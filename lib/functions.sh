

	################################################################################################################################
	##															      ##
	##		THIS ARE ALL THE FUNCTIONS OF THE SCRIPT BE WARY OF MAKING CHANGES IN HERE SINCE THEY MAY AFFECT	      ##
	##		OTHER PARTS OF THE SCRIPT. ALL THESE ARE USED AS OF NOW DEPENDING ON THE FLAGS SET			      ##	
	##															      ##	
	################################################################################################################################


source '../conf/config.sh' 2>/dev/null
	
	################################################################################################################################
	##	Create a tmp file via the mktemp program, this should help to create unique filenames, if it fails for any reason
	## 	it complains and function falls back to the old schema (used in previous versions).
	##
	##	Returns Mail Message File Name
	################################################################################################################################
	function getMailMsgFile
	{
		# Create mail msg file
		fileName=$($_mktemp /tmp/mailMsg.XXXX) || { sayLoud "Could not create mail msg file! will fall back to old method";fileName="/tmp/mailmsg.txt"; }
		return $fileName
	}

	#
	################################################################################################################################
	##
	##	Mounts the SMB network share, currently it connects to $serverPath share and it mounts it in $smbMountPoint 
	##	Current credentials are static and set in Samba variables section.
	## 	If (when) this credentials change script will fail to execute.
	##
	## 	If there's a problem mounting the share then it tries to umount it (just to be on the safe side, via leaveAndMail)
	##	See leaveAndMail function for details
	##
	################################################################################################################################
	function mountShare()
	{
		# Sometime permission problems blocks the script from overwriting log. Erase old log before proceeding
		$_rm $dumpPlace/error.log  2>/dev/null #We dont acre about rm failures 
		toLog "Rm called for OLD error log"

		if [ -e $smbMountPoint]
		then
			sayLoud "=============================== "
			sayLoud "Mounting share to copy backup..."
			{
			$_mountCifs $serverPath $smbMountPoint/ -o user=$credentials 2>>$errorLog
			} && { sayLoud "Mount...succesful"; }|| { sayLoud "Mount...Failed!";leaveAndMail; }
		else
			sayLoud "$smbMountPoint its already mounted"	
			toLog "No need to call mount lets continue..."
		fi
	}

	################################################################################################################################
	##
	## 	Checks for folders existence and appropriate permissions on them before attempting to save the backup files
	##
	################################################################################################################################
	function checkShare
	{
		checkPathExistence $smbMountPoint
		
		# Since checkPathExistence returns 1 if folder doesnt exists we can test for not zero return codes
		# and do some aditional logic, set remoteBackupIncomplete flag to true and log it
		{
		 checkPathExistence $dumpPlace 
		}|| { remoteBackupIncomplete="true";toLog "Directory $dumpPlace had to be recreated, you will need to check manually for missing previous backups on $dumpPlace "; }

 		checkPathExistence $lastWeekBackupFolder

		checkWritePermissions $dumpPlace
		
		checkWritePermissions $lastWeekBackupFolder

		toLog "All checks passed!"
		# If passed all above then continue
	}

	################################################################################################################################
	##
	##	Check that local paths to be acces exist before using them
	##
	################################################################################################################################
	function checkLocalPaths
	{

		# Checks if the folder we want to backup exists, if not we should quit, nothing to backup
		checkBackupTarget
		
		# Checks if folder where we locally put backups exists
		checkPathExistence $defaultBackupDir

	}
	
	################################################################################################################################
	##
	##	Checks if the folder we want to backup exists, if not we should quit, nothing to backup
	##	$1(Arg 1) (optional) Error message to display via sayLoud
	##
	################################################################################################################################
	function checkBackupTarget
	{
		path=backupTargetDir
		errorMsg=$1

		if [ ! -d $path ]
		then
			# Default msg
			sayLoud "$path doen't exists, theres nothing to backup! I'll quit"
			
			# Display optional msg if var is set
			if [ ! -z "$errorMsg" ]
			then
				sayLoud $errorMsg
			fi

			leaveAndMail
		fi
	}
	
	################################################################################################################################
	##
	##	Use this to check paths existence
	##	$1 (Arg 1) the path to check
	##	$2 (Arg 2) (optional) Error message to display via sayLoud
	##
	################################################################################################################################
	function checkPathExistence
	{
		path=$1
		errorMsg=$2
		 #Checks if SMB mount point exists, if not there is no point in checking folders below
		if [ ! -d $path ]
		then
			# Default msg
			sayLoud "$path doesn't exists!, I will try to create it"
			
			# Display optional msg if var is set
			if [ ! -z "$errorMsg" ]
			then
				sayLoud $errorMsg
			fi

			{
			mkdir $path 2>>$errorLog
			} && { 
				sayLoud "$path Creation...succesful";
				}|| {
					sayLoud "$path Creation...Failed!";leaveAndMail; 
				}		
	
			# Folder did NOT existed, pass 1 to signal this condition
			return 1;
		else
			toLog "Path: $1 exists, check passed"
		fi
	}

	################################################################################################################################
	##
	##	Use this to check for write permissions on a path
	##	$1 (Arg 1) the path to check
	##	$2 (Arg 2) (optional) Error message to display via sayLoud
	##
	################################################################################################################################
	function checkWritePermissions
	{
		path=$1
		errorMsg=$2
		 #Checks if SMB mount point exists, if not there is no point in checking folders below
		if [ ! -d $path ]
		then
			if [ ! -w $path ]
			then
				# Default msg
				sayLoud "I have not write permissions on $path I'll quit"
			else
				toLog "Seems like I have Write permission on $path"
			fi

			# Display optional msg if var is set
			if [ ! -z "$errorMsg" ]
			then
				sayLoud $errorMsg
			fi
			leaveAndMail
	
		fi

	}
	
	################################################################################################################################
	##
	##	Informs the user that backup copy is in progress and then it proceeds to copy backup files to the recipient server.
	##	After copy to remote server is done, the samba share is unmounted 
	##
	################################################################################################################################
	function saveBackup()
	{
		# Set as a reminder to later implement speed mesurements in data transmission
		#size=$(du $defaultBackupDir/$outputName.tgz | awk '{ print $1 }')

		# Checks if incomplete for alerts and possible transferAll mechanism
	        if [ "$remoteBackupIncomplete" == "true" ]
        	then
			toLog "Remote Backups were imcomplete, run checkIncompleteBackups"
		
			checkIncompleteBackups
		fi

		if [ "$transferAll" == "false" ]
		then
			# Remote backups seem to be Complete!
			
			toLog "Remote backups look ok"

			# Copy files and tell user copy is in progress
			sayLoud "Saving file please wait..."
			sayLoud "Backup transfer started at $_date"
			{ 
				$_cp $defaultBackupDir/$outputName.tgz $dumpPlace/ 
			} && { sayLoud "Transfer completed at $_date";sayLoud "Backup save...succesful";}|| { 
			sayLoud "Backup save...Failed! File transfer was interrupted. Backup could not be saved to its configured remote destination. Remember that the backup is still in $defaultBackupDir";leaveAndMail; }
		
			# Copy Incremental data file
			$_cp $defaultBackupDir/log.snar $dumpPlace/ 2>>$errorLog
			toLog "Copy of incremental file called"
		
			toLog "About to copy errorLog to remote share. This will be the last line on remote errorLog this is expected"
	
			# From this point and on, messages will only appear on local errorLog
			$_cp $errorLog $dumpPlace/
			toLog "Copy of erroLog file called"
		
		fi
	}
	
	################################################################################################################################
	##
	##	Use this function to output to user (or console) while also saving the output to the log file
	##
	################################################################################################################################
	function sayLoud()
	{
		echo $1
		echo $1 >>$errorLog
	}

	################################################################################################################################
	##
	##	Use to save data to error log file. Only saves the info if debugging is ON.
	##
	################################################################################################################################
	function toLog()
	{
		if [ "$debugging" == "true" ]
		then
			echo $1 >>$errorLog
		fi
	}

	################################################################################################################################
	##
	##	Creates a tar archives from the $backupTargetDir directory (ussually / ), it excludes as many directories as needed
	##
	##	If more are needed simply add them.
	##	The function excludes this backup file folder (itself) to avoid recursion ;)
	##
	##	Now the backup is incremental, the incremental info in saved in a file name log.snar extension is as specified in tar docs
	##
	################################################################################################################################
	function tarIt()
	{
	sayLoud "Creating tar archive..."
		{
		$_tar $tarOptions $1/$outputName.tgz --same-owner --exclude=$1/$outputName.tgz $tarExcluded --listed-incremental $snarLog $backupTargetDir 2>>$errorLog
	
		} && { 
			sayLoud "Tar process...succesful";toLog "This means local file has been succesfully created"; 
			}|| 
			{ toLog "Tar was executed like this: 
			$_tar $tarOptions $1/$outputName.tgz --same-owner --exclude=$1/$outputName.tgz $tarExcluded --listed-incremental $snarLog $backupTargetDir";checkErrorCode "$tar"; 
			}
	}	

	################################################################################################################################
        ##
        ##	Checks other programs error codes, you need to pass who (what program) caused the error, so the fucntion
        ##	can process the logic. 
	##
	##	The porpouse of this functions is to allow the script to "permit" a certain degree of errors from the programs
	##	without completly failing or interrumping scritp behavior. With this function you can check what program failed, then
	##	make the logic to trap the error code you wanna catch, and instead of completly failing and exiting only output something
	##	and continue to operate normally.
	##
	##	Each program has its own error codes so before adding them here check man pages
        ##	or other documentation for each program. You can find a list of who on the top of the script, the listed of called commands
        ##
        ##	Example: checkErrorCode "$who"  It is important to use the quotes
        ##
        ## 	To check for Tar error codes you should call it like this: 
	##
	## 	checkErrorCode "$tar" 
	##
	## 	Then you can implement your tar exclusive logic in the function for the appropiate error code.
        ##
	##	In the tar implementation below we allow the script to continue without completly quitting, this allows tar to
	##	output errors, which will trip the leaveAndMail function (that in turn will log error, mail root and quit)
	##
	################################################################################################################################
	function checkErrorCode
	{
		errorCode=$? # we have to preserve error code cause it will be overwrite on any next command execution
		who=$1 	# The guilty program

		# If the $mailNonFatalErrors variable is set to true, mark execution as dirty to trip log and mail to root
		if [ "$mailNonFatalErrors" == "true" ]
		then
			sayLoud "Will mark execution dirty, but this are non fatal errors. See the checkErrorCode function for more info"
			isDirty="true"

			toLog "Execution just marked as dirty"
			toLog "By $who with Error code $errorCode"
		fi


		#################################
		#	    Tar Section	        #
		#################################
		if [ "$who" == "$tar" ]
		then

			# Tar error code number 2 means that Tar finished with errors but finished anyway
			# so its ussually ok to keep script running even when this happens
			if [ "$errorCode" == 2 ]
			then
				if [ -e $workDir/$outputName.tgz ]
				then
					sayLoud "Tar process...had some errors but managed to finish archive...lets continue"
				else
					sayLoud "Tar process...Failed! Archive file could not be created check error log"
					toLog "This IS a fatal error"
					leaveAndMail
				fi
				#return 0;
				#exit
			else
				sayLoud "Tar process...Failed! Could not create Tarball Fatal Error"
				sayLoud "Check error log for more info!"
				leaveAndMail
			fi
		fi
		
		#################################
		#	uMount Section		#
		#################################
		
		# change who for program variable name
		if [ "$who" == "$umount" ]
		then
			# Check if share is not mounted
			if [ "$errorCode" == 1 ]
			then
				# Since we ended up with error code 1 we assume share is no longer mounted
				sayLoud "Umount complained of error 1, share seems to be unmounted already!"

				# if we dont exit here, leaveAndMail will be called again (cause execution was dirty) this
				# will result in a loop calling leaveAndMail infinitly, Exit now to avoid loop condition
				exit
			else
				sayLoud "Unmounting...Failed! This is no relevant to the Backup, however you may want to try and umount SMB share mannualy"
				toLog "This IS a fatal error"
				leaveAndMail
			fi
		fi

		#################################
		#	Template Section	#
		#################################
		#
		# Use this template for the programs you may wanna check
		#
		# change $name for program variable name, example $tar
		#if [ "$who" == "$name" ]
		#then
		#	# Check error code number
		#	if [ "$errorCode" == number ]
		#	then
		#		# Logic for this code
		#		exit
		#	else
		#		# Logic for other codes
		#	fi
		#fi

	}

	################################################################################################################################
	##
	##	This functions calls doBackup according to the backup mode (incremental or full). This depends on 2 things
	##	-Number 1, if today is $fullBackupDay, a full backup will be started. 
	##	-Number 2 if no previos backups were found, run full
	##
	##	If none of those were present assume backup is incremental. Bear in mind (however) that the check is only local
	##	we don't check for previous remote backups. That is if locally we have a previous full and we'r doing incremental
	##	we will only transfer that incremetal to the SMB share. We never check if all files in here are also there, we asume they are.
	##
	#################################################################################################################################
	function backup()
	{
		if [ "$weekDay" == "$fullBackupDay" ] #Is fullBackupDay do a full backup!
		then
			toLog "Full Backup day"
			isFull=true
			#echo "Full"
			doBackup
			umountNow
		elif [ "$(ls --hide=error.log --hide=lost+found $workDir)" ] # Directory is NOT empty except for error log and lost+found folder, do incremental backup
		then
			toLog "Found other files, backup marked as incremental"
			isFull=false
			#echo "Not empty Incremental"
			doBackup
			umountNow
		else #Is not fullBackupDay but backup folder is empty (No previous full backups). Do a Full backup, cannot do incremental
			toLog "Backups folder is empty, I will do a Full Backup"
			#echo "else full"
			isFull=true
			doBackup
			umountNow
		fi
	
		sayLoud "All done"
	}

	################################################################################################################################
	##
	##	Use this function to umount the SMB share, it checks if backups was set to remote before calling umount
	##	if true umount otherwise no point in calling it
	##
	################################################################################################################################
	function umountNow
	{	
		if [ "$Remote" == "true" ]
		then
			toLog "Calling umount"
			# If any error stoped the script from umounting the samba share unmounting NOW!
	                {
                	$_umount $smbMountPoint 2>>$errorLog
			} && { sayLoud "Unmounting share...succesful"; }|| { checkErrorCode "$umount"; }
		fi
	}
	
	################################################################################################################################
	##
	##	This is the actual worker, this function will call all the others in order according with a set of conditions
	##	
	##	Summary of behavior
	##
	##	If the backup is marked as FULL then erease old backups in $defaultBackupDir then tar and gzip the $backupTargetDir
	##	mount the SMB share and MOVE old backups to $lastWeekBackupFolder (if any old backups) to finish save the backup files 
	##	to the SMB share
	## 
	##	If backup is marked as NON full ($isFull=false) tar and gzip incremental then mount SMB share and copy the files to it
	##
	##	Another check has been added to the script so that it verifies whether the backup is marked as a RemoteBackup or not,
	##	if marked as local only then, share wont be mounted and no transfer will happen with remote server, only tar ang gzip
	##	will be called and backup will remain $defautlbackupDir
	##
	################################################################################################################################
	function doBackup
	{
		if [ "$isFull" == "true" ]
		then
			# Today is full backup day
			sayLoud "Preparing to do a FULL backup"
			
			# Rename this backup as full
			outputName="$fullBackupName"

			sayLoud "Deleting current (local) backups..."

			# Clean previous backups, locals first, this will remove everything but current log
			$_find $workDir -maxdepth 1 -not -iname "error.log" -not -type d -exec rm {} \; 2>>$errorLog && { 
			sayLoud "Old (local) backups gone!"; } || { sayLoud "Could not erase old (local) backups, will quit!"; leaveAndMail; }
			
			# Create the tar archive
			tarIt $workDir
			
			# After tar all local is done check if we should transfer a remote copy		
			if [ "$Remote" == "true" ]
			then
				# About to clean remote backups mount share now
				mountShare
				# We cant check path existence or permissions if not munted
				checkShare

				# Move previous backups to another folder, move instead of erase to avoid ending up with no backups at all
				# in the event that any error will break the process
				cd $dumpPlace/
				if [ "$(ls -A)" ] # Directory is NOT empty, move backups
				then
					# if set to true we must clean folder first
					if [ "$removeOldBackups" == "true" ]
					then
						toLog "Trying to remove old backups"
						$_rm $lastWeekBackupFolder/* && { sayLoud "Old backups removed!"; } || { 
						sayLoud "Could not remove old backups...but I'll continue..."; }
					fi
					# Move last backup to $lastWeekBackupFolder
					$_mv * $lastWeekBackupFolder/ 2>>$errorLog && { sayLoud "Old (remote) backups moved!"; } || { 
					sayLoud "Could not move old (remote) backups, will quit!"; leaveAndMail; }
				else
					sayLoud "I could not found any remote backups. This usually means this is the first run OR backups were ereased";
				fi

				sayLoud "Ready to push new backups"
			
				#Copy backup to server
				saveBackup
			
			elif [ "$Remote" == "false" ]
			then
				alertLocalBackup
			fi
		else
			# Today is incremental backup day
			sayLoud "Preparing to do an Incremental backup"

			#Create the tar archive
			tarIt $workDir
			
			# After tar all local is done, check if we should transfer a remote copy				
			if [ "$Remote" == "true" ]
			then
				#About to clean remote backups mount share now
				mountShare
				checkShare

				#Copy backup to server
				saveBackup	
			
			elif [ "$Remote" == "false" ]
			then
				alertLocalBackup
			fi
		fi
	}
	
	################################################################################################################################
	##
	##	Alert that backup is only happening on the local filesystem
	##
	################################################################################################################################
	function alertLocalBackup()
	{
		sayLoud "Remote backups are disabled, backup has been saved on local file system!!"
		# Successful backups is assumed if we reach this point
		sayLoud "Backup save...succesful";
	}

	################################################################################################################################
	##
	##	This is used when remoteBackups were incomplete. 
	##	First alerts user, and if backup is incremental and $tranferAll is true do a complete transfer of backups. 
	##	If backups is full only alert user and continue
	##
	################################################################################################################################
	function checkIncompleteBackups
	{
		#We know remot backups are incomplete cause we mark it so when we found NO REMOTE folder. So we create it, that means there are no prior incrementals there
		toLog "No remote folder!"
		toLog "I'll mark execution as dirty to inform of problem above via mail"
		isDirty="true"

		if [ "$isFull" == "true" ]
		then
			sayLoud "Since this is a FULL backup there should be no problems. I will send the FULL backup to the Remote destination"
		else # Meaning is an incremental backup
			if [ "$transferAll" == "true" ]
			then
				sayLoud " This transfer may take longer than usual, cause we recreated the remote backup folder so Im about to send all current backups stored locally to remote server, please be patient."

				$_cp $defaultBackupDir/*.tgz $dumpPlace/ 2>>$errorLog && { sayLoud "Backup save...sucessful!"; } || { 
				sayLoud "Backup save...failed!";leaveAndMail;}

			else
				sayLoug "transferAll is off, this means that I will only transfer the incremetal backup I just made to the remote host"
				sayLoud "Since this is an incremental backup, this means that previous incrementals (if any) or prevoius FULL backups will not be transfered/stored on remote server, I will only transfer the most recently created backup, you can always override this behaviour via the transferAll flag"
			fi
		fi
	}

	################################################################################################################################
	##
	##	Use this function to signal an important error that will make the script fail and exit. This will send an informative
	##	mail to $whom2mail letting them know there was a problem with the backups.
	##
	##	The content of the mail is stored in $mailmsg. The error log is appended along with a human friendly message
	##
	################################################################################################################################
	function leaveAndMail()
	{
		
		now=$(date +%c)
		## Append human friendly message, with name of the script and hostname, then append the log 
		echo  > $mailmsg
		echo "There was a problem with a script execution please check the information below to diagonose" >> $mailmsg
		echo "Script: $0" >> $mailmsg
		echo "Hostname: $hostname" >> $mailmsg
		echo  >> $mailmsg
		echo "The error log is attached.">> $mailmsg
		echo  >> $mailmsg
		echo  >> $mailmsg
		echo "===================  START ERROR LOG  ===================" >> $mailmsg
		cat $errorLog >> $mailmsg
		echo "Error log finished at...$now" >> $mailmsg
		echo "===================   END ERROR LOG   ===================" >> $mailmsg
		echo  >> $mailmsg
		
		## Appends done, send the mail
		$_mail -s "$mailSubject" $who2mail < $mailmsg
		
		# Message content no longer relevant delete
		$_rm $mailmsg && { toLog "$mailmsg deleted!"; } || { toLog "Could not delete $mailmsg"; }
		
		# If any error stopped the script from unmounting the samba share unmounting NOW!
		umountNow
		
		toLog "All must be done, about to quit"
		#Ready to quit
		exit
	
	}
	
	################################################################################################################################
	##
	##	Use it to check if execution was marked as dirty. Dirty executions are logged and usually mailed to $whom2mail as long
	##	as $mailOnDirty is set to true
	##
	################################################################################################################################
	function checkDirty()
	{
		if [ "$isDirty" == "true" ]
		then
		sayLoud "Execution was Dirty!"
			if [ "$mailOnDirty" == "true" ]
			then
				leaveAndMail
			else
				toLog "MailOnDirty set=$mailOnDirty"
			fi
		fi

	}
	
	################################################################################################################################
	##
	## Write Dump backups information to Log
	##
	################################################################################################################################
	function debugDump()
	{
		toLog "Variables data used:"
		echo >> $errorLog
		toLog "Backup target dir=$backupTargetDir"
		toLog "Backup mode, Remote=$Remote"

		if [ "$Remote" == "true" ]
		then
			toLog "SMB mount point=$smbMountPoint"
			toLog "Server path=$serverPath"
			toLog "Last Week backup folder=$lastWeekBackupFolder"
			toLog "Transfer All mechanism=$transferAll"
		fi

		toLog "Files dump place=$dumpPlace"
		toLog "Tar options used=$tarOptions"
		toLog "Tar exclusion list=$tarExcluded"
	}

	################################################################################################################################
	##
	##	Called at the start of the program to initialize the first params for the error log file. If  not called at the beginnig
	##	of the script then log file may not be complete. We should ALWAYS call this function first
	##
	################################################################################################################################
	function startLogger()
	{
		# Remove (old) log before writing to it
		$_rm $errorLog &> /dev/null

		now=$(date +%c)

		echo "$0 Script Error Log " > $errorLog
		echo >> $errorLog
		echo "Logging started...." $now >> $errorLog
		echo >> $errorLog
		
		if [ "$debugging" == "true" ]
		then
			sayLoud "Debugging is ON"
			echo >> $errorLog 
			sayLoud "Saving log to $errorLog"
			echo >> $errorLog 
			debugDump
			echo >> $errorLog 
		else
			toLog "Debugging is OFF" # Not really useful to see this only log it
			echo >> $errorLog
		fi
	}

