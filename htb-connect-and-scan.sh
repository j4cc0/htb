#!/usr/bin/env bash
# Script: htb-connect-and-scan.sh
# Author: Jacco van Buuren
# License: BSD 3-clause.

# Description: HackTheBox connect script.
#   This scripts connect to HTB with openvpn and will setup a directory named after the box.
#   Nmap is run as soon as the connection is established.

# Parameters:
# 1. To connect to HTB: OpenVPN-file
# 2. Box name: String.htb
# 3. IP-address of the box: 10.129.x.y
# 4. OPTIONAL: Number. Restart the vpn after this amount of pings sent.

# This script will try to:
# 1. connect to HTB, if not already connected, reconnect if required.
# 2. When the connection is up, ping box IP-addr or reconnect until it does.
# 3. If the box has an entry in /etc/hosts: Replace IP-addr with current, if not add IP-addr and name to /etc/hosts
# 4. mkdir /htb/<name-of-box> if not already there
# 5. run nmap -A -v -n -vv -p- -Pn --open /htb/<name>/full.nmap IP-addr
# 6. run whatever

# -- Globals, constants

MYHTBDIR="/htb"

OVPN="${1:-$HOME/openvpn/hackthebox.ovpn}"
BOXNAME="${2}"
IP="${3}"
PINGAMOUNT="${4:-10}"

HTBRTR="10.10.14.1"
HTBNIC="tun0"
VPNSLEEP=1
KILLSLEEP=2
PINGSLEEP=1
RESTARTAMOUNT=10

# -- No editing beyond this point

ISCONNECTED=0
ROUTE=""
RTR=""
NIC=""
OURVPN=""
OURPID=0
HOSTS="/etc/hosts"

# Colors

RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
EOC="\e[0m"

# -- Functions

usage() {
	cat <<-___EOF___
	Sorry. Not yet implemented.
	___EOF___
	return 0
}

die() {
	#echo -e "[${RED}x${EOC}] $@. Aborted" >&2
	note DIE "$@. Aborted"
	exit 1
}

warn() {
	#echo -e "[${YELLOW}!${EOC}] $@" >&2
	note WARN "$@"
	return 0
}

important() {
	note IMPORTANT "$@"
	return 0
}

note() {
	case "$1" in
		"IMPORTANT")
			shift
			MARK="[${GREEN}+${EOC}]"
			MSG="${RED}$@${EOC}"
			ERR="NO"
			;;
		"WARN")
			shift
			MARK="[${YELLOW}+${EOC}]"
			MSG="$@"
			ERR="YES"
			;;
		"DIE")
			shift
			MARK="[${RED}x${EOC}]"
			MSG="$@"
			ERR="YES"
			;;
		*)
			MARK="[${GREEN}+${EOC}]"
			MSG="$@"
			ERR="NO"
			;;
	esac
	if [ "$ERR" = "YES" ]; then
		echo -e "$MARK $MSG" >&2
	elif [ "$ERR" = "NO" ]; then
		echo -e "$MARK $MSG"
	fi
	return 0
}

connect() {
	basename "$OVPN" 2>/dev/null | sed 's/^\([a-z_]*\)_\([a-z]*-[0-9a-z\-]*\)\.ovpn/\1 \2/g' | tr '[a-z]' '[A-Z]' | while read name vpn
	do
		if [ "x${name}x" != "xx" -a "x${vpn}x" != "xx" ]; then
			note "Connecting to HTB VPN: ${YELLOW}$name${EOC} ${YELLOW}$vpn${EOC}"
		else
			note "Connecting to HTB using $OVPN"
		fi
	done
	ROUTE=""
	NIC=""
	RTR=""
	RESTARTAFTER="$RESTARTAMOUNT"
	OURPID=0
	while [ "$NIC" != "$HTBNIC" -a "$RTR" != "$HTBRTR" ]
	do
		if [ "$OURPID" -eq 0 ]; then
			openvpn "$OVPN" &>/dev/null &
			OURPID="$!"
		fi
		sleep "$VPNSLEEP"
		ROUTE=$(ip route get "$IP" | awk '{print $3 " " $5}' | grep '^[0-9]' | head -n 1)
		RTR=$(echo "$ROUTE" | awk '{print $1}')
		NIC=$(echo "$ROUTE" | awk '{print $2}')
		RESTARTAFTER=$((RESTARTAFTER - 1))
		if [ "$RESTARTAFTER" -le 0 ]; then
			echo ""
			warn "Failed to get a route to $HTBRTR"
			disconnect
			RESTARTAFTER="$RESTARTAMOUNT"
		fi
		printf "."
	done
	echo ""
	note "Route to $HTBRTR established."
	return 0
}

