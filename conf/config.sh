
##################################################################################################################
##														##
##		YOU NEED TO CHECK VALUES IN THIS FILE AND SET THEM TO MATCH YOUR SYSTEM				##
##														##
##	This file contains all variables used by the script, everything is commented so you know what it is	##
##	still if you dont know waht it does and cannot figure out with the comments then leave the default	##
##														##
##														##
##	>>> For detailed information about configuration and usage explanation consult the README file	<<<	##
##														##
##################################################################################################################


source '../lib/functions.sh' 2>/dev/null

##################################################
##		Variables Declarations		##
##################################################

###########################
## 	 Helpers	 ##	
###########################

#
# Runs hostname cmd to get the short hostname of current server. Hostname is used in the outputName of the final tar file
#
readonly hostname=$(hostname -s)

#
# Runs date cmd in full format. This outputs in Yeah-Month-Day format. This is used as a part of outputName of the final tar file
#
readonly currentDate=$(date +%F)

#
# Runs date cmd to get the current day of the week number. Date's man page states that this version take Monday as day 1. This number is used
# to properly schedule full or incremental backups
#
readonly weekDay=$(date +%u)

#
# Sets the outputName that the file will have. It assumed to always be incremental unless stated otherwise. If so variable will have to be reassigned.
# File name is made of short hostname + incremental_string + current date
#
outputName="$hostname"_Incremental_Backup_"$currentDate"

#
# File name of a full backup. Like outputName but for full backups.
#
readonly fullBackupName="$hostname"_FULL_Backup_"$currentDate"

#
# Holds the number of the day you wanna run a full backup. This number is dependent of date cmd number format check $weekDay for more info
#
readonly fullBackupDay="7"

#
# Helper variable. Used in checks to determinate if backup is full or incremental. Initial value is no really important
# but is safer to set it to something.
#
isFull="true"

###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Controls whether the backup will be saved in a remote location or it will be saved on local file system. False means backup is local only
#
readonly Remote="false"

#
# If script runs and finds errors it will mark execution as dirty. Dirty execution logs are sent to root. By default execution is not
# dirty unless marked otherwise. This usually happens when a program return a none zero exit.
#
isDirty="false"

#
# This are the options passed to tar when running the backup. czpf means (c)Create backup (z)Gzip it (p) Preserver permissions (f) is name
# that the tar file will get. Check tar man page for more info
#
readonly tarOptions="czpf"

###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Tar exclusion folders list. This is ugly, we could have easily used -X option and point to a exclusion list file but I don't like to work with many
# files. If you don't like it you can easily change it ;)
#
tarExcluded=" --exclude=error.log"

#
# If true mail will be deliver to $who2mail whenever script execution is marked as dirty.
#
readonly mailOnDirty="true"

#
# Off by default. Can be used to test for problems, it will output to errorLog ONLY. It outputs some variables data used and
# other performed steps.
#
readonly debugging="true"

###################################################################
##		Remote backups exclusive variables		 ##
###################################################################

###################
#
# Variables in this section only need to be set IF you set the $remoteBackup variable to true
#
###################

#
# Variables $transferAll and $removeOldBackups tested and working

#
# Controls whether the script will transfer all the current backups if remote folder had to be created
#
readonly transferAll="false"

#
# During a remote backup we move last week backups to $lastWeekBackupFolder this controls whether to keep them or delete them every week.
# If true folder will only hold last week backups. Old backups will be deleted!
#
readonly removeOldBackups="true"

#
# During a remote backup if its detected that remote backups are partial or non existent and this differs from local state
# then we set this flag to true so we can act with the transferAll mechanism (assuming is set to true)
#
remoteBackupIncomplete="false"



###########################
##	   Paths	 ##	
###########################


###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Set the directory you want to make a backup of. Point it to root if you wanna backup all the server data. 
# If you need to exclude certain folders, set this to those folder parent and then set the exclude list in the 
# proper variable.
#
readonly backupTargetDir="/home/admin/testBkpFolder"

