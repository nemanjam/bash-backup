#!/bin/bash

# ==========================================
# Shared Configuration
# ==========================================

# Project Identifier
PROJECT_NAME="mybb_project"

# Remote Connection Details
DESTINATION_HOST="root@example.com"

# Remote File Paths
# The absolute path to the project root on the remote server
REMOTE_PROJECT_ROOT_DIRECTORY="$HOME/trafik-proxy"

# The paths to the source code directories to backup (relative to REMOTE_PROJECT_ROOT_DIRECTORY)
# Specify multiple directories as a bash array
REMOTE_SOURCE_DIRECTORIES=(
    "apps/mybb"
    # "apps/wordpress"
)

# The path to the .env file containing database credentials (relative to REMOTE_PROJECT_ROOT_DIRECTORY)
REMOTE_ENVIRONMENT_FILE_PATH="apps/mybb/.env"

# Local File Paths
# The directory on the local machine where backups will be stored
LOCAL_BACKUP_DIRECTORY="/home/user/backup"
