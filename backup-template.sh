#!/bin/bash

now() {
	date -u +"%Y-%m-%d_%H-%M-%S"Z
}

delete_pidfile() {
	if [ -f $PIDFILE ]; then
		rm $PIDFILE
	fi
}

create_dirlog() {
	if [ ! -d $LOG_DIR ]; then
		mkdir $LOG_DIR
	fi
}

#---------------------------------------------------#
# 	PARAMETROS
	SOURCE_HOST=
	RSYNC_MODULE=
	BKP_DEST_DIR=
	RSYNC_EXCLUDE_FILE=rsync.exclude
#---------------------------------------------------#

BASE_DIR=$(dirname "$0")
BASE_NAME=$(basename -- "$0")
LOG_DIR=$BASE_DIR/log
PIDFILE=`readlink -f "$0"`.pid
LOGFILE=$LOG_DIR/$BASE_NAME'_'`now`.log

create_dirlog

echo -e "----------------------------------------------------------------------------" 		>> $LOGFILE
echo	"Proceso $0 iniciado" `now` 														>> $LOGFILE
echo -e "----------------------------------------------------------------------------\n"	>> $LOGFILE

if [ -f $PIDFILE ]; then
	PID=$(cat $PIDFILE)
	ps -p $PID > /dev/null 2>&1
	
	if [ $? -eq 0 ]; then
		echo "Process already running" >> $LOGFILE
		exit 1
	else
		## Process not found assume not running
		echo $$ > $PIDFILE
		if [ $? -ne 0 ]; then
			echo "Could not create PID file" >> $LOGFILE
			exit 1
		fi
	fi
else
	echo $$ > $PIDFILE
	if [ $? -ne 0 ]; then
		echo "Could not create PID file" >> $LOGFILE
		exit 1
	fi
fi

IS_ONLINE=`ping -s 1 -c 2 $SOURCE_HOST >> $LOGFILE 2>&1; echo $?`

if [ $IS_ONLINE -eq 0 ]; then
	echo -e "\nEl host" $SOURCE_HOST "esta online --> Backup iniciado" `now` >> $LOGFILE
	rsync -vtr --timeout=15 --delete --stats --exclude-from=$BASE_DIR/$RSYNC_EXCLUDE_FILE $SOURCE_HOST::$RSYNC_MODULE $BKP_DEST_DIR/$RSYNC_MODULE >> $LOGFILE 2>&1
	
	if [ $? -ne 0 ]; then
		echo "============> ERROR <============"	>> $LOGFILE
		echo "ERROR: rsync fallo con error code" $?	>> $LOGFILE
		echo "Proceso finalizado" `now`				>> $LOGFILE
		delete_pidfile
		exit 1
	else
		echo "Backup finalizado" `now` >> $LOGFILE
	fi

	delete_pidfile
	exit 0
else
	echo "El host" $SOURCE_HOST "no esta online --> Backup no realizado" >> $LOGFILE
	echo "Proceso finalizado" `now` >> $LOGFILE
	delete_pidfile
	exit 0
fi
