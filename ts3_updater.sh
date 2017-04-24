#!/bin/bash

TS_USER=""
TS_GROUP=""

TS_MASTER_PATH="/home/$TS_USER"

####################

CURRENT_VERSION="1.3"
TS_DNS_PATH=""$TS_MASTER_PATH"/tsdns"
TMP_PATH="/tmp/teamspeak_old"
BACKUP_FILES=("licensekey.dat" "serverkey.dat" "ts3server.sqlitedb" "query_ip_blacklist.txt" "query_ip_whitelist.txt" "ts3db_mariadb.ini" "ts3db_mysql.ini" "ts3server.ini" "tsdns_settings.ini" "ts3server_startscript.sh" "tsdns_startscript.sh" ".bash_history" ".bash_logout" ".bashrc" ".profile")
BACKUP_DIR=("backup" "Backup" "backups" "logs" "files" ".ssh" ".config")
MACHINE=`uname -m`

VERSION_CHECK() {
	yellowMessage "Checking for the latest updater Script"
	LATEST_VERSION=`wget -q --timeout=60 -O - https://api.github.com/repos/Lacrimosa99/Easy-WI-Teamspeak-Updater/releases/latest | grep -Po '(?<="tag_name": ")([0-9]\.[0-9])'`

	if [ ! "$LATEST_VERSION" = "" ]; then
		if [ "`printf "${LATEST_VERSION}\n${CURRENT_VERSION}" | sort -V | tail -n 1`" != "$CURRENT_VERSION" ]; then
			echo
			redMessage "You are using the old ts3 updater script version ${CURRENT_VERSION}."
			redMessage "Please upgrade to version ${LATEST_VERSION} and retry."
			FINISHED
		else
			greenMessage "You are using the up to date version ${CURRENT_VERSION}"
			sleep 3
			USER_CHECK
		fi
	else
		redMessage "Could not detect last version!"
		FINISHED
	fi
}

USER_CHECK() {
	echo
	if [ ! "$TS_USER" = "" ]; then
		USER_CHECK=$(cut -d: -f6,7 /etc/passwd | grep "$TS_USER" | head -n1)
		if ([ ! "$USER_CHECK" == "/home/$TS_USER:/bin/bash" -a ! "$USER_CHECK" == "/home/$TS_USER/:/bin/bash" ]); then
			redMessage "User $TS_USER not found or wrong shell rights!"
			redMessage "Please check the TS_USER inside this Script or the user shell rights."
			FINISHED
		else
			SERVER_STOP
		fi
	else
		redMessage 'Variable "TS_USER" are empty!'
		FINISHED
	fi
}

SERVER_START_MINIMAL() {
	yellowMessage "Start TS3 Server with minimal script to update database..."
	yellowMessage "Please do not cancel!"
	echo

	if [ -f "$TS_MASTER_PATH"/ts3server.ini ]; then
		su "$TS_USER" -c "ln -s "$TS_MASTER_PATH"/redist/libmariadb.so.2 "$TS_MASTER_PATH"/libmariadb.so.2"
		su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_minimal_runscript.sh inifile=ts3server.ini 2>&1 | tee "$TS_MASTER_PATH"/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" &
	else
		su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_minimal_runscript.sh 2>&1 | tee "$TS_MASTER_PATH"/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" &
	fi
	PID=$!

	sleep 90
	kill -15 $PID 2>&1 >/dev/null
	sleep 10
	echo
	SERVER_START
}

SERVER_START() {
	yellowMessage "Start TS3 Server..."

	if [ -f "$TS_MASTER_PATH"/ts3server.pid ]; then
		su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_startscript.sh restart" 2>&1 >/dev/null
	else
		su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_startscript.sh start" 2>&1 >/dev/null
		sleep 2
		if [ -f "$TS_DNS_PATH"/tsdns_startscript.sh ]; then
			su "$TS_USER" -c ""$TS_DNS_PATH"/tsdns_startscript.sh start" 2>&1 >/dev/null
		fi
	fi

	sleep 2
	greenMessage "Done"
}

SERVER_STOP() {
	yellowMessage "Stop Server for Update..."

	su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_startscript.sh stop" 2>&1 >/dev/null
	if [ -f "$TS_DNS_PATH"/tsdns_startscript.sh ]; then
		su "$TS_USER" -c ""$TS_DNS_PATH"/tsdns_startscript.sh stop" 2>&1 >/dev/null
	fi

	sleep 2
	greenMessage "Done"
	echo
	sleep 3
	BACKUP
}

BACKUP() {
	yellowMessage "Make Backup..."

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
	greenMessage "Done"
	echo
	sleep 3
	DOWNLOAD
}

DOWNLOAD() {
	yellowMessage "Downloading TS3 Server Files..."
	echo

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

	if [ -f /tmp/teamspeak3-server_linux_"$ARCH"-"$VERSION".tar.bz2 ]; then
		cd /tmp
		tar xfj /tmp/teamspeak3-server_linux_"$ARCH"-"$VERSION".tar.bz2

		rm -rf "$TS_MASTER_PATH"/*

		mv /tmp/teamspeak3-server_linux_"$ARCH"/* "$TS_MASTER_PATH"
		echo "$VERSION" >> "$TS_MASTER_PATH"/version
		echo
		sleep 3
		RESTORE
	else
		redMessage "Download the last TS3 Files failed!"
		FINISHED
	fi
}

RESTORE() {
	yellowMessage "Restore TS3 Server Files..."

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
	greenMessage "Done"
	echo
	sleep 3
	SERVER_START_MINIMAL
}

HEADER() {
	echo
	cyanMessage "###################################################"
	cyanMessage "####         EASY-WI - www.Easy-WI.com         ####"
	cyanMessage "####            Teamspeak 3 Updater            ####"
	cyanMessage "####                Version: $CURRENT_VERSION               ####"
	cyanMessage "####                    by                     ####"
	cyanMessage "####                Lacrimosa99                ####"
	cyanMessage "####         www.Devil-Hunter-Clan.de          ####"
	cyanMessage "####      www.Devil-Hunter-Multigaming.de      ####"
	cyanMessage "###################################################"
	echo
}

FINISHED() {
	sleep 2
	echo
	echo
	yellowMessage "Thanks for using this script and have a nice Day."
	HEADER
	echo
	exit 0
}

yellowMessage() {
	echo -e "\\033[33;1m${@}\033[0m"
}

redMessage() {
	echo -e "\\033[31;1m${@}\033[0m"
}

greenMessage() {
	echo -e "\\033[32;1m${@}\033[0m"
}

cyanMessage() {
	echo -e "\\033[36;1m${@}\033[0m"
}

RUN() {
	clear
	echo
	HEADER
	VERSION_CHECK
	FINISHED
}

RUN
