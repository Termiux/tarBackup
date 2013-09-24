#!/bin/bash


##################################################################################################################
##														##
##   tarBackup shell script Tested on RHEL 5 and Debian 7							##
##   Jorge A. Moreno morenog.jorge@gmail.com									##
##   System Backup Bash Shell Script										##
##														##
##    You can use the script to backup your server using tar/gzip. Script can copy the backup files to a SMB	##
##    share on another server, or just keep the backups locally if you wish. 					##
##														##
##    I've made some improvements, so its a little more smart now when something bad happens. 			##
##    It also tries to inform you every time something unexpected happens so you always know what is going on.	##
##														##
##  How to use the script:											##
##														##
##	To use the script, you need to set a few values first. Check README File to know what you need to do	##
##														##
##	To use just drop the script in /etc/cron.daily/ or set it editing crontab. After that just forget it.	##
##	If your cron is well configured you will be mailed of the script output. Anyway you will still be 	##
##	mailed if something bad happens you will always be informed ;)						##
##														##
##														##
##	>>> For detailed information about configuration and usage explanation consult the README file	<<<	##
##														##
##################################################################################################################

##################################################
##		Variables Declarations		##
##################################################

source '.'
	# Run everything!	
	workDir=$defaultBackupDir
	startLogger
	backup
	checkDirty
	exit
