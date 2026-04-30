#!/usr/bin/env bash
#=@ Script: htb-connect-and-scan.sh
#=@ Author: sx02089
#=@ License: BSD 3-clause.
#=@   
#=@ Description
#=@   
#=@ HackTheBox connect and scan script.
#=@ This script connects to HTB with openvpn and will setup a directory named after the box.
#=@ Nmap is run as soon as the connection is established. Based on nmap's output /etc/hosts is modified.
#=@   
#=@ Parameters
#=@   
#=@ 1. REQUIRED: To connect to HTB: OpenVPN-file
#=@ 2. REQUIRED: Box name: name-of-box[.htb]
#=@ 3. REQUIRED: IP-address of the box: 10.129.x.y
#=@ 4. OPTIONAL: Number. Restart the vpn after this amount of pings sent.
#=@   
#=@ Funtionality  
#=@   
#=@ This script will try to use xfce4-terminal (if available) to run openvpn in. It assumes an ANSI-color compatible terminal.
#=@ You're not advised to do so, but if you really must, some global variables in this script can be modified
#=@ to better suit your personal preferences. MYHTBDIR being a likely candidate.
#=@   
#=@ This script will try to:
#=@ 1. connect to HTB, if not already connected, reconnect if required.
#=@ 2. When the connection is up, ping the boxs' IP address or reconnect until it does.
#=@ 3. If the box has an entry in /etc/hosts: Replace the IP address with the current one, if not add it to /etc/hosts.
#=@ 4. mkdir $MYHTBDIR/<name-of-box> if not already there.
#=@ 5. run nmap -A -v -n -vv -p- -Pn --open -oA $MYHTBDIR/<name-of-box>/full <IP address>
#=@ 6. Analyse nmap's output for hostnames and add these to the IP address in /etc/hosts.
#=@   
#=@ Examples
#=@   
#=@ 1. Connect to HTB VPN machines EU 3 and scan a box named pingpong.htb with IP address 10.129.37.253.
#=@    If there's no ping-reply within 3 $PINGAMOUNT of $PINGSLEEP, restart the vpn.
#=@    Notice the absence of .htb in the box-name, and how it is listed in /etc/hosts as a result.
#=@    In the example below, an existing connection to HTB was detected.
#=@   
#=@   $ sudo ./htb-connect-and-scan.sh ~/Downloads/machines_eu-3.ovpn pingpong 10.129.37.253 3
#=@   [+] Reusing a prior established connection to HTB
#=@   [+] Checking connection to 10.129.37.253
#=@   .
#=@   [+] Connected!
#=@   [+] Modifying /etc/hosts to match pingpong.htb to 10.129.37.253
#=@   [+] Found the following names in a certificate alternative names section: ping.htb dc1.ping.htb
#=@   [+] Found the following names in Active Directory LDAP: ping.htb
#=@   [+] 10.129.37.253 is now listed as: pingpong.htb ping.htb dc1.ping.htb
#=@   
#=@ 2. Connect to HTB VPN machines EU 3 and scan a box INCORRECTLY spelled as kobolt instead of kobold.
#=@    Not that that ever happens in real life... Of course not.
#=@    In the example below, no prior connection was found and $XTERM and $DISPLAY were available and used to run openvpn in.
#=@    Notice the wildcard detection feature and the box name CORRECTLY spelled as kobold.htb.
#=@   
#=@   $ sudo ~/htb/htb-connect-and-scan.sh ~/openvpn/machines_eu-3.ovpn kobolt 10.129.43.160
#=@   [+] Connecting to HTB VPN: MACHINES EU-3
#=@   [+] Running openvpn in xfce4-terminal...
#=@   ..
#=@   [+] Route to 10.10.14.1 established.
#=@   [+] Connected to HTB VPN: MACHINES EU-3
#=@   [+] Checking connection to 10.129.43.160
#=@   .
#=@   [+] Connected!
#=@   [+] Adding 10.129.43.160 and kobolt.htb to /etc/hosts
#=@   Starting Nmap 7.99 ( https://nmap.org ) at 2026-04-30 11:43 +0200
#=@   [..NMAP.OUTPUT.HERE..]
#=@   Nmap done: 1 IP address (1 host up) scanned in 44.03 seconds
#=@   Raw packets sent: 65582 (2.886MB) | Rcvd: 65560 (2.623MB)
#=@   [+] Found the following names in a certificate alternative names section: kobold.htb
#=@   [+] A wildcard was found in the server certificate, this is a written invitation to do some vhost-scanning
#=@   [+] Found the following names in a certificate subject: kobold.htb
#=@   [+] Found the following name in a http redirect: kobold.htb
#=@   [+] 10.129.43.160 is now listed as: kobolt.htb kobold.htb
#=@   

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

# When running X11
ZOOM="-2"	# Valid are: 0, -1, -2, -3, -4
TEXT="green"
BACK="black"
XFCE4OPTS="--hide-menubar --hide-toolbar --hide-scrollbar"

# -- No editing beyond this point

ISCONNECTED=0
ROUTE=""
RTR=""
NIC=""
OURVPN=""
export OURPID=0
HOSTS="/etc/hosts"
XTERM="xfce4-terminal"
UNKNOWN="Unknown"
VPNTYPE="$UNKNOWN"
VPNLOC="$UNKNOWN"

