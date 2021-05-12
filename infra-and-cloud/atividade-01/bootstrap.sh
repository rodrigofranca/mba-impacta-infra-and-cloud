apt-get update
apt-get install -y mysql-server-5.7
mysql < /vagrant/mysql/user.sql
mysql < /vagrant/mysql/data.sql
cat /vagrant/mysql/mysqld.cnf > /etc/mysql/mysql.conf.d/mysqld.conf
systemctl restart mysql.service