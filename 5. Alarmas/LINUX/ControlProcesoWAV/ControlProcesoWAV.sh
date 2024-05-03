#!/bin/bash
# Variables Iniciales Script: ControlProcessWAV Description: It runs every 1 minutes, and stop the process of WAV generation, copying an old version of tkpostrecording.sh Variables 
# Iniciales
maxNumberOfAudios=1000
directoryBase="/home/usuarioftp"
archivoControl="/ControlProcesoWAV/archivo_control.txt"
logFile="/tmp/LogControlProcessWAV.log"
host_name=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')
# separar destinatarios por comas
destinatarios="paulo.martinez@inconcertcc.com"
mensaje="Subject: Fallo Proceso WAV\n\nEl proceso de subida de audios en WAV al SFTP posee alta acumulacion de archivos.\n\nHost: $host_name\nIP: $ip_address"
LogEnabled=0
echo $logFile

logInfo() {
	if [ "$LogEnabled" == 1 ]; then
           echo `date +%r-%N` "INFO: $1" >> $logFile
        fi
}
logError() { 
          echo `date +%r-%N` "ERROR: $1" >> $logFile
}
main(){ 

logInfo "Comienzo de busqueda"
    	if [ -f "$archivoControl" ]; then 
           contenido=$(cat "$archivoControl")
           logInfo "Contenido $contenido"
           if [ "$contenido" == "EJECUTAR" ]; then
               logInfo "entro al if"
               num_archivos_carpeta_1=$(find "$directoryBase/FTPSpeech1/speechanalytics1/" -maxdepth 5 -type f | wc -l)
               num_archivos_carpeta_2=$(find "$directoryBase/FTPSpeech2/speechanalytics2/" -maxdepth 5 -type f | wc -l)
               num_archivos_carpeta_3=$(find "$directoryBase/FTPSpeech3/speechanalytics3/" -maxdepth 5 -type f | wc -l)
               logInfo "$directoryBase/FTPSpeech1/speechanalytics1/"
               logInfo "$num_archivos_carpeta_1"
               logInfo "$num_archivos_carpeta_2" 
               logInfo "$num_archivos_carpeta_3"
               if [ $num_archivos_carpeta_1 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_2 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_3 -gt $maxNumberOfAudios ]; then
        	  logInfo "Las carpetas tiene mas de $maxNumberOfAudios archivos"
                  echo "NO_EJECUTAR" > "$archivoControl"
                  echo -e "$mensaje" | msmtp -a office365 -t "$destinatarios" -f alarms@inconcert.global 
                  exit 0
    	       fi
                  logInfo "No se cumple la condicion de mas de $maxNumberOfAudios archivos en ninguna de las carpetas."
               else
                  logInfo "El archivo de control indica que no se debe ejecutar la accion."
               fi
               else
                  logInfo "No se encontro el archivo de control."
               fi
}
main
