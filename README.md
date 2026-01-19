# Bash Backup Rotation Script

Simple script which can be easily modified if needed for backup rotation. This script use ssh and rsync for syncing 
This script is completely rewriten , old script can be found here : https://github.com/todiadiyatmo/bash-backup-rotation-script/tree/legacy-1.0.0 .

## Feature 

- Daily, Weekly, Monthly backup script with number of retention (backup to keep) option
- backup to local only, local + remote and remote only mode
- 4 different backup script  : 
	- file backup with zip compression script
	- rsync script 
	- mysql script
	- mysql with extrabackup script 
- Secure backup with SSH connection


## Todo

This release is still missing this feature from the old relesae 

- [ ] email notification 

# Usage 

## MySQL / MySQL Extrabackup / Zip File Backup 

- Copy script to desired location
- Edit the parameter of the script, configure the `BACKUP_RETENTION_` to set the rotation / number of backup needed

```
### User Pass Mysql ###
USER=backup
PASS=backup
DBNAME=project_sql
BACKUP_DIR="/root/backup"
DST_HOST="user@host"
REMOTE_DST_DIR="/root/backup"
BACKUP_DAILY=true # if set to false backup will not work
BACKUP_WEEKLY=true # if set to false backup will not work
BACKUP_MONTHLY=true # if set to false backup will not work
BACKUP_RETENTION_DAILY=3
BACKUP_RETENTION_WEEKLY=3
BACKUP_RETENTION_MONTHLY=3
```
- test the script to make sure everything correct , ex : `mysql-backup-script.sh`
- put script on cron to make sure it is running everyday at your desired time : `00 03 * * * backup.sh`
- check your backup result
- profit :) 

## Pull request and issue
feel free to open pull request and submit bug ticket 

1. currently this creates backup locally and upload to remote host. Only mybb server has static ip, i dont have other machine with static IP. I want to run this code locally and then to ssh into mybb server, and there backup mysql and zip folders and then download it to local machine. So rentention logic should be applied on local machine. remotely just create single zip file and name it with datetime. You should make this change.

2. Currently mysql vars are hardcoded in script. I run mybb server on ~/trafik-proxy/apps/mybb/ path. This should be var root_path. In that root there is env file apps/mybb/.env that already has mysql user, password and database name. You should add logic to read that file and use it as mysql vars.

3. anoter point, make sure to group script files and code that runs locally and remotely via ssh separated in separate folders. What is used on both put in folder named `common`. remove all code that is not needed and not used.

4. use better names for these vars, use full words, no abbreviations

SRC_CODE="/var/www/html"
BACKUP_DIR="/home/user/backup"
PROJECT_NAME="project"
DST_HOST="user@host"
REMOTE_DST_DIR="/root/backup"


apply all of these changes directly to the code, i will review it

---------

remote folder should contain separate script files for database backup and file backup. More than one folder can be backed up. Folders to backup should be specified in config file as list of paths.

---------
 files should be named backup-mysql.sh, and backup-folders.sh. Entire backup should be a single zip file. Remove all unused code and files. For transfering files use rsync and not scp.

apply all of these changes directly to the code