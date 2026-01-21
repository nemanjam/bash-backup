
```bash
# backup-file-zip.sh

function local_remote
{
	# Create a zip archive of the source code, excluding WordPress uploads.
	zip -r "$BACKUP_DIR/$PROJECT_NAME-htdocs-$DATE.zip" "$SRC_CODE" -x "*wp-content/uploads*"

	# Switch to the backup directory to simplify file operations.
	cd "$BACKUP_DIR/" || return 1

	# List files in the current directory, sorted by modification time (newest first).
	ls -t \
		# Keep only files that belong to the current project.
		| grep "$PROJECT_NAME" \
		# Filter backups related to the htdocs directory.
		| grep htdocs \
		# Filter only daily backups.
		| grep daily \
		# Skip the newest $BACKUP_RETENTION_DAILY files and select the rest for deletion.
		| sed -e 1,"$BACKUP_RETENTION_DAILY"d \
		# Recursively remove the selected old backup directories/files, suppressing all output.
		| xargs -d '\n' rm -R > /dev/null 2>&1



	# Remove old weekly htdocs backups based on the retention policy.
	ls -t \
		| grep "$PROJECT_NAME" \
		| grep htdocs \
		| grep weekly \
		| sed -e 1,"$BACKUP_RETENTION_WEEKLY"d \
		| xargs -d '\n' rm -R > /dev/null 2>&1

	# Remove old monthly htdocs backups based on the retention policy.
	ls -t \
		| grep "$PROJECT_NAME" \
		| grep htdocs \
		| grep monthly \
		| sed -e 1,"$BACKUP_RETENTION_MONTHLY"d \
		| xargs -d '\n' rm -R > /dev/null 2>&1

	# Sync the local backup directory to the remote host and remove stale remote files.
	rsync -avh --delete "$BACKUP_DIR/" "$DST_HOST:$REMOTE_DST_DIR"
}


# Check if the selected backup mode is local-only.
elif [ "$BACKUP_MODE" == local-only ]; then

	# Check conditions for running a daily local-only backup.
	if [[ ( "$BACKUP_DAILY" == true ) \
		# Ensure daily retention is defined and not empty.
		&& ( -n "$BACKUP_RETENTION_DAILY" ) \
		# Ensure daily retention value is not zero.
		&& ( "$BACKUP_RETENTION_DAILY" -ne 0 ) \
		# Ensure the current backup frequency is daily.
		&& ( "$FN" == daily ) ]]; then
		# Execute the local-only backup routine.
		local_only
	fi

	# Check conditions for running a weekly local-only backup.
	if [[ ( "$BACKUP_WEEKLY" == true ) \
		# Ensure weekly retention is defined and not empty.
		&& ( -n "$BACKUP_RETENTION_WEEKLY" ) \
		# Ensure weekly retention value is not zero.
		&& ( "$BACKUP_RETENTION_WEEKLY" -ne 0 ) \
		# Ensure the current backup frequency is weekly.
		&& ( "$FN" == weekly ) ]]; then
		# Execute the local-only backup routine.
		local_only
	fi

	# Check conditions for running a monthly local-only backup.
	if [[ ( "$BACKUP_MONTHLY" == true ) \
		# Ensure monthly retention is defined and not empty.
		&& ( -n "$BACKUP_RETENTION_MONTHLY" ) \
		# Ensure monthly retention value is not zero.
		&& ( "$BACKUP_RETENTION_MONTHLY" -ne 0 ) \
		# Ensure the current backup frequency is monthly.
		&& ( "$FN" == monthly ) ]]; then
		# Execute the local-only backup routine.
		local_only
	fi


# ---------------------
# backup-rsync.sh

#!/bin/bash

# Perform a rotating daily or weekly backup by syncing the source directory into a modulo-based bucket using rsync.

# Get the current day of the year (001–366) and force base-10 to avoid octal issues.
CURRENT_DAY=$((10#$(date +%j)))

# Get the current ISO week number (01–53) and force base-10.
CURRENT_WEEK=$((10#$(date +%V)))

# Number of rotating daily backups to keep.
NUMBER_OF_DAILY_BACKUP=2

# Number of rotating weekly backups to keep.
NUMBER_OF_WEEKLY_BACKUP=2

# Check if the script was called with the --weekly flag.
if [ "$1" == "--weekly" ]; then
	# Calculate the weekly backup bucket using modulo rotation.
	BUCKET=$(( CURRENT_WEEK % NUMBER_OF_WEEKLY_BACKUP ))

	# Mark this run as a weekly backup.
	BUCKET_TYPE="weekly"
else
	# Calculate the daily backup bucket using modulo rotation.
	BUCKET=$(( CURRENT_DAY % NUMBER_OF_DAILY_BACKUP ))

	# Mark this run as a daily backup.
	BUCKET_TYPE="daily"
fi

# Source directory to back up (must be set before running).
SOURCE=""

# Base destination directory for backups.
DESTINATION=""

# Sync source data into the calculated bucket directory using rsync.
rsync -avh "$SOURCE" "$DESTINATION/$BUCKET_TYPE/$BUCKET"

# ------------------

write me is_valid_config() bash function

connect to mysql that runs inside this container and uses this vars

# MySQL credentials
USER=backup
PASS=backup
DB_NAME=project_sql

# container
  database:
    image: mysql:8.0
    container_name: mybb-database
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./data/mysql-data:/var/lib/mysql
      - ./conf/mysql.cnf:/etc/mysql/conf.d/custom.cnf:ro
    networks:
      - default

validates that these folders on relative paths to script location exist

# Dirs paths
# Local folder is root, all other paths are relative to it
# script located at ~/traefik-proxy/apps/mybb/backup/scripts
LOCAL_BACKUP_DIR="../data"

declare -A SRC_CODE_DIRS=(
    ["inc"]="inc"
    ["images/custom"]="images/custom"
)

validates that these vars are 0 or positive numbers less than 5 (configurable), and at least one is not 0

# Retention
BACKUP_RETENTION_DAILY=3
BACKUP_RETENTION_WEEKLY=2
BACKUP_RETENTION_MONTHLY=2

```