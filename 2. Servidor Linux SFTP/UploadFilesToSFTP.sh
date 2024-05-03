#!/bin/bash
# Variables Iniciales
# Script: UploadFilesToSFTP
# Description: It runs every 1 minutos, and transfers files older than 1 minutes to SFTP server
# Args:
# $1: Number Of Queue  


# Variables Iniciales
numberOfAudios=100
timeForFile=1 # Tiempo de antiguedad del file para que se procese
directory="/home/usuarioftp"
logFile="/tmp/LogUploadFilesToSFTP.log"
LogEnabled=1
echo $logFile
PATHFILES="/home/usuarioftp/FTPSpeech$1/speechanalytics$1"
inFile=""
outFile=""
ftpuser="win-user"
ftppassword="pwd" #actualizar password
recordingremotehost="usftpcorp.inconcertcc.com"
remotedirPath="/speechanalytics"
remotedir=""


logInfo() {
	if [ "$LogEnabled" == 1 ]; then
		echo `date +%r-%N`  "INFO: $1" >> $logFile
	fi
}

logError() {
		echo `date +%r-%N` "ERROR: $1" >> $logFile
}

main(){	

	logInfo "ps aux | grep '/usr/sbin/UploadFilesToSFTP.sh $1' | wc -l"
	
	if [ "$1" == ""  ]; then
		logInfo "Debe especificar un argumento"
		exit 1
	fi

	inProcess=$(ps aux | grep '/usr/sbin/UploadFilesToSFTP.sh $1' | wc -l)
	echo inProces = $inProcess
	if [ "$inProcess" -ge "3" ]; then
		logInfo "Otro proceso esta en memoria"
		exit 1
	fi 
	
	
        logInfo "Eliminando subdirectorios vacíos dentro de $PATHFILES y sus subdirectorios"
        find $PATHFILES -mindepth 1 -type d -empty -delete

        logInfo "Procesando archivos"	
	logInfo "Procensado como máximo $numberOfAudios "

	for file in $(find $PATHFILES -maxdepth 5 -type f -print | head -n$numberOfAudios)
	do
		
		logInfo "archivo $file"
                local uploaded=0;
		inFile=$file
		callIdentification=$(basename $inFile)
		callIdentification=$(sed 's/.wav//g' <<< $callIdentification)
		if [[ -f $inFile ]]; then
			logInfo "$inFile exist. Uploading files to SFTP Server"
			logInfo "Executing SFTP command"
			
			relative_path=$(dirname ${inFile#$PATHFILES/})
			remotedir=$remotedirPath"/"$relative_path
			
			cmd='lftp -u $ftpuser,$ftppassword sftp://$recordingremotehost -e "mkdir -p $remotedir;put -O $remotedir $inFile; bye"'
			eval $cmd >> $logFile 2>&1
			uploaded=$?
			if [ "$uploaded" == 0 ]; then
				logInfo "Files uploded ok to sftp server for id:$callIdentification" 
				rm -f $inFile  

			else
				logError "Error transfering file for $callIdentification to sftp server" 
				#mv $inFile "$FAILEDPATH/."
				logInfo "Fallo $callIdentification. Procesando siguiente archivo."	
			fi
		fi
	done
}

main $1
