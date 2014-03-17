# MongoDB Backup

[Wiki](http://www.bonusbits.com/main/Automation:MongoDB_Backup)

## Purpose
This is a simple BASH shell script that can be used to backup MongoDB using MongoDump.  MongoDump is a binary that comes with the MongoDB client installation.  The default installation location is **/usr/bin/mongodump**. If it is installed in another location on your particular linux flavor the be sure that it is in the path or you adjust the script to include the path.

## Setup Summary

1. Copy Shell Script to MongoDB server
2. Set Permissions as needed
3. Pick or Create user to run-as
4. Setup Cron Job to run the script

## Create Backup User
It's recommended that a user be created to run the script to be more secure and easier to track performance etc.

```bash
useradd mongobackup
```

## Copy Shell Script to MongoDB or Backup Server
If you decide to run it on another server other than the MongoDB server then you'll need to have the MongoDB client of the same version installed for it to work.

1. Copy the mongodb_script to a location of your choosing.
  a. Such as, the user home folder of the user that will run the command.
2. Set ownership of the script file as needed
3. Set file as executable
```bash
chmod +x mongodb_backup.sh
```

## Setup Cron Job

Create Cron Job to run backup script
```bash
crontab -u mongobackup -e
0 7 * * 1,3,5 /scripts/mongodb_backup.sh &> /dev/null
```

[Crontab Quick Reference](http://www.adminschoice.com/crontab-quick-reference/)


## Disclaimer

Use at your own risk. I am not responsible for any negative impacts caused by using this code or following these instructions.

I am sharing this for educational purposes. 

I hope it helps!
