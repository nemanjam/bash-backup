#!/bin/bash

#  Remote backup folder structure:
# 
# mybb/
# └─ backup/
#    ├─ scripts/
#    │  ├─ backup-files-and-mysql.sh         - versioned
#    │  └─ backup-files-and-mysql-run.sh     - this script
#    └─ data/
#       ├─ mybb_files_and_mysql-daily-2026-01-20.zip
#       │  ├─ inc/
#       │  ├─ images/custom/
#       │  └─ mysql_database/
#       │     └─ mybb.sql
#       ├─ mybb_files_and_mysql-daily-2026-01-19.zip
#       ├─ mybb_files_and_mysql-weekly-2026-01-14.zip
#       └─ mybb_files_and_mysql-monthly-2026-01-01.zip

# ---------- Configuration ----------

# MySQL credentials
DB_CONTAINER_NAME="mybb-database"
DB_NAME="mybb"
DB_USER="mybbuser"
DB_PASS="password"

# Dirs paths
# Local folder is root, all other paths are relative to it
# script located at ~/traefik-proxy/apps/mybb/backup/scripts
LOCAL_BACKUP_DIR="../data"

declare -A SRC_CODE_DIRS=(
    ["inc"]="inc"
    ["images/custom"]="images/custom"
)

# Zip vars
MYSQL_ZIP_DIR="mysql_database"
ZIP_PREFIX="mybb_files_and_mysql"

# Retention
MAX_RETENTION=5
BACKUP_RETENTION_DAILY=3
BACKUP_RETENTION_WEEKLY=2
BACKUP_RETENTION_MONTHLY=2

# Todo: 
# validate config function
# add success and error logging

# ---------- Validate config ------------

is_valid_config() {
    local SCRIPT_DIR
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    local non_zero_found=0

    # Check that MySQL container is running
    if ! docker inspect -f '{{.State.Running}}' "$DB_CONTAINER_NAME" 2>/dev/null | grep -q true; then
        echo "[ERROR] MySQL container not running or not found: DB_CONTAINER_NAME=$DB_CONTAINER_NAME" >&2
        return 1
    fi

    # Check MySQL connectivity inside container
    if ! docker exec "$DB_CONTAINER_NAME" \
        mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
        echo "[ERROR] MySQL connection failed: container=$DB_CONTAINER_NAME user=$DB_USER db=$DB_NAME" >&2
        return 1
    fi

    # Check local backup directory exists
    if [ ! -d "$SCRIPT_DIR/$LOCAL_BACKUP_DIR" ]; then
        echo "[ERROR] Local backup directory missing: path=$SCRIPT_DIR/$LOCAL_BACKUP_DIR" >&2
        return 1
    fi

    # Check source code directories exist
    for dir in "${SRC_CODE_DIRS[@]}"; do
        if [ ! -d "$SCRIPT_DIR/$LOCAL_BACKUP_DIR/$dir" ]; then
            echo "[ERROR] Source directory missing: path=$SCRIPT_DIR/$LOCAL_BACKUP_DIR/$dir" >&2
            return 1
        fi
    done

    # Validate retention values
    for var in BACKUP_RETENTION_DAILY BACKUP_RETENTION_WEEKLY BACKUP_RETENTION_MONTHLY; do
        value="${!var}"

        if [[ ! "$value" =~ ^[0-9]+$ ]]; then
            echo "[ERROR] Retention value is not a number: $var=$value" >&2
            return 1
        fi

        if (( value >= MAX_RETENTION )); then
            echo "[ERROR] Retention value too large: $var=$value (max=$((MAX_RETENTION - 1)))" >&2
            return 1
        fi

        (( value > 0 )) && non_zero_found=1
    done

    if (( non_zero_found == 0 )); then
        echo "[ERROR] All retention values are zero: daily=$BACKUP_RETENTION_DAILY weekly=$BACKUP_RETENTION_WEEKLY monthly=$BACKUP_RETENTION_MONTHLY" >&2
        return 1
    fi

    return 0
}

if ! is_valid_config; then
    echo "[ERROR] Configuration validation failed. Aborting backup." >&2
    exit 1
fi

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

    TEMP_DB_DIR="$LOCAL_BACKUP_DIR/$MYSQL_ZIP_DIR"
    mkdir -p "$TEMP_DB_DIR"

    # Dump MySQL dump as plain .sql, path is on host
    docker exec "$DB_CONTAINER_NAME" \
        sh -c 'mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME"' \
         > "$TEMP_DB_DIR/$DB_NAME.sql"


    # Add database
    ZIP_SOURCES+=("$TEMP_DB_DIR")

    # Add folders 
    for SRC_CODE_DIR in "${!SRC_CODE_DIRS[@]}"; do
        SRC_CODE_DIR_PATH="${SRC_CODE_DIRS[$SRC_CODE_DIR]}"
        ZIP_SOURCES+=("$SRC_CODE_DIR_PATH")
    done

    # Zip all
    zip -r "$ZIP_PATH" "${ZIP_SOURCES[@]}"

    # Cleanup temp DB dir
    rm -rf "$TEMP_DB_DIR"

    # Move to backup directory
    cd "$LOCAL_BACKUP_DIR/"

    # Prune old backups based on retention
    ls -t | grep "$ZIP_NAME" | grep daily | sed -e 1,"$BACKUP_RETENTION_DAILY"d | xargs -d '\n' rm -R > /dev/null 2>&1
    ls -t | grep "$ZIP_NAME" | grep weekly | sed -e 1,"$BACKUP_RETENTION_WEEKLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
    ls -t | grep "$ZIP_NAME" | grep monthly | sed -e 1,"$BACKUP_RETENTION_MONTHLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
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
