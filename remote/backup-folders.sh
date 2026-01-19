#!/bin/bash
set -e

# ==========================================
# Remote Files Backup Script
# ==========================================

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "$PROJECT_NAME" ]; then
    if [ -f "$SCRIPT_DIRECTORY/config.sh" ]; then
        source "$SCRIPT_DIRECTORY/config.sh"
    else
        echo "Error: config.sh not found in $SCRIPT_DIRECTORY" >&2
        exit 1
    fi
fi

OUTPUT_DIRECTORY=$1

if [ -z "$OUTPUT_DIRECTORY" ]; then
    echo "Error: Output directory not specified." >&2
    exit 1
fi

CURRENT_DATE=$(date +"%Y%m%d_%H%M%S")

# 3. Zip folders
# We loop through REMOTE_SOURCE_DIRECTORIES and zip them.
# The user asked to zip folders and then download. "remotely just create single zip file".
# So we add all source directories to the same zip file.

# Check if REMOTE_SOURCE_DIRECTORIES is set
if [ ${#REMOTE_SOURCE_DIRECTORIES[@]} -eq 0 ]; then
    echo "Error: REMOTE_SOURCE_DIRECTORIES array is empty in config." >&2
    exit 1
fi

# Move to Root to have clean relative paths
cd "${REMOTE_PROJECT_ROOT_DIRECTORY}" || exit 1

# If we are being called from the orchestrator, we might want to zip into a final archive OR 
# zip specific folders to a temp location. 
# The request implies one single zip file containing everything.
# We will just verify the folders exist here. The orchestration happens in the main script?
# OR does this script do the actual zipping?
# "remote folder should contain separate script files for database backup and file backup"
# Making this script responsible for adding files to the zip makes sense if we pass the zip path?
# Or we can just output the list of files/folders to include?

# Simpler approach: This script prepares the files-to-backup.
# Actually, `zip` command handles multiple input paths.
# Let's make this script output the valid relative paths to be zipped.

for dir in "${REMOTE_SOURCE_DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        echo "$dir"
    else
        echo "Warning: Directory not found: $dir" >&2
    fi
done
