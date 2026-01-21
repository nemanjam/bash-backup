
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


i have remote backup folder with this structure
# ~/traefik-proxy/apps/mybb/

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

i want to rsync it locally but first must validate that remote backup is valid

you should write is_valid() function that will ssh and return boolean

backup is valid if remote data folder has more or equal number for each type daily, weekly, monthly than local data folder and corespondent daily, weekly, monthly files are newer or equal than local files (use date from filename) and each file is larger than 1MB (size is configurable variable)

local_ data folder is exact mirror of remote data folder 

local_ data folder and should not hoard old copies but delete them to match exactly remote data folder

if remote backup is valid rsync entire data folder

if remote backup is not valid abort and print error message

here is existing script for remote backup for reference:

```