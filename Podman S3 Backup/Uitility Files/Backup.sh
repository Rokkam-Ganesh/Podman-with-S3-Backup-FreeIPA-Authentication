#!/bin/bash

# Podman Web Server S3 Backup Script
# Location: ~/podman-webserver/scripts/backup-to-s3.sh

set -e  # Exit on any error


BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="$HOME/podman-webserver"
BACKUP_DIR="$PROJECT_DIR/backups"
S3_BUCKET="podman-webserver-backup-[YOUR-INITIALS]-[NUMBER]"
CONTAINER_NAME="webserver-container"

mkdir -p "$BACKUP_DIR"

log() { echo -e "[${1}] $(date '+%F %T') - $2"; }

CONTAINER_RUNNING=false
if podman ps | grep -q "$CONTAINER_NAME"; then
    log "INFO" "Container $CONTAINER_NAME is running"
    CONTAINER_RUNNING=true
else
    log "WARN" "Container $CONTAINER_NAME is not running"
fi

BACKUP_ARCHIVE="webserver_backup_${BACKUP_DATE}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_ARCHIVE"

log "INFO" "Creating backup archive: $BACKUP_ARCHIVE"
cd "$PROJECT_DIR"
tar -czf "$BACKUP_PATH" \
    --exclude='backups' \
    --exclude='.git' \
    html/ data/ scripts/ Dockerfile

if [ "$CONTAINER_RUNNING" = true ]; then
    podman export "$CONTAINER_NAME" > "$BACKUP_DIR/container_export_${BACKUP_DATE}.tar"
    podman inspect "$CONTAINER_NAME" > "$BACKUP_DIR/container_config_${BACKUP_DATE}.json"
fi

[ -f "$BACKUP_PATH" ] || { log "ERROR" "Backup creation failed"; exit 1; }

BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
log "INFO" "Backup size: $BACKUP_SIZE"

log "INFO" "Uploading backup to S3"
aws s3 cp "$BACKUP_PATH" "s3://$S3_BUCKET/backups/" --storage-class STANDARD_IA

if [ "$CONTAINER_RUNNING" = true ]; then
    aws s3 cp "$BACKUP_DIR/container_export_${BACKUP_DATE}.tar" "s3://$S3_BUCKET/container-exports/" --storage-class STANDARD_IA
    aws s3 cp "$BACKUP_DIR/container_config_${BACKUP_DATE}.json" "s3://$S3_BUCKET/container-configs/" --storage-class STANDARD_IA
fi

cat > "$BACKUP_DIR/backup_metadata_${BACKUP_DATE}.json" << EOF
{
  "backup_date": "$BACKUP_DATE",
  "backup_archive": "$BACKUP_ARCHIVE",
  "backup_size": "$BACKUP_SIZE",
  "container_running": $CONTAINER_RUNNING,
  "s3_bucket": "$S3_BUCKET",
  "server_hostname": "$(hostname)",
  "server_ip": "$(curl -s http://checkip.amazonaws.com)",
  "files_backed_up": ["html/", "data/", "scripts/", "Dockerfile"]
}
EOF

aws s3 cp "$BACKUP_DIR/backup_metadata_${BACKUP_DATE}.json" "s3://$S3_BUCKET/metadata/"

cd "$BACKUP_DIR"
ls -t webserver_backup_*.tar.gz | tail -n +6 | xargs -r rm -f
ls -t container_export_*.tar | tail -n +6 | xargs -r rm -f
ls -t container_config_*.json | tail -n +6 | xargs -r rm -f
ls -t backup_metadata_*.json | tail -n +6 | xargs -r rm -f

aws s3 ls "s3://$S3_BUCKET/backups/" --human-readable --summarize
log "INFO" "Backup completed"
