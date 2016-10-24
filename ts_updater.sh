#!/bin/bash

TS_USER=""
TS_GROUP=""

TS_VERSION="x64"

TS_MASTER_PATH="/home/"$TS_USER"/"
TS_DNS_PATH=""$TS_MASTER_PATH"/tsdns"

TMP_PATH="/tmp/teamspeak_update"

####################

BACKUP_FILES=("licensekey.dat" "query_ip_blacklist.txt" "query_ip_whitelist.txt" "serverkey.dat" "ts3db_mariadb.ini" "ts3db_mysql.ini" "ts3server.ini" "ts3server.sqlitedb" "ts3server_startscript.sh" "tsdns_settings.ini")

TS_VERSION_CHECK() {

}

USER_CHECK() {
	echo
	if [ ! "$TS_USER" = "" ]; then
		USER_CHECK=$(cut -d: -f6,7 /etc/passwd | grep "$TS_USER")
		if [ ! "$USER_CHECK" == "/home/$TS_USER:/bin/bash" ] && [ ! "$USER_CHECK" == "/home/$TS_USER/:/bin/bash" ]; then
			redMessage "User $TS_USER not found or wrong shell rights!"
			redMessage "Please check the TS_USER inside this Script or the user shell rights."
			exit 0
		fi
	else
		echo 'Variable "TS_USER" are empty!'
		exit 0
	fi
}

SERVER_START_MINIMAL() {
	su "$TS_USER" -c "./ts3server_minimal_runscript.sh"
}

SERVER_START() {
	su "$TS_USER" -c "./ts3server_startscript.sh start"
	su "$TS_USER" -c "./tsdns/tsdns_startscript.sh start"
}

SERVER_STOP() {
	su "$TS_USER" -c "./ts3server_startscript.sh stop"
	su "$TS_USER" -c "./tsdns/tsdns_startscript.sh stop""
}

BACKUP() {
	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TS_MASTER_PATH"/"$tmp_file" ]; then
			cp "$TS_MASTER_PATH"/"$tmp_file" "$TMP_PATH"
		elif [ -f "$TS_DNS_PATH"/"$tmp_file" ]; then
			cp "$TS_DNS_PATH"/"$tmp_file" "$TMP_PATH"/tsdns
		else
			echo "File not found."
		fi
	done

	if [ -d "$TS_MASTER_PATH"/backup ]; then
		cp "$TS_MASTER_PATH"/backup "$TMP_PATH"
	fi

	if [ -d "$TS_MASTER_PATH"/Backup ]; then
		cp "$TS_MASTER_PATH"/Backup "$TMP_PATH"
	fi
}

DOWNLOAD() {

}

RESTORE() {
	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TMP_PATH"/"$tmp_file" ]; then
			rm -rf "$TS_MASTER_PATH"/"$tmp_file"
			cp "$TMP_PATH"/"$tmp_file" "$TS_MASTER_PATH"
		elif [ -f "$TMP_PATH"/tsdns/"$tmp_file" ]; then
			rm -rf "$TS_DNS_PATH"/"$tmp_file"
			cp "$TMP_PATH"/tsdns/"$tmp_file" "$TS_DNS_PATH"
		else
			echo "File not found."
		fi
	done

	if [ -d "$TMP_PATH"/backup ]; then
		cp "$TMP_PATH"/backup "$TS_MASTER_PATH"
	fi

	if [ -d "$TMP_PATH"/Backup ]; then
		cp "$TMP_PATH"/Backup "$TS_MASTER_PATH"
	fi
}

RUN() {
	USER_CHECK
	TS_VERSION_CHECK
	SERVER_STOP
	BACKUP
	DOWNLOAD
	RESTORE
	SERVER_START_MINIMAL
	sleep 15
#	SERVER_START
	exit 0
}

RUN
