#!/bin/bash

TS_USER=""
TS_GROUP=""

TS_MASTER_PATH="/home/$TS_USER"

####################

TS_DNS_PATH=""$TS_MASTER_PATH"/tsdns"
TMP_PATH="/tmp/teamspeak_old"
BACKUP_FILES=("licensekey.dat" "query_ip_blacklist.txt" "query_ip_whitelist.txt" "serverkey.dat" "ts3db_mariadb.ini" "ts3db_mysql.ini" "ts3server.ini" "ts3server.sqlitedb" "ts3server_startscript.sh" "tsdns_settings.ini" "tsdns_startscript.sh")
BACKUP_DIR=("backup" "Backup" "logs" "files" ".ssh" ".config")
MACHINE=`uname -m`

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
	echo "Start TS3 Server with minimal script to update database..."
	echo "Please do not cancel!"

	su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_minimal_runscript.sh > "$TS_MASTER_PATH"/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" &
	PID=$!

	sleep 90
	kill -15 $PID 2>&1 >/dev/null
	sleep 10
	echo
}

SERVER_START() {
	echo "Start TS3 Server..."

	su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_startscript.sh start" 2>&1 >/dev/null
	sleep 2
	if [ -f "$TS_DNS_PATH"/tsdns_startscript.sh ]; then
		su "$TS_USER" -c ""$TS_DNS_PATH"/tsdns_startscript.sh start" 2>&1 >/dev/null
	fi

	sleep 2
	echo "Done"
	echo
}

SERVER_STOP() {
	echo "Stop Server for Update..."

	su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_startscript.sh stop" 2>&1 >/dev/null
	if [ -f "$TS_DNS_PATH"/tsdns_startscript.sh ]; then
		su "$TS_USER" -c ""$TS_DNS_PATH"/tsdns_startscript.sh stop" 2>&1 >/dev/null
	fi

	sleep 2
	echo "Done"
	echo
	sleep 3
}

BACKUP() {
	echo "Make Backup..."

	if [ ! -d "$TMP_PATH" ]; then
		mkdir "$TMP_PATH"
	else
		rm -rf "$TMP_PATH"
		mkdir "$TMP_PATH"
	fi

	for tmp_dir in ${BACKUP_DIR[@]}; do
		if [ -d "$TS_MASTER_PATH"/"$tmp_dir" ]; then
			cp "$TS_MASTER_PATH"/"$tmp_dir" -R "$TMP_PATH" 2>&1 >/dev/null
		fi
	done

	if [ ! -d "$TMP_PATH"/tsdns ]; then
		mkdir "$TMP_PATH"/tsdns
	fi

	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TS_MASTER_PATH"/"$tmp_file" ]; then
			cp "$TS_MASTER_PATH"/"$tmp_file" -R "$TMP_PATH"/ 2>&1 >/dev/null
		elif [ -f "$TS_DNS_PATH"/"$tmp_file" ]; then
			cp "$TS_DNS_PATH"/"$tmp_file" -R "$TMP_PATH"/tsdns/ 2>&1 >/dev/null
		fi
	done

	sleep 2
	echo "Done"
	echo
	sleep 3
}

DOWNLOAD() {
	echo "Downloading TS3 Server Files..."

	if [ "$MACHINE" == "x86_64" ]; then
		ARCH="amd64"
	elif [ "$MACHINE" == "i386" ] || [ "$MACHINE" == "i686" ]; then
		ARCH="x86"
	else
		echo "$MACHINE is not supported!"
	fi

	VERSION="$(curl -s http://teamspeak.com/downloads#server | grep teamspeak3-server_linux_$ARCH | head -n1 | grep -o [0-9].[0-9].[0-9][0-9].[0-9] | head -n1)"
	DOWNLOAD_URL="http://dl.4players.de/ts/releases/$VERSION/teamspeak3-server_linux_$ARCH-$VERSION.tar.bz2"

	wget --timeout=60 -P /tmp/ "$DOWNLOAD_URL"
	cd /tmp
	tar xfj /tmp/teamspeak3-server_linux_"$ARCH"-"$VERSION".tar.bz2

	rm -rf "$TS_MASTER_PATH"/*

	mv /tmp/teamspeak3-server_linux_"$ARCH"/* "$TS_MASTER_PATH"
	echo "$VERSION" >> "$TS_MASTER_PATH"/version
	echo
	sleep 3
}

RESTORE() {
	echo "Restore TS3 Server Files..."

	for tmp_dir in ${BACKUP_DIR[@]}; do
		if [ -d "$TMP_PATH"/"$tmp_dir" ]; then
			cp "$TMP_PATH"/"$tmp_dir" -R "$TS_MASTER_PATH"/
		fi
	done

	if [ ! -d "$TS_MASTER_PATH"/logs ]; then
		mkdir "$TS_MASTER_PATH"/logs
	fi

	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TMP_PATH"/"$tmp_file" ]; then
			rm -rf "$TS_MASTER_PATH"/"$tmp_file"
			mv "$TMP_PATH"/"$tmp_file" "$TS_MASTER_PATH"/
		elif [ -f "$TMP_PATH"/tsdns/"$tmp_file" ]; then
			rm -rf "$TS_DNS_PATH"/"$tmp_file"
			mv "$TMP_PATH"/tsdns/"$tmp_file" "$TS_DNS_PATH"/
		fi
	done

	chown -cR "$TS_USER":"$TS_GROUP" "$TS_MASTER_PATH" 2>&1 >/dev/null

	rm -rf /tmp/teamspeak3-server_linux_"$ARCH"-"$VERSION".tar.bz2
	rm -rf /tmp/teamspeak3-server_linux_"$ARCH"
	rm -rf "$TMP_PATH"

	sleep 2
	echo "Done"
	echo
	sleep 3
}

RUN() {
	USER_CHECK
	SERVER_STOP
	BACKUP
	DOWNLOAD
	RESTORE
	SERVER_START_MINIMAL
	SERVER_START
}

RUN
