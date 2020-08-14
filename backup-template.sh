#!/bin/bash

function now() {
	date -u +"%Y-%m-%d_%H-%M-%S"Z
}

function create_dirlog() {
	if [ ! -d $log_dir ]; then
		mkdir $log_dir
	fi
}

function finalizar_proceso() {
	if [ -f $pidfile ]; then
		rm $pidfile
	fi
	if [ $2 -eq 0 ]; then
		echo `now` "Backup completado OK" >> $logfile
	else
		echo `now` "Backup NO completado" >> $logfile
	fi
	echo `now` "Proceso finalizado" >> $logfile
	exit $1
}

#---------------------------------------------------#
# 	parametros
	source_host=<DIERCCION_IP>
	rsync_module=<MODULO>
	bkp_dest_dir=<DESTINO>
	rsync_exclude_file=rsync.exclude
	max_reintentos=24
#---------------------------------------------------#

base_dir=$(dirname "$0")
base_name=$(basename -- "$0")
log_dir=$base_dir/log
pidfile=`readlink -f "$0"`.pid
logfile=$log_dir/$base_name'_'`now`.log
contador=1

create_dirlog

echo -e "----------------------------------------------------------------------------\n" >> $logfile

if [ -f $pidfile ]; then
	pid=$(cat $pidfile)
	ps -p $pid > /dev/null 2>&1
	
	if [ $? -eq 0 ]; then
		echo "ERROR: Ya existe una instanca del proceso en ejecucion" >> $logfile
		finalizar_proceso 1 1
	else
		## process not found assume not running
		echo $$ > $pidfile
		if [ $? -ne 0 ]; then
			echo "ERROR: No se puede crear el pid file" >> $logfile
			finalizar_proceso 1 1
		fi
	fi
else
	echo $$ > $pidfile
	if [ $? -ne 0 ]; then
		echo "ERROR: No se puede crear el pid file" >> $logfile
		finalizar_proceso 1 1
	fi
fi

while [ $contador -le $max_reintentos ]; do
	
	echo `now` "Intento Nro. $contador" >> $logfile
	is_online=`ping -s 1 -c 2 $source_host > /dev/null 2>&1; echo $?`

	if [ $is_online -eq 0 ]; then
		echo -e `now` "El host" $source_host "esta online --> Backup iniciado\n" >> $logfile

		rsync -vtr --out-format="%t %f %'''b" --stats -h --timeout=15 --delete --exclude-from=$base_dir/$rsync_exclude_file $source_host::$rsync_module $bkp_dest_dir/$rsync_module >> $logfile 2>&1
		
		if [ $? -ne 0 ]; then
			echo "ERROR: rsync fallo con error code" $?	>> $logfile
			finalizar_proceso 1 1
		else
			finalizar_proceso 0 0
		fi
	else
		echo -e "El host" $source_host "no esta online. Reintento...\n" >> $logfile
	fi
	
	contador=`expr $contador + 1`
	sleep 600
done

finalizar_proceso 0 1