###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Sets the default backups directory, all backups are saved here. If $Remote set to true, this is what will be copied to SMB share
#
export defaultBackupDir="/home/admin/Backups"

#
# Helper variable. Holds the current path we are working into. Unlike defaultBackupDir this changes over script execution
#
export workDir=$defaultBackupDir

###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Used by the Mount and Umount programs to (u)mount the SMB share make sure is valid!
#
smbMountPoint="/mnt/samba"						

###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Server address. You can set and ip and route to the SMB share or name and route
# Example //server.mycompany.com/SMBshare/folder
#
serverPath="//server/share"

#
# This is the path to folder where to store last week backups
# Example: "$smbMountPoint"/oldBackupsFolder
#
lastWeekBackupFolder="$smbMountPoint"/lastWeekBackup

#
# Where we will dump the backups if $Remote set to true
# Example "$smbMountPoint"/BackupsFolder
#
dumpPlace="$smbMountPoint"/Backups

#
# Name and location of the error log file
# Example: "$workDir"/logfile.log
#
errorLog="$workDir"/error.log

#
# Name and location of the incremental snar log file. This file is used by tar to make the incremental backups
# Example: "$workDir"/log.snar
#
snarLog="$workDir"/log.snar

###########################
##	   Samba	 ##	
###########################

###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# Credentials to authenticate on the SMB share. If (when) this change SMB mount will fail if authentication is needed
#
# Usage format: user%pass	Quote it if you need odd characters in your password
# Example: credentials="mike%thisIStheSUPERpassl33t0!%&"
#
# This approach is not very secure!! Improve in later versions, for the time being chmod og-rwx (strip non root from r/w/x)
#
credentials="user%pass"

###########################
##	Programs Names	 ##	
###########################

#
# Following variables are used for error code checking, you can use this to signal who you wanna check via the checkErroCode function
# 
# NOTE: This section is for debugging and further developing, as user you dont really need to change anything in here. All this are related
#       to the checkErroCode function. For more information check the 'checkErrorCode' function
#

#
# Tar program description
#
tar='Tar program with gzip'

#
# Mail program description
#
mail='Mail program'

#
# Mount program description
#
mount='Mount program to mount samba shares'

#
# Umount program description
#
umount='Umount program to Un mount samba shares'


###################################
##	   Programs Paths	 ##	
###################################


###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
#	Change this to reflect you distro commands paths
# Paths to binaries needed to avoid command not found problems

#_awk='/usr/bin/awk/'
#_whereis='/usr/bin/whereis'

_mv=$(whereis mv | awk '{print $2}')

_rm=$(whereis rm | awk '{print $2}')

_cp=$(whereis cp | awk '{print $2}')

_find=$(whereis find | awk '{print $2}')

_date=$(whereis date | awk '{print $2}')

_mktemp=$(whereis mktemp | awk '{print $2}')

_mail=$(whereis mail | awk '{print $2}')

_tar=$(whereis tar | awk '{print $2}')

_mount=$(whereis mount | awk '{print $2}')

_mountCifs=$(whereis mount | awk '{print $2}')

_umount=$(whereis umount | awk '{print $2}')

_hostname=$(whereis hostname | awk '{print $2}')

_date=$(whereis date | awk '{print $2}')


###########################
##	   Mail		 ##	
###########################


###################################################################################################################################
# 	>>>>>>>>>>>>>>>>>>>> 			MOST SET THIS VALUE BEFORE USING SCRIPT 		<<<<<<<<<<<<<<<<<<<<<<<<<<
#
#
# Who do we mail when something breaks. Default set to root
# This approach assumes you already have your mail server configured. If not mail will only be delivered locally only
#
who2mail="root"

#
# Mail subject when something breaks
#
mailSubject="There was a problem with the backups"


#
# Holds the email message file name. This is used to store the mail message when something breaks and someone must be informed
#
readonly mailmsg=getMailMsgFile
	
