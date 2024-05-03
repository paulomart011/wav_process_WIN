# PROCESO MIXEO EN WAV EN PBX Y SUBIDA DE AUDIOS A SFTP
Speech Analytics habitualmente toma los audios Mixeados en WAV del repositorio de audios alojado en el MW, sin embargo dado que wav ocupa gran cantidad de espacio (se llego a observar en algunos clientes de más de 2TB en 3 meses), se decide configurar un proceso que lleve este Mixeo en WAV a un repositorio dedicado SFTP, para esto los pasos a configurar son los siguientes:

1. Se debe configurar en un servidor un FTP, este servirá como paso intermedio entre las PBXs y el SFTP final.
2. Se debe implementar el proceso de carga de archivos del FTP al SFTP.
3. En cada PBX se configura el mixeo y la subida al FTP alojado en el servidor intermedio Linux del punto 1.
4. Se debe configurar alarmas en el servidor intermedio Linux y en las PBXs por si ocurre una acumulación excesiva de archivos.
5. En el MW o un servidor Windows, se deberá configurar un proceso diario (nocturno) que revise en el SFTP externo los audios del dia generados, los guarde en una tabla SQL y genere un csv en este repositorio.

Cada uno de estos puntos estan colocados en sus respectivas carpetas:

1. Configuración FTP en Servidor Intermedio Linux (1. Servidor Linux FTP)
2. Configuración subida a SFTP en Servidor Intermedio Linux (2. Servidor Linux SFTP)
3. Configurar en PBX para carga a FTP (3. Servidor PBX)
4. Alarmas en PBX y servidor intermedio Linux (4. Alarmas)
5. Listado en BD y CSV (5. Listado en BD y CSV)


## 0. Repositorios:

1. En el caso del SFTP final, Infra entrega este repositorio segun solicitud, entregara dominio y credenciales y por default ellos realizan la retencion controlada de 3 meses de audios.

2. En el caso del servidor intermedio Linux, se debe solicitar a Infra, para activar el FTP en este servidor se usa la libreria vsftpd. La configuración esta en la carpeta "Configuración Servidor Intermedio Linux".

## 1. Configuración FTP en Servidor Intermedio Linux

Este servidor Linux servirá como FTP intermedio, es a donde llegan los audios de la PBX que finalmente son enviados al SFTP final.

Crear los siguientes directorio (en el caso de ejemplo se tuvieron 3 nodos):
```
mkdir home/usuarioftp
mkdir home/usuarioftp/FTPSpeech1
mkdir home/usuarioftp/FTPSpeech2
mkdir home/usuarioftp/FTPSpeech3
mkdir home/usuarioftp/FTPSpeech1/speechanalytics1
mkdir home/usuarioftp/FTPSpeech2/speechanalytics2
mkdir home/usuarioftp/FTPSpeech3/speechanalytics3
```
La librería a usar para que el servidor sirva como FTP es vsftpd, la cual se instala de la siguiente forma:

```
sudo apt-get install vsftpd
```
Luego, se debe modificar el archivo de configuración:
```
nano /etc/vsftpd.conf
```
Allí se debe referenciar a la carpeta que servirá como ruta inicial del FTP, se deberá modificar la siguiente línea del archivo vsftpd.conf:
```
local_root=/home/usuarioftp
```

Posterior a modificarlo deben inicar el servicio:
```
sudo service vsftpd start
```
Otros comandos útiles:
```
sudo service vsftpd stop
sudo service vsftpd restart
sudo service vsftpd reload
sudo service vsftpd status
```

Lo siguiente es configurar al usuario para la conectividad al FTP, se deben ejecutar los siguientes comandos:
```
useradd -g ftp -d /home/usuarioftp usuarioftp
chown usuarioftp.ftp /home/usuarioftp -R
chmod -w /home/usuarioftp
passwd usuarioftp
```
En la última línea se define la contraseña que tendra el usuario.
Podemos probar la conexión con el siguiente comando:

```
ftp ip_del_server
```
Si la conexión es exitosa, ya estaria listo el FTP en el servidor intermedio.

## 2. Configuración subida a SFTP en Servidor Intermedio Linux

La librería a usar para enviar archivos al SFTP final es lftp, la cual se instala de la siguiente forma:

```
sudo apt install lftp
```

