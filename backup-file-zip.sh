#!/bin/bash


# ---------- Configuration ----------

SRC_CODE="/var/www/html"
LOCAL_BACKUP_DIR="/home/user/backup"
PROJECT_NAME="project"

BACKUP_RETENTION_DAILY=3
BACKUP_RETENTION_WEEKLY=2
BACKUP_RETENTION_MONTHLY=2

# ------------- Logic ---------------

BACKUP_DAILY=$(( BACKUP_RETENTION_DAILY > 0 ))
BACKUP_WEEKLY=$(( BACKUP_RETENTION_WEEKLY > 0 ))
BACKUP_MONTHLY=$(( BACKUP_RETENTION_MONTHLY > 0 ))

MONTH=`date +%d`
DAY_WEEK=`date +%u`

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

DATE=$FREQ-`date +"%Y%m%d"`

function local_only
{
	zip -r $LOCAL_BACKUP_DIR/$PROJECT_NAME-htdocs-$DATE.zip $SRC_CODE -x *wp-content/uploads*
	cd $LOCAL_BACKUP_DIR/
	ls -t | grep $PROJECT_NAME | grep htdocs | grep daily | sed -e 1,"$BACKUP_RETENTION_DAILY"d | xargs -d '\n' rm -R > /dev/null 2>&1
	ls -t | grep $PROJECT_NAME | grep htdocs | grep weekly | sed -e 1,"$BACKUP_RETENTION_WEEKLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
	ls -t | grep $PROJECT_NAME | grep htdocs | grep monthly | sed -e 1,"$BACKUP_RETENTION_MONTHLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
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
