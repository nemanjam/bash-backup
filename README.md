# Bash Backup Rotation Script

Forked from: https://github.com/todiadiyatmo/bash-backup-rotation-script

Source of truth is on server. Backup on remote server and sync locally. Only remote server has static IP.

## Features

- Validate remote and local config.
- Validate remote backup.
- Dump MySQL in Docker container.

## Todo

- Add strategy to keep source of truth for backup locally and create only temp file on server through SSH.