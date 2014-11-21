# A salt formula for creating a MariaDB 10.0/ Galera cluster

This formula will: 
* Set up haproxy for load balancing multiple MariaDB servers
* Set up a cluster of 3 MariaDB nodes with Galera wsrep




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

#How to use:
This formula uses the orchestration runner above to orchestrate the deployment of the MariaDB/Galera cluster load balanced using haproxy. 

Before running the orchestration runner, make sure the pillar above is in the /srv/pillar directory and the orchestration runner in the /srv/salt/orchestration directory. Also, assign minions their respective roles. 

####Assigning roles: 
Choose a minion to be the haproxy minion and assign it the haproxy role by setting it's grain: 
```shell
salt <node> grains.setval roles ['haproxy']
```
Choose a minion that will act as the clusters bootstrap node and assigne it the "db_bootstrap" role: 
```shell
salt <node> grains.setval roles ['db_bootstrap']
```
Assign the "db" role to the remaining nodes that will be a part of the cluster: 
```shell
salt <node> grains.setval roles ['db'] 
```

Note: Ensure the ID of the database nodes contain the string "db". This is because of the way the orchestration runner targets the nodes. 

#### Run orchestration: 
Finally, run the orchestration runner.
```shell
salt-run state.sls orchestration.galera_cluster
```