Copiar el archivo UploadFilesToSFTP.sh a la ruta /usr/sbin/ y se deberá modificar con las credenciales a usar del SFTP final:
```
ftpuser="win-user"
ftppassword="pwd"
recordingremotehost="usftpcorp.inconcertcc.com"
```
Luego nos aseguramos el formato unix y damos permisos al archivo copiado:
```
dos2unix /usr/sbin/UploadFilesToSFTP.sh
chown -R root:root /usr/sbin/UploadFilesToSFTP.sh
chmod +x /usr/sbin/UploadFilesToSFTP.sh
```

Luego programamos en crontab el script sh (en el ejemplo se tienen 3 nodos, se deberá adecuar en base a lo que se requiere):

```
nano /etc/crontab
```
```
# WAV Files to SFTP
* * * * * root /usr/sbin/UploadFilesToSFTP.sh 1;
* * * * * root /usr/sbin/UploadFilesToSFTP.sh 2;
* * * * * root /usr/sbin/UploadFilesToSFTP.sh 3;
```
En la ruta principal del SFTP debe existir la siguiente carpeta:
```
speechanalytics
```
Con esto, ya se puede validar dejando una archivo en la ruta del FTP y ver si lo transfiere adecuadamente al SFTP final.

## 3. Configurar en PBXs para carga a FTP

