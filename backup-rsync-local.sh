#!/bin/bash

# ---------- Configuration ----------

REMOTE_HOST="arm2"
REMOTE_DATA_DIR="~/traefik-proxy/apps/mybb/backup/data"
LOCAL_DATA_DIR="$HOME/backups/mybb/data"

ZIP_PREFIX="mybb_files_and_mysql"

# Minimum valid backup size
MIN_BACKUP_SIZE_MB=1
MIN_BACKUP_SIZE_BYTES=$(( MIN_BACKUP_SIZE_MB * 1024 * 1024 ))

# ---------- Validation ----------

is_valid() {
    local type
    local remote_list local_list
    local remote_count local_count
    local remote_latest local_latest
    local bad_file

    for type in daily weekly monthly; do

        # List remote backups for given type
        remote_list=$(ssh "$REMOTE_HOST" \
            "ls -1 $REMOTE_DATA_DIR/${ZIP_PREFIX}-${type}-*.zip 2>/dev/null")

        # List local backups for given type
        local_list=$(ls -1 "$LOCAL_DATA_DIR/${ZIP_PREFIX}-${type}-*.zip" 2>/dev/null)

        # Count backups
        remote_count=$(echo "$remote_list" | grep -c . || true)
        local_count=$(echo "$local_list" | grep -c . || true)

        # Remote must have at least as many backups as local
        if (( remote_count < local_count )); then
            echo "ERROR: remote has fewer $type backups than local"
            return 1
        fi

        # Extract latest date from filenames
        remote_latest=$(echo "$remote_list" \
            | sed -E 's/.*-([0-9]{4}-[0-9]{2}-[0-9]{2})\.zip/\1/' \
            | sort | tail -n 1)

        local_latest=$(echo "$local_list" \
            | sed -E 's/.*-([0-9]{4}-[0-9]{2}-[0-9]{2})\.zip/\1/' \
            | sort | tail -n 1)

        # Remote backups must not be older than local
        if [[ -n "$local_latest" && "$remote_latest" < "$local_latest" ]]; then
            echo "ERROR: remote $type backup is older than local"
            return 1
        fi

        # Validate minimum file size on remote
        bad_file=$(ssh "$REMOTE_HOST" "
            for f in $REMOTE_DATA_DIR/${ZIP_PREFIX}-${type}-*.zip; do
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
    done

    return 0
}

# ---------- Sync ----------

# Validate remote backup before syncing
if is_valid; then
    echo "Remote backup valid - syncing data"

    # Mirror remote data folder locally
    rsync -av --delete \
        "$REMOTE_HOST:$REMOTE_DATA_DIR/" \
        "$LOCAL_DATA_DIR/"

else
    echo "Backup validation failed - aborting"
    exit 1
fi
