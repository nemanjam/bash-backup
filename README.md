# Bash Backup Rotation Script

Source of truth is on server. Backup on remote server and sync locally. Only remote server has static IP.

## Features

- Validate remote and local config.
- Validate remote backup.
- Dump MySQL in Docker container.

## Todo

- Add strategy to keep source of truth for backup locally and create only temp file on server through SSH.