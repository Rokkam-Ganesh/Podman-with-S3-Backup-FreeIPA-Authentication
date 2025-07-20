#!/bin/bash

# Podman Web Server S3 Restore Script
# Location: ~/podman-webserver/scripts/restore-from-s3.sh

set -e  # Exit on any error
PROJECT_DIR="$HOME/podman-webserver"
BACKUP_DIR="$PROJECT_DIR/backups"
S3_BUCKET="podman-webserver-backup-[YOUR-INITIALS]-[NUMBER]"
CONTAINER_NAME="webserver-container"

log() { echo "[${1}] $(date '+%F %T') - $2"; }

list_backups() {
    log "INFO" "Available backups in S3:"
    aws s3 ls "s3://$S3_BUCKET/backups/" | grep webserver_backup_
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_archive_name>"
    list_backups
    exit 1
fi

BACKUP_ARCHIVE="$1"
RESTORE_DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

if ! aws s3 ls "s3://$S3_BUCKET/backups/$BACKUP_ARCHIVE" > /dev/null 2>&1; then
    log "ERROR" "Backup archive $BACKUP_ARCHIVE not found in S3"
    list_backups
    exit 1
fi

log "INFO" "Restoring: $BACKUP_ARCHIVE"

if podman ps | grep -q "$CONTAINER_NAME"; then
    log "WARN" "Stopping and removing existing container"
    podman stop "$CONTAINER_NAME"
    podman rm "$CONTAINER_NAME"
fi

if [ -d "$PROJECT_DIR/html" ] || [ -d "$PROJECT_DIR/data" ]; then
    log "INFO" "Backing up current project files"
    tar -czf "$BACKUP_DIR/current_backup_before_restore_${RESTORE_DATE}.tar.gz" -C "$PROJECT_DIR" html data scripts Dockerfile 2>/dev/null || true
fi

log "INFO" "Downloading backup from S3"
aws s3 cp "s3://$S3_BUCKET/backups/$BACKUP_ARCHIVE" "$BACKUP_DIR/"

[ -f "$BACKUP_DIR/$BACKUP_ARCHIVE" ] || { log "ERROR" "Download failed"; exit 1; }

cd "$PROJECT_DIR"
rm -rf html data scripts Dockerfile
tar -xzf "$BACKUP_DIR/$BACKUP_ARCHIVE"

log "INFO" "Rebuilding container"
podman build -t webserver-app:v1.0 .

log "INFO" "Starting container"
podman run -d \
  --name "$CONTAINER_NAME" \
  -p 8080:80 \
  -v "$PROJECT_DIR/data:/app/data:Z" \
  --restart unless-stopped \
  webserver-app:v1.0

sleep 5

if podman ps | grep -q "$CONTAINER_NAME"; then
    log "INFO" "Container started"

    if curl -s http://localhost:8080 > /dev/null; then
        PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
        log "INFO" "Web server is accessible at: http://$PUBLIC_IP:8080"
    else
        log "WARN" "Web server not responding yet"
    fi
else
    log "ERROR" "Failed to start container"
    exit 1
fi

log "INFO" "Restore complete from: $BACKUP_ARCHIVE"
