#!/bin/bash
set -e

# ==========================================
# Local Backup Coordinator Script
# ==========================================

# Get directory of this script
SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT_DIRECTORY="$(dirname "$SCRIPT_DIRECTORY")"
COMMON_DIRECTORY="$PROJECT_ROOT_DIRECTORY/common"

# Load Configuration
if [ -f "$COMMON_DIRECTORY/config.sh" ]; then
    source "$COMMON_DIRECTORY/config.sh"
else
    echo "Error: config.sh not found in $COMMON_DIRECTORY" >&2
    exit 1
fi

# Retention Settings
BACKUP_RETAIN_DAILY=true
BACKUP_RETAIN_WEEKLY=true
BACKUP_RETAIN_MONTHLY=true

RETENTION_COUNT_DAILY=3
RETENTION_COUNT_WEEKLY=3
RETENTION_COUNT_MONTHLY=3

# Helper function to delete old backups
clean_old_backups() {
    local backup_type=$1
    local retention_count=$2
    local file_pattern=$3
    
    echo "Cleaning $backup_type backups (Retention: $retention_count)..."
    
    ls -t "$LOCAL_BACKUP_DIRECTORY" | grep "$file_pattern" | grep "$backup_type" | sed -e "1,${retention_count}d" | while read -r file; do
        rm -v "${LOCAL_BACKUP_DIRECTORY}/$file"
    done
}

# Determine Backup Type
CURRENT_MONTH=$(date +%d)
CURRENT_DAY_OF_WEEK=$(date +%u)
BACKUP_TYPE=""

if [[ ( "$CURRENT_MONTH" -eq 1 ) && ( "$BACKUP_RETAIN_MONTHLY" == "true" ) ]]; then
    BACKUP_TYPE='monthly'
elif [[ ( "$CURRENT_DAY_OF_WEEK" -eq 7 ) && ( "$BACKUP_RETAIN_WEEKLY" == "true" ) ]]; then
    BACKUP_TYPE='weekly'
elif [[ ( "$CURRENT_DAY_OF_WEEK" -lt 7 ) && ( "$BACKUP_RETAIN_DAILY" == "true" ) ]]; then
    BACKUP_TYPE='daily'
fi

if [ -z "$BACKUP_TYPE" ]; then
    echo "No backup scheduled for today."
    exit 0
fi

echo "Starting $BACKUP_TYPE backup for project: $PROJECT_NAME..."

# 1. Prepare Local Directory
mkdir -p "$LOCAL_BACKUP_DIRECTORY"

# 2. Deploy Scripts to Remote
echo "Deploying scripts to $DESTINATION_HOST..."
# Create a temp dir on remote to hold scripts
REMOTE_TEMP_EXEC_DIR=$(ssh "$DESTINATION_HOST" "mktemp -d")

# SCP config and remote scripts
# Using rsync for better performance and checks
rsync -avq "$COMMON_DIRECTORY/config.sh" \
       "$PROJECT_ROOT_DIRECTORY/remote/remote-backup.sh" \
       "$PROJECT_ROOT_DIRECTORY/remote/backup-mysql.sh" \
       "$PROJECT_ROOT_DIRECTORY/remote/backup-folders.sh" \
       "$DESTINATION_HOST:$REMOTE_TEMP_EXEC_DIR/"

ssh "$DESTINATION_HOST" "chmod +x $REMOTE_TEMP_EXEC_DIR/*.sh"

# 3. Execute Remote Backup
echo "Executing remote backup..."
# Run the script
REMOTE_ZIP_PATH=$(ssh "$DESTINATION_HOST" "$REMOTE_TEMP_EXEC_DIR/remote-backup.sh" | tail -n 1)

echo "Remote backup artifact created at: $REMOTE_ZIP_PATH"

# 4. Download Backup
LOCAL_FILENAME="${PROJECT_NAME}-backup-${BACKUP_TYPE}-$(date +"%Y%m%d").zip"

echo "Downloading..."
rsync -avq "$DESTINATION_HOST:$REMOTE_ZIP_PATH" "$LOCAL_BACKUP_DIRECTORY/$LOCAL_FILENAME"
echo "Saved to: $LOCAL_BACKUP_DIRECTORY/$LOCAL_FILENAME"

# 5. Cleanup Remote
echo "Cleaning up remote..."
ssh "$DESTINATION_HOST" "rm '$REMOTE_ZIP_PATH'; rm -rf '$REMOTE_TEMP_EXEC_DIR'"

# 6. Local Retention Rotation
cd "$LOCAL_BACKUP_DIRECTORY" || exit 1

if [ "$BACKUP_RETAIN_DAILY" == "true" ]; then
    clean_old_backups "daily" "$RETENTION_COUNT_DAILY" "${PROJECT_NAME}-backup"
fi
if [ "$BACKUP_RETAIN_WEEKLY" == "true" ]; then
    clean_old_backups "weekly" "$RETENTION_COUNT_WEEKLY" "${PROJECT_NAME}-backup"
fi
if [ "$BACKUP_RETAIN_MONTHLY" == "true" ]; then
    clean_old_backups "monthly" "$RETENTION_COUNT_MONTHLY" "${PROJECT_NAME}-backup"
fi

echo "Backup process completed successfully."