disconnect() {
	note "Shutting down openvpn ..."
	if [ "$OURPID" -ne 0 ]; then
		kill -KILL "$OURPID" &>/dev/null 
		wait "$OURPID" &>/dev/null
	else
		RUNNINGVPN=$(basename "$(ps ax | grep 'openvp[n]' | awk '$5 == "openvpn" { print $NF }' | head -n 1)" 2>/dev/null)
		RUNNINGVPNPID=$(ps ax | grep 'openvp[n]' | awk '$5 == "openvpn" { print $1 }' | head -n 1)
		if [ "x${RUNNINGVPN}x" = "x${OURVPN}x" ]; then
			kill -KILL "$RUNNINGVPNPID" &>/dev/null
			wait "$RUNNINGVPNPID" &>/dev/null
		else
			tty -s &>/dev/null
			if [ "$?" -eq 0 ]; then
				warn "Couldn't find our openvpn instance."
				important "Killing all instances OR HIT CTRL-C RIGHT NOW"
				read -t 3
			else
				warn "Couldn't find our openvpn instance. Killing all instances"
			fi
			pkill -KILL openvpn &>/dev/null
			wait &>/dev/null
		fi
	fi
	OURPID=0
	sleep "$KILLSLEEP"
}

reconnect() {
	disconnect
	connect
	return 0
}

# -- Parameter parsing

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	usage
	exit 0
fi

# -- Sanity checking

