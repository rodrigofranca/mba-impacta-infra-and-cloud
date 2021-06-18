apt-get update
apt-get install -y mysql-server-5.7
mysql < /tmp/mysql/user.sql
mysql < /tmp/mysql/data.sql
cat /tmp/mysql/mysqld.cnf > /etc/mysql/mysql.conf.d/mysqld.conf
systemctl restart mysql.service