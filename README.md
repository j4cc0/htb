# htb-connect-and-scan.sh

Script: htb-connect-and-scan.sh   
Author: sx02089   
License: BSD 3-clause.   
  
## Description
  
HackTheBox connect and scan script.
This script connects to HTB with openvpn and will setup a directory named after the box.
Nmap is run as soon as the connection is established. Based on nmap's output /etc/hosts is modified.
  
## Parameters
  
1. REQUIRED: To connect to HTB: OpenVPN-file
2. REQUIRED: Box name: name-of-box[.htb]
3. REQUIRED: IP-address of the box: 10.129.x.y
4. OPTIONAL: Number. Restart the vpn after this amount of pings sent.
  
## Funtionality  
  
This script will try to use xfce4-terminal (if available) to run openvpn in. It assumes an ANSI-color compatible terminal.
You're not advised to do so, but if you really must, some global variables in this script can be modified
to better suit your personal preferences. MYHTBDIR being a likely candidate.
  
This script will try to:
1. connect to HTB, if not already connected, reconnect if required.   
2. When the connection is up, ping the boxs' IP address or reconnect until it does.   
3. If the box has an entry in /etc/hosts: Replace the IP address with the current one, if not add it to /etc/hosts.  
4. mkdir $MYHTBDIR/<name-of-box> if not already there.  
5. run nmap -A -v -n -vv -p- -Pn --open -oA $MYHTBDIR/<name-of-box>/full <IP address>   
6. Analyse nmap's output for hostnames and add these to the IP address in /etc/hosts.   
  
## Examples
  
1. Connect to HTB VPN machines EU 3 and scan a box named pingpong.htb with IP address 10.129.37.253.
   If there's no ping-reply within 3 $PINGAMOUNT of $PINGSLEEP, restart the vpn.
   Notice the absence of .htb in the box-name, and how it is listed in /etc/hosts as a result.
   In the example below, an existing connection to HTB was detected.
  
  $ sudo ./htb-connect-and-scan.sh ~/Downloads/machines_eu-3.ovpn pingpong 10.129.37.253 3
  [+] Reusing a prior established connection to HTB
  [+] Checking connection to 10.129.37.253
  .
  [+] Connected!
  [+] Modifying /etc/hosts to match pingpong.htb to 10.129.37.253
  [+] Found the following names in a certificate alternative names section: ping.htb dc1.ping.htb
  [+] Found the following names in Active Directory LDAP: ping.htb
  [+] 10.129.37.253 is now listed as: pingpong.htb ping.htb dc1.ping.htb
  
2. Connect to HTB VPN machines EU 3 and scan a box INCORRECTLY spelled as kobolt instead of kobold.
   Not that that ever happens in real life... Of course not.
   In the example below, no prior connection was found and $XTERM and $DISPLAY were available and used to run openvpn in.
   Notice the wildcard detection feature and the box name CORRECTLY spelled as kobold.htb.
  
  $ sudo ~/htb/htb-connect-and-scan.sh ~/openvpn/machines_eu-3.ovpn kobolt 10.129.43.160
  [+] Connecting to HTB VPN: MACHINES EU-3
  [+] Running openvpn in xfce4-terminal...
  ..
  [+] Route to 10.10.14.1 established.
  [+] Connected to HTB VPN: MACHINES EU-3
  [+] Checking connection to 10.129.43.160
  .
  [+] Connected!
  [+] Adding 10.129.43.160 and kobolt.htb to /etc/hosts
  Starting Nmap 7.99 ( https://nmap.org ) at 2026-04-30 12:13 +0200
  [..NMAP.OUTPUT.HERE..]
  Nmap done: 1 IP address (1 host up) scanned in 44.03 seconds
  Raw packets sent: 65582 (2.886MB) | Rcvd: 65560 (2.623MB)
  [+] Found the following names in a certificate alternative names section: kobold.htb
  [+] A wildcard was found in the server certificate, this is a written invitation to do some vhost-scanning
  [+] Found the following names in a certificate subject: kobold.htb
  [+] Found the following name in a http redirect: kobold.htb
  [+] 10.129.43.160 is now listed as: kobolt.htb kobold.htb
  
