#!/bin/bash
mkdir /opt/install /opt/software
cd /opt/software || exit

if [ ! -f "nginx-1.18.0.tar.gz" ]; then
    wget -P /opt/software https://nginx.org/download/nginx-1.18.0.tar.gz
fi

ng_tgz=$(find /opt/software -name "nginx-1.18.0.tar.gz")
install_dir=$(basename "${ng_tgz}" .tar.gz)

echo "安装Nginx依赖包"
yum install -y gcc gcc-c++ autoconf automake zlib zlib-devel \
    openssl openssl-devel pcre pcre-devel make automake &>/dev/null

echo "创建Nginx运行用户"
groupadd nginx
useradd -g nginx nginx -s /sbin/nologin
tar -xf "${ng_tgz}" -C /opt/install/
cd /opt/install/"${install_dir}" || exit
./configure \
    --prefix=/usr/local/nginx \
    --with-http_dav_module \
    --with-http_stub_status_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-pcre \
    --with-http_ssl_module \
    --with-http_gzip_static_module \
    --user=nginx \
    --group=nginx \
    --http-client-body-temp-path=/usr/local/nginx/tmp/client \
    --http-proxy-temp-path=/usr/local/nginx/tmp/proxy \
    --http-fastcgi-temp-path=/usr/local/nginx/tmp/fastcgi \
    --http-uwsgi-temp-path=/usr/local/nginx/tmp/uwsgi \
    --http-scgi-temp-path=/usr/local/nginx/tmp/scgi \
    --error-log-path=/usr/local/nginx/nginxlog/error.log \
    --http-log-path=/usr/local/nginx/nginxlog/access.log \
    --pid-path=/usr/local/nginx/pids/nginx.pid \
    --lock-path=/usr/local/nginx/locks/nginx.lock &>/dev/null

if [ $? -eq 0 ]; then
    echo "Nginx预编译完成，开始安装"
else
    echo "Nginx预编译失败，请检查相关依赖包是否安装"
    exit 4
fi
mkdir mkdir -p /usr/local/nginx/tmp/client
make &>/dev/null
make install &>/dev/null
if [ $? -eq 0 ]; then
    echo "Nginx安装成功"
else
    echo "Nginx安装失败"
    exit 5
fi
ln -s /usr/local/nginx/sbin/nginx /usr/sbin/nginx
netstat -anput | grep nginx &>/dev/null
if [ $? -eq 0 ]; then
    echo "Nginx启动成功"
else
    echo "Nginx启动失败"
    exit 6
fi

cat >/usr/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=nginx
After=network.target
[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl status nginx
systemctl enable nginx
