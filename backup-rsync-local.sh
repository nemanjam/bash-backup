#!/bin/bash

#  Local backup folder structure:
# 
# mybb/
# └─ backup/
#    ├─ scripts/
#    │  └─ backup-rsync-local.sh     - this script
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

REMOTE_HOST="arm2"
REMOTE_DATA_DIR="~/traefik-proxy/apps/mybb/backup/data"
LOCAL_DATA_DIR="../data"

# Must match backup-files-and-mysql.sh
ZIP_PREFIX="mybb_files_and_mysql"

# Minimum valid backup size
MIN_BACKUP_SIZE_MB=1
MIN_BACKUP_SIZE_BYTES=$(( MIN_BACKUP_SIZE_MB * 1024 * 1024 ))

# ---------- Utils ----------

# Extract latest YYYY-MM-DD date from backup filenames
get_latest_date() {
    sed -E 's/.*-([0-9]{4}-[0-9]{2}-[0-9]{2})\.zip/\1/' \
        | sort | tail -n 1
}

# Split a list of filenames into daily/weekly/monthly assoc array
split_backup_types() {
    local files="$1"
    declare -n arr=$2  # pass assoc array by name

    while IFS= read -r file; do
        case "$file" in
            *-daily-*.zip)   arr[daily]+="$file"$'\n' ;;
            *-weekly-*.zip)  arr[weekly]+="$file"$'\n' ;;
            *-monthly-*.zip) arr[monthly]+="$file"$'\n' ;;
        esac
    done <<< "$files"
}

# Ensure remote has at least as many backups as local
check_count() {
    local remote_count="$1"
    local local_count="$2"
    local backup_type="$3"

    if (( remote_count < local_count )); then
        echo "ERROR: remote has fewer type=$backup_type backups than local, remote_count=$remote_count, local_count=$local_count"
        return 1
    fi
}

# Ensure remote backups are not older than local
check_date() {
    local remote_latest="$1"
    local local_latest="$2"
    local backup_type="$3"

    if [[ -n "$local_latest" && "$remote_latest" < "$local_latest" ]]; then
        echo "ERROR: remote type=$backup_type backup is older than local, remote_latest=$remote_latest, local_latest=$local_latest"
        return 1
    fi
}

# Ensure all remote backups are larger than minimum size
check_file_size() {
    local bad_file

    bad_file=$(ssh "$REMOTE_HOST" "
        for f in $REMOTE_DATA_DIR/${ZIP_PREFIX}-*.zip; do
            [ -f \"\$f\" ] || continue
            size=\$(stat -c %s \"\$f\")
            if (( size < $MIN_BACKUP_SIZE_BYTES )); then
                echo \"\$f\"
                exit 1
            fi
        done
    " || true)

    if [[ -n "$bad_file" ]]; then
        echo "ERROR: remote backup too small: $bad_file"
        return 1
    fi
}

# ---------- Validation ----------

is_valid() {
    # Local variables
    local -A remote_lists local_lists
    local remote_all_files local_all_files

    # Loop variables
    local backup_type
    local remote_list local_list
    local remote_count local_count
    local remote_latest local_latest

    # Global size validation (run once)
    if ! check_file_size; then
        echo "ERROR: remote backup contains file(s) smaller than minimum size ($MIN_BACKUP_SIZE_BYTES bytes)"
        return 1
    fi

    # Store remote backup filenames in a variable and split
    remote_all_files=$(ssh "$REMOTE_HOST" "ls -1 $REMOTE_DATA_DIR/${ZIP_PREFIX}-*.zip 2>/dev/null")
    split_backup_types "$remote_all_files" remote_lists

    # Store local backup filenames in a variable and split
    local_all_files=$(ls -1 "$LOCAL_DATA_DIR/${ZIP_PREFIX}-*.zip" 2>/dev/null)
    split_backup_types "$local_all_files" local_lists

    for backup_type in daily weekly monthly; do
        # Set filename lists
        remote_list="${remote_lists[$backup_type]}"
        local_list="${local_lists[$backup_type]}"

        # Check counts
        remote_count=$(echo "$remote_list" | grep -c . || true)
        local_count=$(echo "$local_list" | grep -c . || true)
        if ! check_count "$remote_count" "$local_count" "$backup_type"; then
            echo "ERROR: backup count mismatch for type=$backup_type: remote=$remote_count is less than local=$local_count"
            return 1
        fi

        # Check latest dates
        remote_latest=$(echo "$remote_list" | get_latest_date)
        local_latest=$(echo "$local_list" | get_latest_date)
        if ! check_date "$remote_latest" "$local_latest" "$backup_type"; then
            echo "ERROR: latest backup date mismatch for type=$backup_type: remote=$remote_latest is older than local=$local_latest"
            return 1
        fi
    done

    return 0
}

# ---------- Sync ----------

# Exit early if remote backup is not valid
if ! is_valid; then
    echo "Backup validation failed - aborting"
    exit 1
fi

echo "Remote backup valid - syncing data"

# Mirror remote data directory locally
rsync -av --delete \
    "$REMOTE_HOST:$REMOTE_DATA_DIR/" \
    "$LOCAL_DATA_DIR/"

echo "Backup sync complete"
