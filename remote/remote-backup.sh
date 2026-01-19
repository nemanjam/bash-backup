#!/bin/bash
set -e

# ==========================================
# Remote Backup Orchestrator
# ==========================================

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load Configuration
if [ -f "$SCRIPT_DIRECTORY/config.sh" ]; then
    source "$SCRIPT_DIRECTORY/config.sh"
else
    echo "Error: config.sh not found in $SCRIPT_DIRECTORY" >&2
    exit 1
fi

TEMPORARY_DIRECTORY=$(mktemp -d)
CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="${PROJECT_NAME}_${CURRENT_DATE}"

# 1. Backup Database
# We execute the database backup script and expect it to place the .sql file in our temp dir
# and output the path to it.
echo "Running Database Backup..." >&2
SQL_DUMP_PATH=$("$SCRIPT_DIRECTORY/backup-mysql.sh" "$TEMPORARY_DIRECTORY")

if [ ! -f "$SQL_DUMP_PATH" ]; then
    echo "Error: Database backup failed or file not found at $SQL_DUMP_PATH" >&2
    exit 1
fi

# 2. Identify Files to Backup
# We execute the folders backup script to get a list of relative paths to backup
echo "Identifying Files/Folders to Backup..." >&2
# mapfile is safer for reading lines into array
mapfile -t FILES_TO_BACKUP < <("$SCRIPT_DIRECTORY/backup-folders.sh")

if [ ${#FILES_TO_BACKUP[@]} -eq 0 ]; then
    echo "Warning: No file directories found to backup." >&2
fi

# 3. Create Final Zip Archive
ZIP_FILE_PATH="/tmp/${BACKUP_FILENAME}.zip"

# Move to Project Root to run zip so relative paths work
cd "${REMOTE_PROJECT_ROOT_DIRECTORY}" || exit 1

# We need to include the SQL dump in the zip. 
# It is currently in $TEMPORARY_DIRECTORY. 
# We can tell zip to include it using full path/junk-paths or move it here.
# Let's move it to current dir for clean zipping, then remove.
SQL_FILENAME=$(basename "$SQL_DUMP_PATH")
mv "$SQL_DUMP_PATH" "./$SQL_FILENAME"

echo "Creating Zip Archive..." >&2
# Zip syntax: zip -r output.zip path1 path2 ...
zip -q -r "$ZIP_FILE_PATH" "$SQL_FILENAME" "${FILES_TO_BACKUP[@]}"

# Cleanup
rm "./$SQL_FILENAME"
rm -rf "$TEMPORARY_DIRECTORY"

# 4. Output Result
echo "$ZIP_FILE_PATH"