Generalmente se monta el procedimiento sobre PBX que tengan el mixeo en mp3, se requiere configurar el mixeo en wav (separado del mixeo nativo) para subirlo al repositorio FTP del linux intermedio. Se debe validar que el ambiente este configurado para generar audios en mp3 (revisando el archivo tkpostrecording.sh y inconcert.conf), en caso este aplicado la configuracion en wav debera aplicarse rollback a esa configuracion en una ventana. Rollback a las configuraciones indicadas en la guia: [https://inconcert.atlassian.net/wiki/spaces/i6Docs/pages/1126301763/C+mo+setear+el+formato+de+grabaci+n+de+audios+a+.wav]

### a. Setup previo

Copiar los archivos de la carpeta "4. Servidor PBX" en alguna carpeta de la PBX, a fines de la guia se llamara "inicioGrab", ubicado en /home/brt001spt

### b. Crear los directorios que se usaran en el proceso
 
```
mkdir /GrabacionesWAV
mkdir /GrabacionesWAV/q1
mkdir /GrabacionesWAV/q2
mkdir /GrabacionesWAV/q3
mkdir /GrabacionesWAV/q4
mkdir /GrabacionesWAV/q5
mkdir /GrabacionesWAV/qp

mkdir /GrabacionesWAVFailed
mkdir /GrabacionesWAVFailed/q1
mkdir /GrabacionesWAVFailed/q2
mkdir /GrabacionesWAVFailed/q3
mkdir /GrabacionesWAVFailed/q4
mkdir /GrabacionesWAVFailed/q5
mkdir /GrabacionesWAVFailed/qp
```

### c. Copiar los scripts a la ruta /usr/sbin:

Editar en los archivos UploadFilesToFTP.sh y UploadFailedToFTP.sh las credenciales a usar y el número de random number en base a los nodos con los que se trabajará (en este ejemplo son 3 nodos):
```
ftpuser="usuarioftp"
ftppassword="pwd"
recordingremotehost="10.151.67.113"
randomNumber=$(( (RANDOM % 3) + 1 ))
```

Luego mover estos archivos a la siguiente ruta:
- **FTP:**

    ```
    cp /home/brt001spt/inicioGrab/UploadFilesToFTP.sh /usr/sbin/
    cp /home/brt001spt/inicioGrab/UploadFailedToFTP.sh /usr/sbin/
    ```


### d. Asegurar el formato unix y dar permisos a los archivos copiados:

- **FTP:**

    ```
    dos2unix /usr/sbin/UploadFilesToFTP.sh
    dos2unix /usr/sbin/UploadFailedToFTP.sh
    chown -R root:root /usr/sbin/UploadFilesToFTP.sh
    chmod +x /usr/sbin/UploadFilesToFTP.sh
    chown -R root:root /usr/sbin/UploadFailedToFTP.sh
    chmod +x /usr/sbin/UploadFailedToFTP.sh
    ```

### e. Programar crontab, se usa los scripts sh:

```
nano /etc/crontab
```

- **FTP:**

    ```
    # WAV Files to MW
    * * * * * root /usr/sbin/UploadFilesToFTP.sh 1;
    * * * * * root /usr/sbin/UploadFilesToFTP.sh 2;
    * * * * * root /usr/sbin/UploadFilesToFTP.sh 3;
    * * * * * root /usr/sbin/UploadFilesToFTP.sh 4;
    * * * * * root /usr/sbin/UploadFilesToFTP.sh 5;

    * * * * * root /usr/sbin/UploadFailedToFTP.sh 1;
    * * * * * root /usr/sbin/UploadFailedToFTP.sh 2;
    * * * * * root /usr/sbin/UploadFailedToFTP.sh 3;
    * * * * * root /usr/sbin/UploadFailedToFTP.sh 4;

### f. Editar el archivo /usr/sbin/tkpostrecording.sh (validacion en caso se requiera)

Se recomienda en primer paso hacer un backup:

```
mkdir /home/brt001spt/backupscambiowav/
cp -p /usr/sbin/tkpostrecording.sh /home/brt001spt/backupscambiowav/tkpostrecording.sh
```

Debajo de cada generación de audio se debe agregar la siguiente línea:
```
	echo "$cmdDebian -M $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$in_file /GrabacionesWAV/$queueName/$callId.wav && " >> $recordingdir/$callId.prs	
```
Tener en cuenta que se debe agregar "&&" dentro del comando echo de cada generación de audio:
Por ejemplo, esta linea estaba así:
```
echo "$cmdDebian $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$callId.mp3" >> $recordingdir/$callId.prs
```
Y ahora deberia estar asi:
```
echo "$cmdDebian $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$callId.mp3 && " >> $recordingdir/$callId.prs
```
Una vez realizado ello, ya comenzarán a generarse audios WAV y deberían estar llegando al FTP del servidor linux. Finalmente, del servidor linux estarán siendo enviadas al SFTP final.

## 4. Alarmas en PBX y servidor intermedio Linux:
Para el proceso se configura una alarma que valida la cantidad de archivos y en caso el número sea elevado envia una notificación email.

Para ello primero se debe instalar la libreria msmtp en el servidor linux y las PBXs (no requiere ningún reinicio):
```
apt-get -y install msmtp
```

Luego en el archivo de configuración se debe colocar lo siguiente:
```
nano ~/.msmtprc
```
```
     # A system wide configuration is optional.
     # If it exists, it usually defines a default account.
     # This allows msmtp to be used like /usr/sbin/sendmail.
     defaults
     auth on
     tls on
     tls_starttls on
     tls_trust_file /etc/ssl/certs/ca-certificates.crt

     account office365
     host smtp.office365.com
     port 587
     from alarms@inconcert.global
     user alarms@inconcert.global
     password poner_password_de_la_cuenta

     account default : office365

     # Use TLS.
     #tls on
     #tls_trust_file /etc/ssl/certs/ca.pem

     # Syslog logging with facility LOG_MAIL instead of the default LOG_USER.
     syslog LOG_MAIL

```
Para validar que el envio funciona correctamente se puede ejecutar la siguiente linea:
```
echo -e "Subject: Fallo Proceso WAV\n\nEl proceso de generacion de audios en WAV se detuvo debido a una falla que causo acumulacion de archivos" | msmtp -a office365 -t "paulo.martinez@inconcertcc.com" -f alarms@inconcert.global
```
### a. Alarma para el servidor intermedio Linux:
En el servidor intermedio linux, crear carpeta:
```
mkdir ControlProcesoWAV
```
La carpeta contendrá los siguientes archivos (se pueden encontrar en la carpeta 4 en "LINUX"):
a. archivo_control.txt
b. ControlProcesoWAV.sh (se debe actualizar en base a los nodos que se tienen)

Se debe editar el archivo ControlProcesoWAV.sh en base a los nodos que se tengan, en este ejemplo se esta trabajando con 6 nodos.

Dar formato a archivo:
```
dos2unix /ControlProcesoWAV/ControlProcesoWAV.sh
chown -R root:root /ControlProcesoWAV/ControlProcesoWAV.sh
chmod +x /ControlProcesoWAV/ControlProcesoWAV.sh
```
Agregar al contrab la siguiente linea
```
* * * * * root /ControlProcesoWAV/ControlProcesoWAV.sh;
```

Con esto se estará validando cada minuto la cantidad de archivos de las 3 carpetas del FTP (en este caso se tienen 3 nodos en el ambiente).

Si el proceso se detiene por carga de archivos, se debe revisar que esta generando el encolamiento, posterior a ello se puede activar el proceso de control poniendo "EJECUTAR" como contenido del archivo de control.

### b. Alarma para las PBXs:
En cada PBX, crear la carpeta:
```
mkdir ControlProcesoWAV
```
La carpeta contendrá los siguientes archivos (se pueden encontrar en la carpeta 4 en "LINUX"):
a. archivo_control.txt
b. ControlProcesoWAV.sh
c. tkpostrecordingOn.sh (representa el tkpostrecording.sh con los cambios para la generación en WAV)
d. tkpostrecordingOff.sh (representa el tkpostrecording.sh sin cambios)

Dar formato a archivo:
```
dos2unix /ControlProcesoWAV/ControlProcesoWAV.sh
chown -R root:root /ControlProcesoWAV/ControlProcesoWAV.sh
chmod +x /ControlProcesoWAV/ControlProcesoWAV.sh
```
Agregar al contrab la siguiente linea
```
* * * * * root /ControlProcesoWAV/ControlProcesoWAV.sh;
```

Con esto se estará validando cada minuto la cantidad de archivos de las carpetas de GrabacionesWAV y GrabacionesWAVFailed de las PBXs.
Si el proceso se detiene por carga de archivos, se debe revisar que esta generando el encolamiento, posterior a ello se puede activar el proceso de control poniendo "EJECUTAR" como contenido del archivo de control.

## 5. Listado en BD y en CSV:

En un servidor Windows (en WIN se uso el MW3), crear la carpeta tmpAudios por ejemplo (modificar según el disco que se tenga):
```
C:\tmpAudios
```
Y en su interior crear un archivo vacio llamado fileDetails.csv
Finalmente, dar clic derecho en la carpeta, poner SharedWith>SpecificPeople>Everyone y dar en Aceptar. Deberá aparecer una pantalla con una ruta como esta:
```
\\MW3-FD193\tmpAudios
```
Esta es la ruta compartida que se usará desde la BD para dejar el archivo CSV.

En la tabla de negocio se deberá crear la siguiente tabla:
```
USE [WINKeywords]
GO

/****** Object:  Table [dbo].[DatosArchivosAudiosV2]    Script Date: 5/3/2024 4:40:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DatosArchivosAudiosV2](
	[path] [varchar](500) NULL,
	[file] [varchar](500) NOT NULL,
	[location] [varchar](500) NULL,
	[creationDate] [date] NULL,
 CONSTRAINT [PK_DatosArchivosAudiosV2] PRIMARY KEY CLUSTERED 
(
	[file] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
```
En la tabla de negocio se deberá crear el siguiente sp que se encargará de descargar los registros:
```
USE [WINKeywords]
GO
/****** Object:  StoredProcedure [dbo].[BulkArchivosAudios_forHour]    Script Date: 5/3/2024 4:39:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[BulkArchivosAudios_forHour]
AS
BEGIN
	BEGIN TRY
		bulk insert dbo.DatosArchivosAudiosV2
		from '\\MW3-FD193\tmpAudios\fileDetails.csv'
		with
		(
			FIRSTROW = 2 ,
			FIELDTERMINATOR = ';',
			ROWTERMINATOR = '\n', 
			MAXERRORS = 1000000000,
			CODEPAGE = 'ACP'
		)
	END TRY
	BEGIN CATCH
	END CATCH

	EXEC [sp_GenerateReportDetailInOutCallsByCampaignToSFTP] 
END
```
Finalmente el siguiente sp se encarga de enviar el archivo con la metadata adicional a la ruta correspondiente del SFTP:
```
USE [WINKeywords]
GO
/****** Object:  StoredProcedure [dbo].[sp_GenerateReportDetailInOutCallsByCampaignToSFTP]    Script Date: 5/3/2024 4:41:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- Test
-- EXEC [sp_GenerateReportDetailInOutCallsByCampaignToSFTP] 
ALTER procedure [dbo].[sp_GenerateReportDetailInOutCallsByCampaignToSFTP]
as

SET NOCOUNT ON

DROP TABLE IF EXISTS dbo.DatosToSFTPProcesados;
CREATE TABLE [dbo].[DatosToSFTPProcesados](
	[Campaign] [varchar](500) NULL,
	[StartDate] [varchar](500) NULL,
	[Initiative] [varchar](500) NULL,
	[Account] [varchar](500) NULL,
	[CallDnis] [varchar](500) NULL,
	[ContactAddress] [varchar](500) NULL,
	[ContactName] [varchar](500) NULL,
	[FirstAgent] [varchar](500) NULL,
	[LastAgent] [varchar](500) NULL,
	[WasSentToAgentSearch] [varchar](500) NULL,
	[IsTaken] [varchar](500) NULL,
	[IsAbandoned] [varchar](500) NULL,
	[IsCanceled] [varchar](500) NULL,
	[SLPositive] [varchar](500) NULL,
	[IsShort] [varchar](500) NULL,
	[IsLong] [varchar](500) NULL,
	[IsGhost] [varchar](500) NULL,
	[IsOutOfScheduler] [varchar](500) NULL,
	[PureIVR] [varchar](500) NULL,
	[Ender] [varchar](500) NULL,
	[StartAttention][varchar](500) NULL,
	[EndDate] [varchar](500) NULL,
	[DurationTime] [varchar](500) NULL,
	[WaitingTime] [varchar](500) NULL,
	[IVRTime] [varchar](500) NULL,
	[ACDTime] [varchar](500) NULL,
	[RingingTime] [varchar](500) NULL,
	[AnswerTime] [varchar](500) NULL,
	[AttentionTime] [varchar](500) NULL,
	[WrapupTime] [varchar](500) NULL,
	[PreviewTime] [varchar](500) NULL,
	[DispositionCode] [varchar](500) NULL,
	[DispositionTreePath] [varchar](500) NULL,
	[DispositionIsGoal] [varchar](500) NULL,
	[IsAppointment] [varchar](500) NULL,
	[HasAppointment] [varchar](500) NULL,
	[WasTransferredFromCampaign] [varchar](500) NULL,
	[OriginalCampaign] [varchar](500) NULL,
	[IsTransferred] [varchar](500) NULL,
	[TransferSuccessful] [varchar](500) NULL,
	[TransferDestinationType] [varchar](500) NULL,
	[TransferDestination] [varchar](500) NULL,
	[TransferTime] [varchar](500) NULL,
	[TransferExternalCalls] [varchar](500) NULL,
	[TransferExternalCallsTime] [varchar](500) NULL,
	[TransferExternalTime] [varchar](500) NULL,
	[RequeuedTime] [varchar](500) NULL,
	[HasConference] [varchar](500) NULL,
	[ConferenceDestinationType] [varchar](500) NULL,
	[ConferenceDestination] [varchar](500) NULL,
	[Holds] [varchar](500) NULL,
	[HoldTime] [varchar](500) NULL,
	[Ticket] [varchar](500) NULL,
	[VCC] [varchar](500) NULL,
	[ID] [varchar](500) NULL,
	[AccountID] [varchar](500) NULL,
	[file] [varchar](max) NULL,
	[location] [varchar](max) NULL,
	);

	DECLARE @IdTimeZone Varchar(50)
	DECLARE @VirtualCC Varchar(50)
	SET @VirtualCC = 'win'
	SET @IdTimeZone = 'PET'

	-- DEFINO ESTRUCTURA DE ARCHIVO
	DECLARE @RemoteDirectoryFilter VARCHAR(1000); ---- Directorio remoto en el servidor SFTP
    DECLARE @RemoteDirectory VARCHAR(1000);  -- Directorio para dejar el CSV
	DECLARE @RemoteFileName VARCHAR(1000) -- Nombre del archivo en el servidor SFTP
	DECLARE @HoraAnterior DATETIME;
	DECLARE @mainPath VARCHAR(1000);
	SET @mainPath = '/speechanalytics/';
	SET @HoraAnterior = DATEADD(HOUR, -1, HistoricalData.dbo.GetRealDate(@IdTimeZone, GETDATE()));
	
	SET @RemoteDirectory = @mainPath + CONVERT(VARCHAR(4), YEAR(@HoraAnterior)) + '/Metadata/';
	SET @RemoteDirectoryFilter = @mainPath + CONVERT(VARCHAR(4), YEAR(@HoraAnterior)) + '/' +
							RIGHT(CONVERT(VARCHAR(2), MONTH(@HoraAnterior)), 2) + '/' +
							RIGHT(CONVERT(VARCHAR(2), DAY(@HoraAnterior)), 2) + '/' +
							RIGHT(CONVERT(VARCHAR(2), DATEPART(HOUR, @HoraAnterior)), 2) + '/';
	SET @RemoteFileName = 'Metadata_' + CONVERT(VARCHAR(4), YEAR(@HoraAnterior)) + 
							RIGHT('00' + CONVERT(VARCHAR(2), MONTH(@HoraAnterior)), 2) + 
							RIGHT('00' + CONVERT(VARCHAR(2), DAY(@HoraAnterior)), 2) + 
							RIGHT('00' + CONVERT(VARCHAR(2), DATEPART(HOUR, @HoraAnterior)), 2) + '.csv';

	INSERT INTO DatosToSFTPProcesados 
	(
		Campaign, StartDate, Initiative, Account, CallDnis, ContactAddress, ContactName, 
		FirstAgent, LastAgent, WasSentToAgentSearch, IsTaken, IsAbandoned, IsCanceled, 
		SLPositive, IsShort, IsLong, IsGhost, IsOutOfScheduler, PureIVR, Ender, 
		StartAttention, EndDate, DurationTime, WaitingTime, IVRTime, ACDTime, 
		RingingTime, AnswerTime, AttentionTime, WrapupTime, PreviewTime, DispositionCode, 
		DispositionTreePath, DispositionIsGoal, IsAppointment, HasAppointment, WasTransferredFromCampaign, 
		OriginalCampaign, IsTransferred, TransferSuccessful, TransferDestinationType, TransferDestination, 
		TransferTime, TransferExternalCalls, TransferExternalCallsTime, TransferExternalTime, RequeuedTime, 
		HasConference, ConferenceDestinationType, ConferenceDestination, Holds, HoldTime, Ticket, 
		VCC, ID, AccountID, [file], [location]
	)
	VALUES 
	(
		'Campana', 'FechaInicio', 'Inic', 'Cuenta', 'Dnis', 'Dir', 'NombreContacto', 
		'PrimerAgte', 'UltimoAgte', 'BuscoAg', 'Aten', 'Ab', 'Canc', 
		'Sl', 'Corta', 'Larga', 'Fant', 'FueraHora', 'PureBotIvr', 'Finalizador', 
		'FechaInichoAten', 'FechaFinal', 'TpoDur', 'TpoEsp', 'TpoIvr', 'TpoAcd', 
		'TpoTimb', 'TpoResp', 'TpoAten', 'TpoConc', 'TpoPrev', 'Disp', 
		'DispAbs', 'Exito', 'EsAgenda', 'TieneAgenda', 'FueTr', 
		'CampOrig', 'Tr', 'TrOk', 'TipoTr', 'DestTr', 
		'TpoTr', 'LlamadasExternas', 'TiempoLlamadasExternas', 'TiempoExterno', 'ReqTime', 
		'Conf', 'TipoConf', 'DestConf', 'Rets', 'TpoRet', 'Tick', 
		'Vcc', 'IdConversacion', 'IdDeCuenta', 'NombreAudio', 'Ruta'
	);

	INSERT INTO DatosToSFTPProcesados
	SELECT D.Campaign,
		   CONVERT(VARCHAR(500), HistoricalData.dbo.GetRealDate(@IdTimeZone, D.StartDate), 121) AS 'StartDate',
		   CASE WHEN D.Initiative = 'INBOUND' THEN 'Ent.' when D.Initiative = 'OUTBOUND' THEN 'Sal.'  ELSE 'No' END AS Initiative,
		   D.Account,
		   D.CallDnis,
		   D.ContactAddress,
		   D.ContactName,
		   D.FirstAgent,
		   D.LastAgent,
		   CASE WHEN D.WasSentToAgentSearch = '1' THEN 'Si' ELSE 'No' END AS WasSentToAgentSearch,
		CASE WHEN D.IsTaken = '1' THEN 'Si' ELSE 'No' END AS IsTaken,
		CASE WHEN D.IsAbandoned = '1' THEN 'Si' ELSE 'No' END AS IsAbandoned,
		CASE WHEN D.IsCanceled = '1' THEN 'Si' ELSE 'No' END AS IsCanceled,
		CASE WHEN D.SLPositive = '1' THEN 'Si' ELSE 'No' END AS SLPositive,
		CASE WHEN D.IsShort = '1' THEN 'Si' ELSE 'No' END AS IsShort,
		CASE WHEN D.IsLong = '1' THEN 'Si' ELSE 'No' END AS IsLong,
		CASE WHEN D.IsGhost = '1' THEN 'Si' ELSE 'No' END AS IsGhost,
		CASE WHEN D.IsOutOfScheduler = '1' THEN 'Si' ELSE 'No' END AS IsOutOfScheduler,
		CASE WHEN D.PureIVR = '1' THEN 'Si' ELSE 'No' END AS PureIVR,
		 D.Ender,
		  CONVERT(VARCHAR(500), HistoricalData.dbo.GetRealDate(@IdTimeZone, D.StartAttention), 121) as 'StartAttention',
		   CONVERT(VARCHAR(500), HistoricalData.dbo.GetRealDate(@IdTimeZone, D.EndDate), 121) as 'EndDate',
		   FORMAT(DATEADD(SECOND,CAST(D.DurationTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'DurationTime',
		   FORMAT(DATEADD(SECOND,CAST(D.WaitingTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'WaitingTime',
		   FORMAT(DATEADD(SECOND,CAST(D.IVRTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'IVRTime',
		   FORMAT(DATEADD(SECOND,CAST(D.ACDTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'ACDTime',
		   FORMAT(DATEADD(SECOND,CAST(D.RingingTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'RingingTime',
		   FORMAT(DATEADD(SECOND,CAST(D.AnswerTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'AnswerTime',
		   FORMAT(DATEADD(SECOND,CAST(D.AttentionTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'AttentionTime',
		  FORMAT(DATEADD(SECOND,CAST(D.WrapupTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'WrapupTime',
		  FORMAT(DATEADD(SECOND,CAST(D.PreviewTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'PreviewTime',
		   D.DispositionCode,
		   D.DispositionTreePath,
		   CASE WHEN D.DispositionIsGoal = '1' THEN 'Si' ELSE 'No' END AS DispositionIsGoal,
		   CASE WHEN D.IsAppointment = '1' THEN 'Si' ELSE 'No' END AS IsAppointment,
		   CASE WHEN D.HasAppointment = '1' THEN 'Si' ELSE 'No' END AS HasAppointment,
		   CASE WHEN D.WasTransferredFromCampaign = '1' THEN 'Si' ELSE 'No' END AS WasTransferredFromCampaign,
		   D.OriginalCampaign,
		   CASE WHEN D.IsTransferred = '1' THEN 'Si' ELSE 'No' END AS IsTransferred,
		   CASE WHEN D.TransferSuccessful = '1' THEN 'Si' ELSE 'No' END AS TransferSuccessful,
		   D.TransferDestinationType,
		   D.TransferDestination,
		   FORMAT(DATEADD(SECOND,CAST(D.TransferTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'TransferTime',
		   D.TransferExternalCalls,
		   FORMAT(DATEADD(SECOND,CAST(D.TransferExternalCallsTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'TransferExternalCallsTime',
		   FORMAT(DATEADD(SECOND,CAST(D.TransferExternalTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'TransferExternalTime',
		   FORMAT(DATEADD(SECOND,CAST(D.RequeuedTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'RequeuedTime',
		   CASE WHEN D.HasConference = '1' THEN 'Si' ELSE 'No' END AS HasConference,
		   D.ConferenceDestinationType,
		   D.ConferenceDestination,
		   D.Holds,
		   FORMAT(DATEADD(SECOND,CAST(D.HoldTime AS INTEGER) , '1900-01-01'), 'HH:mm:ss') as 'HoldTime',
		   D.Ticket,
		   D.VCC,
		   D.ID,
		   D.AccountID,
		   I.[file],
		   LEFT(I.[path], LEN(I.[path]) - 1) as 'path'
	  FROM WINKeywords..DatosArchivosAudiosV2 (nolock) I
	  LEFT JOIN HistoricalDataNotifi6..Detail_Call_i6 (nolock) D  
	  ON LEFT(I.[file], CHARINDEX('_', I.[file]) - 1) = D.ID
	  WHERE I.[path] = @RemoteDirectoryFilter and D.ID is not null;

  -- GENERO EL ARCHIVO CSV EN BASE A UN SELECT
  DECLARE @SQL NVARCHAR(MAX);
  DECLARE @cmd varchar(8000);
  SET @SQL = 'SELECT * FROM WINKeywords.dbo.DatosToSFTPProcesados with (nolock)';
  SET @cmd = 'bcp "' + @SQL + '" queryout "\\MW3-FD193\tmpToSFTP\data.csv" -c -t , -T -S ' + @@SERVERNAME + ' -C 1252';
  EXEC master.dbo.xp_cmdshell @cmd

	WAITFOR DELAY '00:00:05';

    -- ENVIO EL ARCHIVO CSV A UN SFTP
    DECLARE @LocalFilePath VARCHAR(1000) = '\\MW3-FD193\tmpToSFTP\data.csv' -- Ruta del archivo local
	DECLARE @Port VARCHAR(1000) = '22' -- Puerto del SFTP
	DECLARE @sftpuser VARCHAR(1000) = 'win-user' -- Usuario del SFTP
	DECLARE @sftppassword VARCHAR(1000) = 'pwd' -- Password del SFTP
	DECLARE @sftpHOST VARCHAR(1000) = 'usftpcorp.inconcertcc.com' -- Host del SFTP
    DECLARE @Fingerprint VARCHAR(1000) = '93:c2:26:.......' -- Fingerprint del servidor SFTP
    DECLARE @SFTPCommandsFilePath VARCHAR(1000) = '\\MW3-FD193\tmpToSFTP\sftp_commands.txt' -- Definir la ruta completa para el archivo sftp_commands.txt que realiza el cargado al SFTP

	-- Genero el archivo que define las acciones sobre el SFTP
    DECLARE @CmdCreateFile VARCHAR(1000)
    SET @CmdCreateFile = 'echo put "' + @LocalFilePath + '" "' + @RemoteDirectory + @RemoteFileName + '" > ' + @SFTPCommandsFilePath
    EXEC master.dbo.xp_cmdshell @CmdCreateFile

	WAITFOR DELAY '00:00:05';

    -- Ejecutar psftp con los comandos
    DECLARE @CmdExecuteSFTP VARCHAR(1000)
    SET @CmdExecuteSFTP = 'echo y | psftp -P '+@Port+' -l '+@sftpuser+' -pw '+@sftppassword+' -batch -hostkey ' + @Fingerprint + ' '+@sftpHOST+' -b ' + @SFTPCommandsFilePath
    EXEC master.dbo.xp_cmdshell @CmdExecuteSFTP

	--- Elimino el archivo que definio las acciones sobre el SFTP
	DECLARE @CmdExecuteDeleteLocalFile VARCHAR(1000)
	SET @CmdExecuteDeleteLocalFile = 'del ' + @SFTPCommandsFilePath
    EXEC master.dbo.xp_cmdshell @CmdExecuteDeleteLocalFile

	DELETE DatosToSFTPProcesados;

SET NOCOUNT OFF

```

Lo que hará el proceso es crear un archivo con información de los audios generados en la ultima hora, esta información contiene datos de la interacción en OCC. Y esta información es enviada a la ruta correspondiente del SFTP

Luego, subir el proceso de listado de audios "Ejecutable.zip" (carpeta 5. Listado en BD y CSV), y mediante un task scheduler poner que se ejecute cada hora. Lo que hara el proceso es listar todos los archivos de la hora anterior.
En el archivo appSettings.json modificar las siguientes lineas en base a lo requerido:
```
{
  "sftpHost": "usftpcorp.inconcertcc.com",   									//dominio del SFTP
  "sftpPath": "/speechanalytics/",   	     									//ruta raíz del SFTP
  "sftpArchivoLista": "/procesados/listasAudios/", 								//ruta del SFTP donde se depositarán los archivos CSV
  "sftpFingerPrint": "......",											//fingerprint para conexion al SFTP
  "sftpUsername": "womcolombia-user",										//usuario SFTP
  "sftpPassword": "pwd",											//password SFTP
  "rutaArchivoCSV": "r:\\tmpAudios\\fileDetails.csv",								//ruta del server MW para referenciar la generación del archivo
  "spBulk": "EXEC WomVentas..BulkArchivosAudios;",								//SP de bulk de data
  "cabecera": "file;location;creationDate",									//cabecera fija (no cambia)
  "dataSource": "Data Source=172.16.227.114;Initial Catalog=WomVentas;User ID=UsrAccMw;Password=poner_pwd",	//definicion de la BD a usar
  "timeout_win": "10",												//timeout de conexion en segundos
  "diaListar": "1"												//dia atras que se listara (en 1 significa que listará los archivos del dia anterior)
}
```

Este proceso generará los registros en BD y en un CSV.
Si se requiere revisar las fuentes, se encuentran en el zip "ListarAudiosSFTP"

