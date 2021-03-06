#!/bin/bash
function isRoot() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
}

function initialCheck() {
    if ! isRoot; then
        echo "请使用root用户运行脚本"
        exit 1
    fi
}

function installNginx() {
    mkdir /opt/install /opt/software &>/dev/null
    cd /opt/software || exit

    if [ ! -f "nginx-1.18.0.tar.gz" ]; then
        wget -P /opt/software https://nginx.org/download/nginx-1.18.0.tar.gz
    fi

    ng_tgz=$(find /opt/software -name "nginx-1.18.0.tar.gz")
    install_dir=$(basename "${ng_tgz}" .tar.gz)

    echo "安装Nginx依赖包"
    yum install -y wget gcc zlib-devel bzip2-devel openssl openssl-devel ncurses-devel \
        sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel \
        libffi-devel git pcre pcre-devel make automake &>/dev/null

    echo "创建Nginx运行用户"
    groupadd nginx
    useradd -g nginx -M nginx -s /sbin/nologin
    echo "解压文件"
    tar -xf "${ng_tgz}" -C /opt/install/
    echo "预编译文件"
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
    echo "已配置开机启动"
    systemctl enable nginx &>/dev/null
    systemctl start nginx
    echo "Nginx服务已经就绪"
    netstat -ntlp|grep nginx && systemctl status nginx
    
}

function removeNginx() {
    echo ""
    read -rp "Do you really want to remove Nginx? [y/n]: " -e -i n REMOVE
    if [[ $REMOVE == 'y' ]]; then

        # Stop nginx
        systemctl disable nginx
        systemctl stop nginx
        yum remove -y nginx
        # Delete user
        userdel nginx
        rm -f /var/spool/mail/nginx
        # Cleanup
        rm -rf /usr/local/nginx/
        rm -rf /opt/install/"${install_dir}"
        rm -f /usr/lib/systemd/system/nginx.service &>/dev/null
        rm -f /usr/sbin/nginx 

        echo ""
        echo "Nginx removed!"
    else
        echo ""
        echo "Removal aborted!"
    fi
}

function manageMenu() {
    echo "Welcome to nginx-install"
    echo "The git repository is available at: https://github.com/apnpc/Shell/blob/main/Applications/nginx-install.sh"
    echo ""
    echo "It looks like Nginx is already installed."
    echo ""
    echo "What do you want to do?"
    echo "   1) Remove Nginx"
    echo "   2) Exit"
    until [[ $MENU_OPTION =~ ^[1-2]$ ]]; do
        read -rp "Select an option [1-2]: " MENU_OPTION
    done

    case $MENU_OPTION in
    1)
        removeNginx
        ;;
    2)
        exit 0
        ;;
    esac
}
initialCheck
# Check if Nginx is already installed
if [ -d /usr/local/nginx/ ]; then
    manageMenu
else
    installNginx
fi
