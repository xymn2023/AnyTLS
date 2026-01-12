#!/bin/bash
C="/etc/sing-box/config.json";I="/root/.sb_info.json";S="sing-box";R='\033[0;31m';G='\033[0;32m';P='\033[0m'
[[ $EUID -ne 0 ]] && echo -e "${R}需要Root权限${P}" && exit 1
dep(){ rm -f /etc/sing-box/client_info.json;apt update -y;apt install -y curl jq net-tools openssl;curl -fsSL https://sing-box.app/install.sh|sh -s -- --beta;}
chk(){ [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ];}; occ(){ netstat -tuln|grep -q ":$1 ";}; ip(){ local i=$(curl -s4 ifconfig.me);[[ -z "$i" ]] && i=$(curl -s6 ifconfig.me);echo "$i";}
inst(){ dep;while :;do read -p "端口(默认1443): " p;p=${p:-1443};chk "$p"||continue;occ "$p"&&echo "${R}端口占用${P}"&&continue;break;done
read -p "密码(默认随机生成): " w;[[ -z "$w" ]]&&w=$(openssl rand -hex 16)
read -p "SNI(默认genshin.hoyoverse.com): " s;s=${s:-genshin.hoyoverse.com}
k=$(/usr/bin/sing-box generate reality-keypair);sk=$(echo "$k"|grep Private|awk '{print $2}');pk=$(echo "$k"|grep Public|awk '{print $2}');id=$(openssl rand -hex 8)
cat > $C <<EOF
{"log":{"level":"info","timestamp":true},"inbounds":[{"type":"anytls","listen":"::","listen_port":$p,"users":[{"name":"user","password":"$w"}],"padding_scheme":["stop=8","0=30-30","1=100-400","2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000","3=9-9,500-1000","4=500-1000","5=500-1000","6=500-1000","7=500-1000"],"tls":{"enabled":true,"server_name":"$s","reality":{"enabled":true,"handshake":{"server":"$s","server_port":443},"private_key":"$sk","short_id":["$id"]}}}]}
EOF
cat > $I <<EOF
{"pk":"$pk","id":"$id","sni":"$s","pwd":"$w","port":$p}
EOF
systemctl daemon-reload;systemctl enable $S;systemctl restart $S;link;}
link(){ [[ ! -f $I ]]&&echo "无配置"&&return;x=$(ip);p=$(jq -r .port $I);w=$(jq -r .pwd $I);s=$(jq -r .sni $I);k=$(jq -r .pk $I);d=$(jq -r .id $I);echo -e "\n${G}链接:${P} anytls://${w}@${x}:${p}/?sni=${s}&fp=chrome&pbk=${k}&sid=${d}#AnyReality\n";}
uninst(){ systemctl stop $S;systemctl disable $S;rm -f /etc/systemd/system/$S.service /usr/bin/$S /usr/local/bin/$S $I;rm -rf /etc/$S;systemctl daemon-reload;echo -e "${G}已完全卸载并清除数据${P}";}
menu(){ echo -e "${G}1.安装 2.管理 3.链接 4.状态 5.日志 6.卸载 0.退出${P}";read -p "选项: " o;case $o in 1) inst;;2) read -p "1.启动 2.停止 3.重启: " a;[[ $a == 1 ]]&&systemctl start $S;[[ $a == 2 ]]&&systemctl stop $S;[[ $a == 3 ]]&&systemctl restart $S;;3) link;;4) systemctl status $S;;5) journalctl -u $S -e;;6) uninst;;0) exit;;esac;}
while :;do menu;done