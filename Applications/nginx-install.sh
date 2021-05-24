#!/bin/bash
yum clean all && yum update -y && yum makecache
yum -y install gcc gcc-c++ pcre pcre-devel zlib zlib-devel openssl 
yum -y install openssl-devel

ng_tgz=`find / -name "nginx-1.18.0.tar.gz"`

install_dir=`basename ${ng_tgz} .tar.gz`

if [ ! -d /data/software ];then
	mkdir -p /data/software
fi

if [ ! -d /data/temp ];then
	mkdir -p /data/temp
fi

tar -xf ${ng_tgz} -C /data/temp/

cd /data/temp/${install_dir}

./configure --prefix=/usr/local/nginx  \
--conf-path=/usr/local/nginx/conf/nginx.conf  \
--user=nginx --group=nginx  \
--error-log-path=/usr/local/nginx/nginxlog/error.log  \
--http-log-path=/usr/local/nginx/nginxlog/access.log  \
--pid-path=/usr/local/nginx/pids/nginx.pid  \
--lock-path=/usr/local/nginx/locks/nginx.lock  \
--with-http_ssl_module  \
--with-http_stub_status_module  \
--with-http_gzip_static_module  \
--http-client-body-temp-path=/usr/local/nginx/tmp/client  \
--http-proxy-temp-path=/usr/local/nginx/tmp/proxy  \
--http-fastcgi-temp-path=/usr/local/nginx/tmp/fastcgi  \
--http-uwsgi-temp-path=/usr/local/nginx/tmp/uwsgi  \
--http-scgi-temp-path=/usr/local/nginx/tmp/scgi
make && make install

ln -sv /data/software/nginx/sbin/nginx /usr/bin/nginx