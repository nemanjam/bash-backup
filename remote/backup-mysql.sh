#!/bin/bash
set -e

# ==========================================
# Remote Database Backup Script
# ==========================================

# Expects config.sh to be sourced by the caller or present in the same dir
SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load Configuration if not already loaded
if [ -z "$PROJECT_NAME" ]; then
    if [ -f "$SCRIPT_DIRECTORY/config.sh" ]; then
        source "$SCRIPT_DIRECTORY/config.sh"
    else
        echo "Error: config.sh not found in $SCRIPT_DIRECTORY" >&2
        exit 1
    fi
fi

# Arguments: Output Directory
OUTPUT_DIRECTORY=$1

if [ -z "$OUTPUT_DIRECTORY" ]; then
    echo "Error: Output directory not specified." >&2
    exit 1
fi

CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# 1. Read Environment File for Credentials
FULL_ENVIRONMENT_FILE_PATH="${REMOTE_PROJECT_ROOT_DIRECTORY}/${REMOTE_ENVIRONMENT_FILE_PATH}"

if [ ! -f "$FULL_ENVIRONMENT_FILE_PATH" ]; then
    echo "Error: Environment file not found at $FULL_ENVIRONMENT_FILE_PATH" >&2
    exit 1
fi

# Extract Credentials
DATABASE_USER=$(grep -E "^(MYSQL_USER|DB_USER)=" "$FULL_ENVIRONMENT_FILE_PATH" | head -n1 | cut -d '=' -f2 | tr -d '"'\'' ')
DATABASE_PASSWORD=$(grep -E "^(MYSQL_PASSWORD|DB_PASSWORD)=" "$FULL_ENVIRONMENT_FILE_PATH" | head -n1 | cut -d '=' -f2 | tr -d '"'\'' ')
DATABASE_NAME=$(grep -E "^(MYSQL_DATABASE|DB_DATABASE|DB_NAME)=" "$FULL_ENVIRONMENT_FILE_PATH" | head -n1 | cut -d '=' -f2 | tr -d '"'\'' ')

if [ -z "$DATABASE_USER" ] || [ -z "$DATABASE_PASSWORD" ] || [ -z "$DATABASE_NAME" ]; then
    echo "Error: Could not parse database credentials from $FULL_ENVIRONMENT_FILE_PATH" >&2
    exit 1
fi

# 2. Dump Database
SQL_DUMP_FILENAME="${DATABASE_NAME}-${CURRENT_DATE}.sql"
SQL_DUMP_FILE_PATH="${OUTPUT_DIRECTORY}/${SQL_DUMP_FILENAME}"

mysqldump -u"$DATABASE_USER" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" > "$SQL_DUMP_FILE_PATH"

echo "$SQL_DUMP_FILE_PATH"