if [ $# -lt 3 ]; then
	die "Missing a parameter. Use -h or --help for help"
fi

if [ ! -r "$OVPN" ]; then
	die "$OVPN is not readable. Does it exist"
fi

# Make double sure there's a boxname ending in .htb and a plainname (without that).

PLAINNAME=$(echo "$BOXNAME" | tr '[A-Z]' '[a-z]' | sed 's/\.htb.*$//')
BOXNAME="${PLAINNAME}.htb"

# -- Main

# Connect to HTB

OURVPN=$(basename "$OVPN")
RUNNINGVPN=$(basename "$(ps ax | grep 'openvp[n]' | awk '$5 == "openvpn" { print $NF }' | head -n 1)" 2>/dev/null)
if [ "x${RUNNINGVPN}x" = "xx" ]; then
	# Not connected. Connect first
	connect
elif [ "x${RUNNINGVPN}x" != "x${OURVPN}x" ]; then
	# Connected but to the wrong vpn. Reconnect
	reconnect
fi

note "Checking connection to $IP"
while [ "$ISCONNECTED" -eq 0 ]; do
	PINGCOUNT="$PINGAMOUNT"
	while [ "$ISCONNECTED" -eq 0 -a "$PINGCOUNT" -gt 1 ]; do
		ping -q -c 1 -w 3 -W 3 "$IP" &>/dev/null && \
			ISCONNECTED=1
		printf "."
		PINGCOUNT=$((PINGCOUNT - 1))
		sleep "$PINGSLEEP"
	done
	# If no ping was answered, restart openvpn.
	if [ "$ISCONNECTED" -eq 0 ]; then
		echo ""
		warn "Box did not respond. Restarting openvpn."
		reconnect
		ISCONNECTED=0
	fi
done
echo ""
note "Connected!"

# Add or modify host entry in /etc/hosts

grep -w "$BOXNAME" "$HOSTS" &>/dev/null
if [ "$?" -eq 0 ]; then
	# The box is already in /etc/hosts: Modify the entry to match the current IP-address
	note "Modifying $HOSTS to match $BOXNAME to $IP"
	#grep "$BOXNAME" /etc/hosts # --- DEBUG ---
	sed -i "/$BOXNAME/s/^.*[0-9]*[[:space:]]\($BOXNAME.*\)$/$IP\t\1\n/" "$HOSTS"
	#grep "$BOXNAME" /etc/hosts # --- DEBUG ---
else
	# The box is not in /etc/hosts: Add the IP-address and boxname to /etc/hosts
	note "Adding $IP and $BOXNAME to $HOSTS"
	printf "%s\t%s\n" "$IP" "$BOXNAME" >> /etc/hosts
fi

# Create directory and start nmap

HTBDIR="$MYHTBDIR/$PLAINNAME"
mkdir -p "$HTBDIR" &>/dev/null

touch "$HTBDIR/$IP" || \
	die "Failed to write in $HTBDIR"

NMAPFILE="$HTBDIR/full.nmap"
if [ ! -s "$NMAPFILE" ]; then
	# Nmap file does not exist or is 0 bytes.
	nmap -A -p- -n -vv -oA "$HTBDIR/full" "$IP"
fi

# Correct /etc/hosts if the name of the box didn't match from the nmap scan, but keep the (incorrect) BOXNAME in there, so this script can be re-run and things will remain consistent.

# Filter out unique names related to BOXNAME
THESEHOSTS=$(grep "$BOXNAME" "$HOSTS" | sed 's/^.*[0-9][[:space:]]//;s/ /\n/g' | sort -ru | xargs echo)

# Method 1:
NEWNAMES1=$(grep -i 'DNS:' "$NMAPFILE" | sed 's/,/\n/g;s/\*\.//g;s/DNS:/\n/g' | grep -v : | grep htb | sort -ru | xargs echo)
if [ "x${NEWNAMES1}x" != "xx" ]; then
	note "Found the following names in a certificate alternative names section: $NEWNAMES1"
	HASWILDCARD=$(grep -i 'DNS:' "$NMAPFILE" | sed 's/,/\n/g;s/DNS:/\n/g' | grep -v : | grep htb | sort -ru | grep '\*')
	if [ "x${HASWILDCARD}x" != "xx" ]; then
		important "A wildcard was found in the server certificate, this is a written invitation to do some vhost-scanning"
		# Perhaps try something like:
		#     gobuster vhost -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-20000.txt --domain kobold.htb -u https://10.129.41.223 -k --ad 
	fi
fi

# Method 2:
NEWNAMES2=$(grep Domain: "$NMAPFILE" | sed 's/^.*Domain: \(.*\), .*$/\1/' | sort -ru | xargs echo)
if [ "x${NEWNAMES2}x" != "xx" ]; then
	note "Found the following names in Active Directory LDAP: $NEWNAMES2"
fi

# Method 3:
NEWNAMES3=$(grep -i 'Subject: commonName=' "$NMAPFILE" | sed 's/^.*commonName=\(.*\)$/\1/' | sort -ru | xargs echo)
if [ "x${NEWNAMES3}x" != "xx" ]; then
	note "Found the following names in a certificate subject: $NEWNAMES3"
fi

# Method 4:
NEWNAMES4=$(grep 'follow redirect' "$NMAPFILE" | sed 's@^.*://\(.*.htb\).*$@\1@' | sort -ru | xargs echo)
if [ "x${NEWNAMES4}x" != "xx" ]; then
	note "Found the following name in a http redirect: $NEWNAMES4"
fi

# Method 5:
NEWNAMES5=$(grep "DNS_Computer_Name:" "$NMAPFILE" | awk '{print $NF}')
if [ "x${NEWNAMES5}x" != "xx" ]; then
	note "Found the following name in rdp-ntlm-info: $NEWNAMES5"
fi

ALLNAMES=$(echo "$NEWNAMES1 $NEWNAMES2 $NEWNAMES3 $NEWNAMES4 $NEWNAMES5 $THESEHOSTS" | sed 's/ /\n/g' | sort -ru | xargs echo)
sed -i "/$BOXNAME/s/^.*[0-9]*[[:space:]]$BOXNAME.*$/$IP\t$ALLNAMES\n/" "$HOSTS"
note "${YELLOW}$IP${EOC} is now listed as: ${YELLOW}$ALLNAMES${EOC}"


