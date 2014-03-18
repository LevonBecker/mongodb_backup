#!/bin/bash


#region Default Variables

  default_backup_path=/backups/mongo_backups
  default_log_path=/var/log/mongo_backups
  default_auth_db=admin
  default_size_limit_mb=5000
  default_use_auth=true
  default_host=localhost
  default_port=27017
  default_version=2.4
  default_retention_days=30

  # Get Date and Time
  datetime=`date +%Y%m%d-%H%M`
  logfile=mongo_backup_$datetime.log
  backupfile=mongo_backup_$datetime.tgz
  starttime_seconds=$(date +%s)
  starttime=$(date)

#endregion Default Variables


#region Help

function usage () {
usageMessage="
-----------------------------------------------------------------------------------------------------------------------
AUTHOR:       Levon Becker
PURPOSE:      Backup MongoDB with Mongodump
VERSION:      1.0.8
GITHUB:       https://github.com/LevonBecker/mongodb_backup
SOURCES:      http://docs.mongodb.org/manual/reference/program/mongodump/
DESCRIPTION:  Backup MongoDB with Mongodump.
-----------------------------------------------------------------------------------------------------------------------
|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-----------------------------------------------------------------------------------------------------------------------
PARAMETERS
-----------------------------------------------------------------------------------------------------------------------
Manditory:
-u Mongo User
-d Authenication Database
-p Mongo User Password
Optional:
-b Backup Path - Default is ($default_backup_path)
-l Log Path - Default is ($default_backup_path)
-s Space limit in MB
-a Use Authentication - (true | false) - Default ($default_use_auth)
-v MongoDB Version (2.2 | 2.4) - Default ($default_version)
-n Hostname - Default ($default_host)
-t Port - Default ($default_port)
-r Retention in Days to save backups - Default ($default_retention_days)
-----------------------------------------------------------------------------------------------------------------------
EXAMPLES
-----------------------------------------------------------------------------------------------------------------------
$0 -u admin -p password -d admin
$0 -u admin -p password -d admin -s '10000'
$0 -u admin -p password -d admin -b '/cust/mybackup/folder' -s '5000'
$0 -u admin -p password -d admin -b '/cust/mybackup/folder' -s '5000' -n 'mongoserver01.domain.com'
$0 -a false

-----------------------------------------------------------------------------------------------------------------------
"
    echo "$usageMessage";
}

#endregion Help


#region Arguments

  while getopts "u:d:p:b:l:s:a:v:n:t:r:h" opts; do
      case $opts in
          u ) username=$OPTARG;;
          d ) auth_db=$OPTARG;;
          p ) password=$OPTARG;;
          b ) backup_path=$OPTARG;;
          l ) log_path=$OPTARG;;
          s ) size_limit_mb=$OPTARG;;
          a ) use_auth=$OPTARG;;
          v ) version=$OPTARG;;
          n ) host=$OPTARG;;
          t ) port=$OPTARG;;
          r ) retention_days=$OPTARG;;
          h ) usage; exit 0;;
          * ) usage; exit 1;;
      esac
  done

  # Use defaults if missing arguments
  if [ -z $backup_path ]; then backup_path=$default_backup_path; fi
  if [ -z $log_path ]; then log_path=$default_log_path; fi
  if [ -z $size_limit_mb ]; then size_limit_mb=$default_size_limit_mb; fi
  if [ -z $use_auth ]; then use_auth=$default_use_auth; fi
  if [ -z $version ]; then version=$default_version; fi
  if [ -z $host ]; then host=$default_host; fi
  if [ -z $port ]; then port=$default_port; fi
  if [ -z $retention_days ]; then retention_days=$default_retention_days; fi

  if [ $use_auth == true ]
  then  
    if [ -z $username ]
    then
        logMe "Username argument (-u) required when using authentication - aborting";
        usage;
        exit 1;
    fi
    if [ -z $password ]
    then
        logMe "Password argument (-p) required when using authentication - aborting";
        usage;
        exit 1;
    fi
    if [ $version == '2.4' ]
    then
      if [ -z $auth_db ]
      then
          logMe "Authenctication Database argument (-d) required when using authentication - aborting";
          usage;
          exit 1;
      fi
      auth_command="--authenticationDatabase $auth_db --username $username --password $password"
    else
      auth_command="--username $username --password $password"
    fi
  else
      auth_command=""
  fi

