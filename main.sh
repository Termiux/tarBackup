#!/bin/bash

	echo "Starting now...1"
source './conf/config.sh'
	echo "Starting now...2"
	# Run everything!	
	workDir=$defaultBackupDir
	echo $workDir
	#workDir=/home/admin/Backups
source './lib/functions'
	startLogger
	backup
	checkDirty
	exit