# Usage from marked comments

DOXMARK='#.@ '
SCRIPT="$0"

# Terminal colors

RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
EOC="\e[0m"

# -- Functions

usage() {
	grep "$DOXMARK" "$SCRIPT" | sed -e "s/$DOXMARK//" -e 's/$/\n/' | grep -v '^DOXMARK=' | grep -v '^$'
	#cat <<-___EOF___
	#Sorry. Not yet implemented.
	#___EOF___
	return 0
}

list_descendants() {
	if [ "$#" -ne 1 ]; then
		warn "Internal error. Parameter expected"
		return 1
	fi
	expr $1 + 1 &>/dev/null
	if [ "$?" -ne 0 ]; then
		warn "Internal error. Parameter not numeric"
		return 1
	fi
	local children=$(ps -o pid= --ppid "$1")
	for pid in $children
	do
		list_descendants "$pid"
	done
	echo "$children"
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

die() {
	note DIE "$@. Aborted"
	exit 1
}

warn() {
	note WARN "$@"
	return 0
}

important() {
	note IMPORTANT "$@"
	return 0
}

start_openvpn() {
	if [ "$OURPID" -ne 0 ]; then
		# Already running. No need to start again
		return 1
	fi
	if [ "x${DISPLAY}x" = "xx" -o "x$(which $XTERM 2>/dev/null)x" = "xx" ]; then
		note "DISPLAY ($DISPLAY) was not set or terminal ($XTERM) was not found. Running openvpn in background"
		openvpn "$OVPN" &>/dev/null &
		OURPID="$!"
		return 0
	fi
	note "Running openvpn in $XTERM..."
	# Get the screen resolution and calculate width and height for 5 settings.
	#read -r X Y <<<$(xrandr 2>&1 | grep "Screen $(echo $DISPLAY | sed 's/\..*$//' | rev)" | sed 's/^.*current \([0-9]*\) x \([0-9]*\),.*$/\1 \2/')
	read -r X Y <<<$(xrandr 2>&1 | grep "^Screen [0-9]: .* current .*$" | sed 's/^.*current \([0-9]*\) x \([0-9]*\),.*$/\1 \2/')
	W=$((X-1120))
	H=$((Y-480))
	case $ZOOM in
		0)
			W=$((X-1120))
			H=$((Y-480))
			;;
		-1)
			W=$((X-1010))
			H=$((Y-440))
			;;
		-2)
			W=$((X-900))
			H=$((Y-400))
			;;
		-3)
			W=$((X-750))
			H=$((Y-360))
			;;
		-4)
			W=$((X-400))
			H=$((Y-280))
			;;
		*)
			;;
	esac
	note "Detected screen resolution as: $X x $Y, using $W and $H for zoom $ZOOM"
	TITLE="---=<[ HTB ]>=--=<[ $VPNTYPE ]>=--=<[ $VPNLOC ]>=---"
	# --- DEBUG
	#echo "$XTERM $XFCE4OPTS -T \"$TITLE\" --zoom \"$ZOOM\" --color-text \"$TEXT\" --color-bg \"$BACK\" --geometry=148x30+${W}+${H} -e openvpn --user \"${USER}\" --config \"$OVPN\""
	# --- DEBUG
	$XTERM $XFCE4OPTS -T "$TITLE" --zoom "$ZOOM" --color-text "$TEXT" --color-bg "$BACK" --geometry="148x30+${W}+${H}" -e "openvpn --user \"${USER}\" --config \"$OVPN\"" &>/dev/null &
	OURPID="$!"
	return 0
}

connect() {
	read -r VPNTYPE VPNLOC <<<$(basename "$OVPN" 2>/dev/null | sed 's/^\([a-z_]*\)_\([a-z]*-[0-9a-z\-]*\)\.ovpn/\1 \2/g' | tr '[a-z]' '[A-Z]')
	if [ "x${VPNTYPE}x" != "xx" -a "x${VPNLOC}x" != "xx" ]; then
		note "Connecting to HTB VPN: ${YELLOW}${VPNTYPE}${EOC} ${YELLOW}${VPNLOC}${EOC}"
	else
		note "Connecting to HTB using $OURVPN"
	fi
	ROUTE=""
	NIC=""
	RTR=""
	RESTARTAFTER="$RESTARTAMOUNT"
	OURPID=0
	start_openvpn
	while [ "$NIC" != "$HTBNIC" -a "$RTR" != "$HTBRTR" ]
	do
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
			start_openvpn
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
		kill -KILL $(list_descendants "$OURPID") &>/dev/null 
		wait "$OURPID" &>/dev/null
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

if [ "$VPNTYPE" = "$UNKNOWN" -o "$VPNLOC" = "$UNKNOWN" ]; then
	note "Reusing a prior established connection to HTB"
else
	note "Connected to HTB VPN: ${VPNTYPE} ${VPNLOC}"
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
	sed -i "/$BOXNAME/s/^.*[0-9]*[[:space:]]\($BOXNAME.*\)$/$IP\t\1\n/" "$HOSTS"
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
		#     gobuster vhost -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-20000.txt --domain "${BOXNAME}" -u https://"${IP}" -k --ad 
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