#endregion Arguments


#region Prerequisites

  echo "Checking Prerequisites ..."
  # errorcount=0

  if [ ! -d $backup_path ]
  then
      echo "Creating Backup Path ($backup_path)"
      mkdir -p $backup_path
  else
      echo "Backup Path Already Exists ($backup_path)"
  fi

  if [ ! -d $log_path ]
  then
      echo "Creating Backup Path ($log_path)"
      mkdir -p $log_path
  else
      echo "Backup Path Already Exists ($log_path)"
  fi

#endregion Prerequisites


#region Functions

  function show_message {
    echo '' | tee -a $log_path/$logfile
    echo '--------------------------------------------------------------------------------' | tee -a $log_path/$logfile
    echo $1 | tee -a $log_path/$logfile
    echo '--------------------------------------------------------------------------------' | tee -a $log_path/$logfile
    echo '' | tee -a $log_path/$logfile
  }

#endregion Functions


#region Latest Log Symlink

  show_message 'BEGIN: Latest Log Symlink.'
  echo "ACTION: Creating Symlink to: ($log_path/$logfile)" | tee -a $log_path/$logfile
  if [ -f $log_path/$logfile ]
  then
    ln -sf $log_path/$logfile $log_path/latest_mongo_backup.log
  else
    echo 'ERROR: Log Not Found ($log_path/$logfile)' | tee -a $log_path/$logfile
    exit 1
  fi
  show_message 'END:   Latest Log Symlink.'

#endregion Latest Log Symlink


#region Space Check

  show_message 'BEGIN: Space Check.'
  used_space_bytes=$(du -bs $backup_path | awk '{print $1}')
  used_space_mb=$[$used_space_bytes/1000000]
  echo 'REPORT: Backup Destination Directory ($backup_path)' | tee -a $log_path/$logfile
  echo "REPORT: Space Before Backup in MB: $used_space_mb" | tee -a $log_path/$logfile
  if [ $used_space_mb -le $size_limit_mb ]
  then
    echo 'REPORT: Space OK' | tee -a $log_path/$logfile
    show_message 'END:   Space Check.'
  else
    echo 'ERROR: Over Space Limit!' | tee -a $log_path/$logfile
    show_message 'END:   Space Check.'
    exit 1
  fi

#endregion Space Check


#region Backup

  show_message 'BEGIN: Attempting Backup'
  mongodump --host $host --port $port $auth_command --out $backup_path/$datetime | tee -a $log_path/$logfile
  show_message 'END: Attempting Backup.'

#endregion Backup


#region Compress

  if [ -d  $backup_path/$datetime ]
  then
    show_message 'BEGIN: Attempting Compression.'
    tar -czvf $backup_path/$backupfile $backup_path/$datetime | tee -a $log_path/$logfile
    show_message 'END: Attempting Compression.'
  else
    echo 'ERROR: Failed to Compress Mongo Backup because could not find backup destination directory path.' | tee -a $log_path/$logfile
    show_message 'END: Attempting Compression.'
    exit 1
  fi

#endregion Compress


#region Remove Temp

  if [ -f  $backup_path/$backupfile ]
  then
    show_message 'BEGIN: Removing Uncompressed Backup Files.'
    rm -rvf $backup_path/$datetime | tee -a $log_path/$logfile
    show_message 'END: Removing Uncompressed Backup Files.'
  else
    echo 'ERROR: Failed to Remove Uncompressed Mongo Backup because could not find the compressed file.' | tee -a $log_path/$logfile
    show_message 'END: Removing Uncompressed Backup Files.'
    exit 1
  fi

