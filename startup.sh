#!/bin/bash
set -eou pipefail


chown root:kvm /dev/kvm
service libvirtd start
service virtlogd start
[ -z "$CPU" ] && export CPU=4
[ -z "$RAM" ] && export RAM=4096
VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up
iptables-save > $HOME/firewall.txt
rsyslogd
IP=$(vagrant ssh-config | grep HostName | awk '{ print $2 }')
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -A FORWARD -i eth0 -o virbr1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i virbr1 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -i eth0 -o virbr1 -p tcp --syn --dport 3389 -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 3389 -j DNAT --to-destination $IP
iptables -t nat -A POSTROUTING -o virbr1 -p tcp --dport 3389 -d $IP -j SNAT --to-source 192.168.121.1

#iptables -A FORWARD -i eth0 -o virbr1 -p tcp --syn --dport 5900 -m conntrack --ctstate NEW -j ACCEPT
#iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 5900 -j DNAT --to-destination $IP
#iptables -t nat -A POSTROUTING -o virbr1 -p tcp --dport 5900 -d $IP -j SNAT --to-source 192.168.121.1

#iptables -A FORWARD -i eth0 -o virbr1 -p tcp --syn --dport 5901 -m conntrack --ctstate NEW -j ACCEPT
#iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 5901 -j DNAT --to-destination $IP
#iptables -t nat -A POSTROUTING -o virbr1 -p tcp --dport 5901 -d $IP -j SNAT --to-source 192.168.121.1

iptables -A FORWARD -i eth0 -o virbr1 -p tcp --syn --dport 22 -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 22 -j DNAT --to-destination $IP
iptables -t nat -A POSTROUTING -o virbr1 -p tcp --dport 22 -d $IP -j SNAT --to-source 192.168.121.1

iptables -D FORWARD -o virbr1 -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -i virbr1 -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -o virbr0 -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -i virbr0 -j REJECT --reject-with icmp-port-unreachable

exec "$@"