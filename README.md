TO DO




###Pillar
```yaml
interfaces:
	private: eth0
	public: eth0
mine_functions:
	network.ip_addrs: [eth0]
	network.interfaces: []
mine_interval: 1
mdb_cfg_files:
	ubuntu_cluster:
		path: /etc/mysql/conf.d/cluster.cnf
		source: salt://galera/config/cluster.cnf
	ubuntu_maintenance:
		path: /etc/mysql/debian.cnf
		source: salt://galera/config/debian.cnf
mdb_config:
	provider: /usr/lib/galera/libgalera_smm.so
mdb_repo:
	baseurl: http://mirror.jmu.edu/pub/mariadb/repo/10.0/ubuntu
	keyserver: hkp://keyserver.ubuntu.com:80
	keyid: '0xcbcb082a1bb943db'
	file: /etc/apt/sources.list
percona_repo:
	keyserver: keys.gnupg.net
	keyid: '1C4CBDCDCD2EFD2A'
	file: /etc/apt/sources.list
user_via_heat:
	name: $user
	password: $password
	remotehost: "$remotehost"
database:
	name: $database
mysql_config:
	dbuser: root
	port: 3306
	socket: /var/lib/mysql/mysql.sock
	datadir: /var/lib/mysql/db_data
	maintenance_password: $pw
	admin_password: $admin_password
```



###Orchestration Runner
```yaml
 haproxy:
	salt.state:
		- tgt: 'roles:haproxy'
		- tgt_type: grain
		- sls:
			- galera.haproxy
			- galera.mysql
setup:
	salt.state:
		- tgt: '*db*'
		- sls:
			- galera
bootstrap-stop:
	salt.state:
		- tgt: 'roles:db_bootstrap'
		- tgt_type: grain
		- sls:
			- galera.stop
		- requires:
			- salt: setup
db2-stop:
	salt.state:
		- tgt: '*db2*'
		- sls:
			- galera.stop
		- requires:
			- salt: bootstrap-stop
db3-stop:
	salt.state:
		- tgt: '*db3*'
		- sls:
			- galera.stop
		- requires:
			- salt: db2-stop
bootstrap-start:
	salt.state:
		- tgt: 'roles:db_bootstrap'
		- tgt_type: grain
		- sls:
			- galera.start
		- requires:
			- salt: db3-stop
non-bootstrap-start:
	salt.state:
		- tgt: 'roles:db'
		- tgt_type: grain
		- sls:
			- galera.start
		- require:
			- salt: bootstrap-start
build-db:
	salt.state:
		- tgt: 'roles:db_bootstrap'
		- tgt_type: grain
		- sls:
			- galera.db
		- require:
			- salt: non-bootstrap-start

```