#endregion Remove Temp


#region Remove Out-of-Date Backups

  # Delete old at end to be sure there is a good backup before nuking old ones.  Hate to delete all the backups if backup failing for a long period of time.
  show_message 'BEGIN: Removing Out-of-Data Backups and Logs.'
  # If Backup Success
  if [ -f  $backup_path/$backupfile ]
  then
    backupcount=$(find $backup_path -mtime +$retention_days -type f -exec ls -f {} \; | wc -l)
    if [ $backupcount -gt 0 ]
    then
      backupfiles=$(find $backup_path -mtime +$retention_days -type f -exec ls -f {} \;)
      echo "REPORT: Found ($backupcount) out-of-date files to delete" | tee -a $log_path/$logfile
      # Remove Old Backups
      echo "ACTION: Attempting to Remove the Following Backup Files: $backupfiles" | tee -a $log_path/$logfile
      find $backup_path -mtime +$retention_days -type f -exec rm -vf {} \;
      # Determine Success
      if [ $? -eq 0 ]
      then
        echo 'REPORT: Removed Backup Files Successfully!' | tee -a $log_path/$logfile
      else
        echo 'ERROR: Failed to Remove Older Mongo Backup Files.' | tee -a $log_path/$logfile
        show_message 'END: Removing Out-of-Date Backups and Logs.'
        exit 1
      fi
      # Remove Log Files
      logcount=$(find $log_path -mtime +$retention_days -type f -exec ls -f {} \; | wc -l)
      if [ $logcount -gt 0 ]
      then
        logfiles=$(find $log_path -mtime +$retention_days -type f -exec ls -f {} \;)
        echo "REPORT: Found ($logcount) out-of-date backup log files to delete" | tee -a $log_path/$logfile
        # Delete Log Files
        echo "ACTION: Attempting to Remove the Following Log Files: $logfiles" | tee -a $log_path/$logfile
        find $log_path -mtime +$retention_days -type f -exec rm -vf {} \;
        # Determine Success
        if [ $? -eq 0 ]
        then
          echo 'REPORT: Removed Backup Logs Successfully!' | tee -a $log_path/$logfile
        else
          echo 'ERROR: Failed to Remove Older Mongo Backup Logs.' | tee -a $log_path/$logfile
          show_message 'END: Removing Out-of-Date Backups and Logs.'
          exit 1
        fi
      else
        echo "REPORT: No Out-of-Date Backup Logs Found" | tee -a $log_path/$logfile
      fi
    else
      echo "REPORT: No Out-of-Date Backups Found" | tee -a $log_path/$logfile
    fi
  else
    echo 'ERROR: Failed to Remove Older Mongo Backups and Backup Logs because could not find the compressed file.' | tee -a $log_path/$logfile
    show_message 'END: Removing Out-of-Date Backups and Logs.'
    exit 1
  fi
  show_message 'END: Removing Out-of-Date Backups and Logs.'

#endregion Remove Out-of-Date Backups


#region Results

  show_message 'BEGIN: Display Results.'
  echo 'File:       $backup_path/$backupfile' | tee -a $log_path/$logfile
  backup_size=$(du -h $backup_path/$backupfile | cut -f 1)
  echo 'Size:       $backup_size' | tee -a $log_path/$logfile
  endtime=$(date)
  runtime=$(date -d @$(($(date +%s)-$starttime_seconds)) +"%H:%M:%S")
  echo 'Starttime:  $starttime' | tee -a $log_path/$logfile
  echo 'Endtime:    $endtime' | tee -a $log_path/$logfile
  echo 'Runtime:    $runtime' | tee -a $log_path/$logfile
  show_message 'END: Display Results.'

#endregion Results