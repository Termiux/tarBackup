#!/bin/bash

source './conf/config.sh' 2>/dev/null
source './lib/functions.sh' 2>/dev/null

	# Run everything!	
	workDir=$defaultBackupDir
	#Star logging before doing anything else
	startLogger 
	#Star the backup process
	backup
	#Check if execution was marked as dirty
	checkDirty
	exit
