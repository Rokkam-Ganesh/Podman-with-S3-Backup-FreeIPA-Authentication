#!/bin/bash

# Podman Web Server S3 Backup Script
# Location: ~/podman-webserver/scripts/backup-to-s3.sh

set -e  # Exit on any error

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="$HOME/podman-webserver"
BACKUP_DIR="$PROJECT_DIR/backups"
S3_BUCKET="podman-webserver-backup-[YOUR-INITIALS]-[NUMBER]"  # Replace with your bucket name
CONTAINER_NAME="webserver-container"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Podman Web Server Backup Started at $(date) ===${NC}"

mkdir -p "$BACKUP_DIR"

log_message() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

if podman ps | grep -q "$CONTAINER_NAME"; then
    log_message "Container $CONTAINER_NAME is running"
    CONTAINER_RUNNING=true
else
    log_warning "Container $CONTAINER_NAME is not running"
    CONTAINER_RUNNING=false
fi

BACKUP_ARCHIVE="webserver_backup_${BACKUP_DATE}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_ARCHIVE"

log_message "Creating backup archive: $BACKUP_ARCHIVE"

cd "$PROJECT_DIR"
tar -czf "$BACKUP_PATH" \
    --exclude='backups' \
    --exclude='.git' \
    html/ \
    data/ \
    scripts/ \
    Dockerfile

if [ "$CONTAINER_RUNNING" = true ]; then
    log_message "Backing up container runtime data"
    
    podman export "$CONTAINER_NAME" > "$BACKUP_DIR/container_export_${BACKUP_DATE}.tar"
    
    podman inspect "$CONTAINER_NAME" > "$BACKUP_DIR/container_config_${BACKUP_DATE}.json"
fi

if [ -f "$BACKUP_PATH" ]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
    log_message "Backup archive created successfully: $BACKUP_SIZE"
else
    log_error "Failed to create backup archive"
    exit 1
fi

log_message "Uploading backup to S3 bucket: $S3_BUCKET"

if aws s3 cp "$BACKUP_PATH" "s3://$S3_BUCKET/backups/" --storage-class STANDARD_IA; then
    log_message "Main backup uploaded successfully to S3"
else
    log_error "Failed to upload main backup to S3"
    exit 1
fi

if [ "$CONTAINER_RUNNING" = true ]; then
    aws s3 cp "$BACKUP_DIR/container_export_${BACKUP_DATE}.tar" "s3://$S3_BUCKET/container-exports/" --storage-class STANDARD_IA
    aws s3 cp "$BACKUP_DIR/container_config_${BACKUP_DATE}.json" "s3://$S3_BUCKET/container-configs/" --storage-class STANDARD_IA
    log_message "Container runtime data uploaded to S3"
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
    "files_backed_up": [
        "html/",
        "data/",
        "scripts/",
        "Dockerfile"
    ]
}
EOF

aws s3 cp "$BACKUP_DIR/backup_metadata_${BACKUP_DATE}.json" "s3://$S3_BUCKET/metadata/"

log_message "Cleaning up old local backups (keeping last 5)"
cd "$BACKUP_DIR"
ls -t webserver_backup_*.tar.gz | tail -n +6 | xargs -r rm -f
ls -t container_export_*.tar | tail -n +6 | xargs -r rm -f
ls -t container_config_*.json | tail -n +6 | xargs -r rm -f
ls -t backup_metadata_*.json | tail -n +6 | xargs -r rm -f

log_message "Current S3 backups:"
aws s3 ls "s3://$S3_BUCKET/backups/" --human-readable --summarize

log_message "Backup completed successfully!"
echo -e "${BLUE}=== Backup process finished at $(date) ===${NC}"
