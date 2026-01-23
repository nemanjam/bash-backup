# Bash Backup Rotation Script

Forked from: https://github.com/todiadiyatmo/bash-backup-rotation-script

Source of truth is on server. Backup on remote server and sync locally. Only remote server has static IP.

## Features

- Validate remote and local config.
- Validate remote backup.
- Dump MySQL in Docker container.

## Restore MySQL backup in Docker

```bash
# Create a new database inside the container
# -p pdb_password without space, intentionally
docker exec -i mybb-database mysql -u db_user -pdb_password -e "CREATE DATABASE new_db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Example
docker exec -i mybb-database mysql -u mybbuser -pmybbpass -e "CREATE DATABASE mybb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Import the dump into the new database
# -p pdb_password without space, intentionally
docker exec -i mybb-database mysql -u db_user -pdb_password new_db_name < .path/to/dump.sql

# Example
docker exec -i mybb-database mysql -u mybbuser -pmybbpass mybb < ./mybb.sql
```

## Todo

- Add strategy to keep source of truth for backup locally and create only temp file on server through SSH.