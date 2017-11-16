#!/bin/bash

# Debug Mode
DEBUG="OFF"

# Teamspeak3 User
TS_USER=""

# Teamspeak3 Group
TS_GROUP=""

# Teamspeak3 Path
TS_MASTER_PATH="/home/$TS_USER"

# Backup Path
BACKUP_PATH=""

####################

CURRENT_SCRIPT_VERSION="1.4"
TMP_PATH="/tmp/teamspeak_old"
BACKUP_FILES=("licensekey.dat" "serverkey.dat" "ts3server.sqlitedb" "query_ip_blacklist.txt" "query_ip_whitelist.txt" "ts3db_mariadb.ini" "ts3db_mysql.ini" "ts3server.ini" "ts3server_startscript.sh" ".bash_history" ".bash_logout" ".bashrc" ".profile")
BACKUP_DIR=("backup" "Backup" "backups" "logs" "files" ".ssh" ".config")
MACHINE=`uname -m`

VERSION_CHECK() {
	yellowMessage "Checking for the latest Updater Script"
	LATEST_SCRIPT_VERSION=`wget -q --timeout=60 -O - https://api.github.com/repos/Lacrimosa99/Easy-WI-Teamspeak-Updater/releases/latest | grep -Po '(?<="tag_name": ")([0-9]\.[0-9])'`

	if [ "$LATEST_SCRIPT_VERSION" != "" ]; then
		if [ "`printf "${LATEST_SCRIPT_VERSION}\n${CURRENT_SCRIPT_VERSION}" | sort -V | tail -n 1`" != "$CURRENT_SCRIPT_VERSION" ]; then
			echo
			redMessage "You are using a old TS3 Updater Script Version ${CURRENT_SCRIPT_VERSION}."
			redMessage "Please Upgrade to Version ${LATEST_SCRIPT_VERSION} and retry."
			redMessage "Download Link: https://github.com/Lacrimosa99/Easy-WI-Teamspeak-Updater/releases"
			FINISHED
		else
			greenMessage "You are using a Up-to-Date Script Version ${CURRENT_SCRIPT_VERSION}"
			sleep 2
		fi
	else
		redMessage "Could not detect last Script Version!"
		FINISHED
	fi

	echo
	yellowMessage "Checking for the latest TS3 Server Version"

	if [ "$MACHINE" == "x86_64" ]; then
		ARCH="amd64"
	elif [ "$MACHINE" == "i386" ] || [ "$MACHINE" == "i686" ]; then
		ARCH="x86"
	else
		echo "$MACHINE is not supported!"
	fi

	LASTEST_TS3_VERSION=$(curl -s https://teamspeak.com/en/downloads#server | grep teamspeak3-server_linux_$ARCH | head -n1 | grep -o [0-9].[0-9].[0-9][0-9].[0-9] | head -n1)
	LOCAL_TS3_VERSION=$(if [ -f "$TS_MASTER_PATH"/version ]; then cat "$TS_MASTER_PATH"/version; fi)
	if [ "$LASTEST_TS3_VERSION" != "" ]; then
		if [ "$LOCAL_TS3_VERSION" != "$LASTEST_TS3_VERSION" ]; then
			redMessage "Your TS3 Server Version is deprecated."
			redMessage "Start Update Process"
			sleep 2
			USER_CHECK
		else
			greenMessage "Your TS3 Server Version is Up-to-Date"
			FINISHED
		fi
	else
		redMessage "Could not detect last TS3 Server Version!"
		FINISHED
	fi
}

USER_CHECK() {
	echo
	if [ "$TS_USER" != "" ]; then
		USER_CHECK=$(cut -d: -f6,7 /etc/passwd | grep "$TS_USER" | head -n1)
		if ([ "$USER_CHECK" != "/home/$TS_USER:/bin/bash" -a "$USER_CHECK" != "/home/$TS_USER/:/bin/bash" ]); then
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
	yellowMessage "starting TS3 Server with ts3server_minimal_runscript.sh to Update Database..."
	yellowMessage "Please do not cancel!"
	echo

	CHECK_MARIADB=$(if [ -f "$TS_MASTER_PATH"/ts3db_mariadb.ini ]; then cat "$TS_MASTER_PATH"/ts3db_mariadb.ini | grep "username="; fi)
	CHECK_MSQL=$(if [ -f "$TS_MASTER_PATH"/ts3db_mysql.ini ]; then cat "$TS_MASTER_PATH"/ts3db_mysql.ini | grep "username="; fi)

	if [ "$CHECK_MARIADB" != "" -o "$CHECK_MSQL" != "" ]; then
		su "$TS_USER" -c "ln -s "$TS_MASTER_PATH"/redist/libmariadb.so.2 "$TS_MASTER_PATH"/libmariadb.so.2"
		su "$TS_USER" -c "$TS_MASTER_PATH/ts3server_minimal_runscript.sh inifile=ts3server.ini 2>&1 | tee $TS_MASTER_PATH/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" &
	else
		su "$TS_USER" -c "$TS_MASTER_PATH/ts3server_minimal_runscript.sh | tee $TS_MASTER_PATH/logs/ts3server_minimal_start_$(date +%d-%m-%Y).log" &
	fi

	sleep 80
	TS3_PID=$(ps -ef | grep ts3server | grep -v grep | awk '{print $2}' | sort | tail -n1)
	kill -15 $TS3_PID
	sleep 10
	greenMessage "Done"
	sleep 20
	echo
	SERVER_START
}

SERVER_START() {
	yellowMessage "Start TS3 Server"

	su "$TS_USER" -c "$TS_MASTER_PATH/ts3server_startscript.sh start" 2>&1 >/dev/null
	sleep 2
	greenMessage "Done"
}

SERVER_STOP() {
	yellowMessage "Stop Server for Update..."

	su "$TS_USER" -c ""$TS_MASTER_PATH"/ts3server_startscript.sh stop" 2>&1 >/dev/null
	sleep 5
	if [ $(ps -ef | grep ts3server | grep -v grep | awk '{print $2}' | sort | tail -n1) != "" ]; then
		TS3_PID=$(ps -ef | grep ts3server | grep -v grep | awk '{print $2}' | sort | tail -n1)
		kill -15 $TS3_PID
	fi
	sleep 5
	greenMessage "Done"
	sleep 3
	echo
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

	for tmp_file in ${BACKUP_FILES[@]}; do
		if [ -f "$TS_MASTER_PATH"/"$tmp_file" ]; then
			cp "$TS_MASTER_PATH"/"$tmp_file" -R "$TMP_PATH"/ 2>&1 >/dev/null
		fi
	done

	if [ "$BACKUP_PATH" != "" ]; then
		cd "$TMP_PATH"
		tar cpvz ./ | split -b1024m - Teamspeak_Backup.$(date -I).tar.gz.split.
		mv Teamspeak_Backup.*.tar.gz.split.* "$BACKUP_PATH"
	fi

	sleep 2
	greenMessage "Done"
	sleep 3
	echo
	DOWNLOAD
}

DOWNLOAD() {
	yellowMessage "Downloading TS3 Server Files..."
	echo

	DOWNLOAD_URL="http://dl.4players.de/ts/releases/$LASTEST_TS3_VERSION/teamspeak3-server_linux_$ARCH-$LASTEST_TS3_VERSION.tar.bz2"
	wget --timeout=60 -P /tmp/ "$DOWNLOAD_URL"

	if [ -f /tmp/teamspeak3-server_linux_"$ARCH"-"$LASTEST_TS3_VERSION".tar.bz2 ]; then
		cd /tmp
		tar xfj /tmp/teamspeak3-server_linux_"$ARCH"-"$LASTEST_TS3_VERSION".tar.bz2

		rm -rf "$TS_MASTER_PATH"/*

		mv /tmp/teamspeak3-server_linux_"$ARCH"/* "$TS_MASTER_PATH"
		echo "$LASTEST_TS3_VERSION" >> "$TS_MASTER_PATH"/version
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
		fi
	done

	chown -cR "$TS_USER":"$TS_GROUP" "$TS_MASTER_PATH" 2>&1 >/dev/null

	rm -rf /tmp/teamspeak3-server_linux_"$ARCH"-"$LASTEST_TS3_VERSION".tar.bz2
	rm -rf /tmp/teamspeak3-server_linux_"$ARCH"
	rm -rf "$TMP_PATH"

	sleep 3
	greenMessage "Done"
	sleep 3
	echo
	SERVER_START_MINIMAL
}

HEADER() {
	echo
	cyanMessage "###################################################"
	cyanMessage "####         EASY-WI - www.Easy-WI.com         ####"
	cyanMessage "####            Teamspeak 3 Updater            ####"
	cyanMessage "####                Version: $CURRENT_SCRIPT_VERSION               ####"
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
	if [ "$DEBUG" = "ON" ]; then
		set +x
	fi
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
	if [ "$DEBUG" = "ON" ]; then
		set -x
	fi
	clear
	echo
	HEADER
	VERSION_CHECK
	FINISHED
}

RUN
