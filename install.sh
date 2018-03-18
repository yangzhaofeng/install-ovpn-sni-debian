#!/bin/sh


interface=eth0


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
        "deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/debian \
        $(lsb_release -cs) \
        stable"
apt-get update
apt-get install docker-ce
mkdir /etc/docker
touch /etc/docker/daemon.json
echo '{' >> /etc/docker/daemon.json
echo '    '"registry-mirrors": ["https://docker.mirrors.ustc.edu.cn/"] >> /etc/docker/daemon.json
echo '}' >> /etc/docker/daemon.json
systemctl reload docker
fi
ipaddr=$(ip a show dev $interface | grep "inet" | grep  "brd" | awk '{print $2}' | cut -c 1-)
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
apt-get install bind9
ip a add 192.168.142.254 dev lo
mv /etc/bind/named.conf.options /etc/bind/named.conf.options.old
mv /etc/bind/named.conf.local /etc/bind/named.conf.local.old
cp named.conf.options named.conf.local db.rpz /etc/bind/
echo '*.magi-reco.com           A       192.168.142.1' >> /etc/bind/db.rpz
systemctl start bind9.service
fi

if [ `dpkg -l | grep openvpn |wc -l` -ne 1 ];then
apt-get install openvpn easy-rsa
mkdir /etc/openvpn/easy-rsa/
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
mv /etc/openvpn/easy-rsa/vars /etc/openvpn/easy-rsa/vars.old
cp vars /etc/openvpn/easy-rsa/vars
source /etc/openvpn/easy-rsa/vars
/etc/openvpn/easy-rsa/clean-all
/etc/openvpn/easy-rsa/build-ca
/etc/openvpn/easy-rsa/build-key-server server
/etc/openvpn/easy-rsa/build-dh
cp /etc/openvpn/easy-rsa/keys/server.crt /etc/openvpn/
cp /etc/openvpn/easy-rsa/keys/server.key /etc/openvpn/
cp /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/
cp /etc/openvpn/easy-rsa/keys/dh2048.pem /etc/openvpn/
source /etc/openvpn/easy-rsa/vars
/etc/openvpn/easy-rsa/build-key client1
mv /etc/openvpn/server.conf /etc/openvpn/server.conf.old
cp server.conf /etc/openvpn/
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p
systemctl start openvpn@server.service
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
cat /etc/openvpn/ca.crt >> client1.ovpn
echo '</ca>' >> client1.ovpn
echo '<cert>' >> client1.ovpn
cat /etc/openvpn/easy-rsa/keys/client1.crt >> client1.ovpn
echo '</cert>' >> client1.ovpn
echo '<key>' >> client1.ovpn
cat /etc/openvpn/easy-rsa/keys/client1.key >> client1.ovpn
echo '</key>' >> client1.ovpn

fi
