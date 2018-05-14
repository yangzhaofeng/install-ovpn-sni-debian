#!/bin/bash

dir=$(pwd)
iface=eth0


if [ `dpkg -l | grep docker-ce |wc -l` -ne 1 ];then
apt-get remove docker docker-engine docker.io
apt-get update
apt-get install \
	apt-transport-https \
	ca-certificates \
	curl \
	gnupg2 \
	software-properties-common
curl -fsSL https://mirrors.ustc.edu.cn/docker-ce/linux/debian/gpg | apt-key add -
add-apt-repository \
	"deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/linux/debian \
	$(lsb_release -cs) \
	stable"
apt-get update
apt-get install -y docker-ce
mkdir /etc/docker
touch /etc/docker/daemon.json
echo '{' >> /etc/docker/daemon.json
echo '	'"registry-mirrors": ["https://docker.mirrors.ustc.edu.cn/"] >> /etc/docker/daemon.json
echo '}' >> /etc/docker/daemon.json
systemctl reload docker
fi
ipaddr=$(ip a show dev $iface | grep "inet" | grep "brd" | awk '{print $2}' | cut -c 1-)
sed -i 's/a.b.c.d/$ipaddr/g' sniproxy.conf
ip a add 192.168.142.1 dev lo
mkdir /srv/docker
mkdir /srv/docker/sniproxy
mkdir /srv/docker/sniproxy/conf
mkdir /srv/docker/sniproxy/log
cp sniproxy.conf /srv/docker/sniproxy/conf/

docker run -itd \
	--restart=always \
	--name=sniproxy \
	--net=host \
	-v /srv/docker/sniproxy/conf:/etc/sniproxy \
	-v /srv/docker/sniproxy/log:/var/log \
	gaoyifan/sniproxy

if [ `dpkg -l | grep bind9 |wc -l` -ne 1 ];then
ip a add 192.168.142.254 dev lo
git clone https://github.com/yangzhaofeng/bind-magireco.git /srv/docker/bind
cp named.conf.options /srv/docker/bind/
docker run -itd \
	--restart=always \
	--name=bind9 \
	--net=host \
	--privileged \
	-v /srv/docker/bind:/etc/bind \
	yangzhaofengsteven/bind9
fi

if [ `dpkg -l | grep easy-rsa |wc -l` -ne 1 ];then
	apt-get install -y easy-rsa
fi

if [ `dpkg -l | grep openvpn |wc -l` -ne 1 ];then
mkdir /srv/docker/openvpn/
cp -r /usr/share/easy-rsa/ /srv/docker/openvpn/
mv /srv/docker/openvpn/easy-rsa/vars /srv/docker/openvpn/easy-rsa/vars.old
cp vars /srv/docker/openvpn/easy-rsa/vars
source /srv/docker/openvpn/easy-rsa/vars
/srv/docker/openvpn/easy-rsa/clean-all
/srv/docker/openvpn/easy-rsa/build-ca
/srv/docker/openvpn/easy-rsa/build-key-server server
/srv/docker/openvpn/easy-rsa/build-dh
cp /srv/docker/openvpn/easy-rsa/keys/server.crt /srv/docker/openvpn/
cp /srv/docker/openvpn/easy-rsa/keys/server.key /srv/docker/openvpn/
cp /srv/docker/openvpn/easy-rsa/keys/ca.crt /srv/docker/openvpn/
cp /srv/docker/openvpn/easy-rsa/keys/dh2048.pem /srv/docker/openvpn/
source /srv/docker/openvpn/easy-rsa/vars
/srv/docker/openvpn/easy-rsa/build-key client1
#mv /srv/docker/openvpn/server.conf /srv/docker/openvpn/server.conf.old
cp server.conf /srv/docker/openvpn/
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p

docker run -itd \
	-v /srv/docker/openvpn/:/etc/openvpn/:ro \
	-v /var/log/openvpn:/var/log/openvpn \
	--net=host \
	--restart=always \
	--privileged \
	--name=openvpn \
	--sysctl net.ipv6.conf.all.disable_ipv6=0 \
	yangzhaofengsteven/docker-openvpn \
	/usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

touch client1.ovpn
echo 'client' >> client1.ovpn
echo 'proto udp' >> client1.ovpn
echo 'remote $ipaddr 1194' >> client1.ovpn
echo 'nobind' >> client1.ovpn
echo 'persist-key' >> client1.ovpn
echo 'persist-tun' >> client1.ovpn
echo 'dev myvpn' >> client1.ovpn
echo 'dev-type tun' >> client1.ovpn
echo '<ca>' >> client1.ovpn
cat /srv/docker/openvpn/ca.crt >> client1.ovpn
echo '</ca>' >> client1.ovpn
echo '<cert>' >> client1.ovpn
cat /srv/docker/openvpn/easy-rsa/keys/client1.crt >> client1.ovpn
echo '</cert>' >> client1.ovpn
echo '<key>' >> client1.ovpn
cat /srv/docker/openvpn/easy-rsa/keys/client1.key >> client1.ovpn
echo '</key>' >> client1.ovpn

fi
