#!/bin/bash

# ---------- Configuration ----------

# MySQL credentials
USER=backup
PASS=backup
DB_NAME=project_sql

LOCAL_BACKUP_DIR="/root/backup"
ZIP_PREFIX="mysql"

BACKUP_RETENTION_DAILY=3
BACKUP_RETENTION_WEEKLY=2
BACKUP_RETENTION_MONTHLY=2

# ------------- Logic ---------------

BACKUP_DAILY=$(( BACKUP_RETENTION_DAILY > 0 ))
BACKUP_WEEKLY=$(( BACKUP_RETENTION_WEEKLY > 0 ))
BACKUP_MONTHLY=$(( BACKUP_RETENTION_MONTHLY > 0 ))

# Test daily weekly or monthly
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

DATE=$FREQ-$(date +"%Y%m%d")

function local_only
{
	mysqldump -u$USER -p$PASS $DB_NAME  | gzip > "$LOCAL_BACKUP_DIR/$ZIP_PREFIX-$DB_NAME-$DATE.sql.gz"

	cd $LOCAL_BACKUP_DIR/

	ls -t | grep "$ZIP_PREFIX" | grep $DB_NAME | grep daily | sed -e 1,"$BACKUP_RETENTION_DAILY"d | xargs -d '\n' rm -R > /dev/null 2>&1
	ls -t | grep "$ZIP_PREFIX" | grep $DB_NAME | grep weekly | sed -e 1,"$BACKUP_RETENTION_WEEKLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
	ls -t | grep "$ZIP_PREFIX" | grep $DB_NAME | grep monthly | sed -e 1,"$BACKUP_RETENTION_MONTHLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
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
