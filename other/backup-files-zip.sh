#!/bin/bash

# ---------- Configuration ----------

declare -A SRC_CODE_DIRS=(
    ["inc"]="inc"
    ["images/custom"]="images/custom"
)

# script located at /home/username/traefik-proxy/apps/mybb/backup/scripts"
LOCAL_BACKUP_DIR="../data"
ZIP_PREFIX="mybb_files"

BACKUP_RETENTION_DAILY=3
BACKUP_RETENTION_WEEKLY=2
BACKUP_RETENTION_MONTHLY=2

# ------------- Logic ---------------

BACKUP_DAILY=$(( BACKUP_RETENTION_DAILY > 0 ))
BACKUP_WEEKLY=$(( BACKUP_RETENTION_WEEKLY > 0 ))
BACKUP_MONTHLY=$(( BACKUP_RETENTION_MONTHLY > 0 ))

# Current day and weekday
MONTH=$(date +%d)
DAY_WEEK=$(date +%u)

if [[ ( $MONTH -eq 1 ) && ( $BACKUP_MONTHLY == true ) ]];
        then
    FREQ='monthly'
elif [[ ( $DAY_WEEK -eq 7 ) && ( $BACKUP_WEEKLY == true ) ]];
        then
    FREQ='weekly'
elif [[ ( $DAY_WEEK -lt 7 ) && ( $BACKUP_DAILY == true ) ]];
        then
    FREQ='daily'
fi

DATE=$(date +"%Y-%m-%d")
ZIP_SUFFIX="$FREQ-$DATE"

function local_only {
    ZIP_PATH="$LOCAL_BACKUP_DIR/$ZIP_PREFIX-$ZIP_SUFFIX.zip"
    ZIP_SOURCES=()

    for SRC_CODE_DIR in "${!SRC_CODE_DIRS[@]}"; do
        SRC_CODE_DIR_PATH="${SRC_CODE_DIRS[$SRC_CODE_DIR]}"
        ZIP_SOURCES+=("$SRC_CODE_DIR_PATH")
    done

    # Zip all source directories into a single zip
    zip -r "$ZIP_PATH" "${ZIP_SOURCES[@]}"

    # Move to backup directory
    cd "$LOCAL_BACKUP_DIR/"

    # Prune old backups based on retention
	ls -t | grep "$ZIP_PREFIX" | grep daily | sed -e 1,"$BACKUP_RETENTION_DAILY"d | xargs -d '\n' rm -R > /dev/null 2>&1
    ls -t | grep "$ZIP_PREFIX" | grep weekly | sed -e 1,"$BACKUP_RETENTION_WEEKLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
    ls -t | grep "$ZIP_PREFIX" | grep monthly | sed -e 1,"$BACKUP_RETENTION_MONTHLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
}


if [[ ( $BACKUP_DAILY == true ) && ( ! -z "$BACKUP_RETENTION_DAILY" ) && ( $BACKUP_RETENTION_DAILY -ne 0 ) && ( $FREQ == daily ) ]]; then
    local_only
fi
if [[ ( $BACKUP_WEEKLY == true ) && ( ! -z "$BACKUP_RETENTION_WEEKLY" ) && ( $BACKUP_RETENTION_WEEKLY -ne 0 ) && ( $FREQ == weekly ) ]]; then
    local_only
fi
if [[ ( $BACKUP_MONTHLY == true ) && ( ! -z "$BACKUP_RETENTION_MONTHLY" ) && ( $BACKUP_RETENTION_MONTHLY -ne 0 ) && ( $FREQ == monthly ) ]]; then
    local_only
fi
