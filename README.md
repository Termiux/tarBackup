   tarBackup shell script v0.5.2
   Backup Bash Shell Script								
================================
   Tested on RHEL 5, and Debian 6
   GitHub: https://github.com/Termiux/tarBackup

   Jorge A. Moreno morenog.jorge@gmail.com
   http://www.var-log-it.com/

-------------------------
You can use the script to backup your server using tar/gzip. Script can copy the backup files to any mount point or config it to dinamically mount an SMB share.

How to use the script
------------------------
									
To use the script, you need to set a few values first. It is recommended to read the script working explanation below. Then you can set your own settings. 
To use just drop the script files in /etc/cron.daily/ or set it editing crontab. After that just forget it. If your cron instance is well configured you will be mailed of the script output. Anyway you will still be mail if something unexpectd happens.
												
Default Script Behavior
-------------------------													
You can override default behavior using flags. 

The default is as follows:				
Script makes a Tar Gzip file of $defaultBackupDir depending of the day of the week or if previous incremental backups exist. If script can't find previous incremental backups it performs a FULL backup regardless of the day 	of the week. Otherwise Full backups ocurr only on $fullBackupDay. After tar/gzip are done the script will try and save the created backup tar/gzip file to $dumpPlace. When $Remote is true (default: false) the script assumes you want to save to connect to a remote SMB share. The script will mount the share look for the the $dumpPlance directory (or create it) and will quit after done.												
If things go well it checks for 'Remote' previous backups.If found this backups are then moved! to $lastweekBackupFolder. If not found (or after move is done), new backup is dump in $dumpPlace. Share is then unmounted and script finishes execution.

If something goes wrong during execution you will be informed by mail. Recipient is set in $whom2mail (default is set to root). The mail will be accompanied by a error log so you can check what went wrong.

>	IF YOU DON'T WANNA READ DESCRIPTION, DEFAULT OPTIONS ARE USUALLY OK
>	However there are still variable you must set:								

	*** Open the file config.sh files that MUST be set are marked so ***
														
	Default values are as follow: 
	Backups will be remote, saved to a SMB Share
	Create Full Backup every Sunday, Incremental the rest of the week.
	 Mail on dirty execution(when something bad ahppens)	
														
	Following MUST be set:											
	$backupTargetDir									
	$credentials		==> Not necessary if $Remote set to false
	$smbMountPoint		==> Not necessary if $Remote set to false
	$serverPath		==> Not necessary if $Remote set to false
	$lastWeekBackupFolder	==> Not necessary if $Remote set to false
	$dumpPlace		==> Not necessary if $Remote set to false				
`														
Important Flags
-------------------------													
											
You can check variables definition for detailed information, here is a list of things will you probably want to override with existent flags:

	Remote Backups ($Remote): Remote backups can be made to be local only. Default: false

	Full Backup Day ($fullBackupDay): Sets the number of the day of the week when you would like to run a Full Backup. Day number is based on date program day starts on Monday (1). Default 7 (Sunday)
	
	Mail On Dirty	($mailOnDirty): Controls whether you wanna receive a mail notification when script execution was marked as dirty. A dirty execution is when script encountered non fatal errors so it managed to finish. Default: true														
	Remove Old Backups ($removeOldBackups): We use the $lastWeekBackupFolder to store last week backups. When script runs and connects to remote SMB share it moves your last weeks backups to that folder and puts the new backup in $dumpPlace. However after a few weeks that folders gets all previous backups and gets big in size. Use this to erase those backups, and hold ONLY the last week backup and not all previous backups. Default: false

	Transfer All ($transferAll): Sometimes (for example) if files were modified manually things can get messed up. Lets say someone erase your remote backups on a Monday. However you still have this week local backups. When the script runs it assumes you are making a incremental backup cause of your have other incremental and FULL for this week but once the share is mounted and folder inspected it realizes that the remote backups are none existent. This differs from your locals. So it alerts of it saying that only the current incremental backup (the one we're doing today) will be transfered. 

	Use this flag to override this and transfer the missing backups too (previous incrementals and full) so you have a complete Full and incrementals in the remote location, just as you do locally. Default: false

CHANGES in this version (Major version)
-------------------------									
  - A lot of code has been refractored, moved around to easy configuration
  - A few bugs corrected

  TO DO's
-------------------------
	- [x] Refractor code to ease code management
	- [x] Separate config from rest of the code to ease configuration
	- [ ] Need to make usage of normal mount points easier
	- [ ] $transferAll implementation is ugly, needs improvement
	- [ ] Current user and pass schema its insecure needs improvement
	- [x] Allow easier adaptation to other servers
	- [ ] Improve the isDirty mechanism
	- [x] Improve the checkErrorCode mechanism to make it easier to use
	- [x] Fix program paths problems
	- [x] Make script debugging easier
	- [x] Make script more verbose												
