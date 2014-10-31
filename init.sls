{% set admin_password = pillar['mysql_config']['admin_password'] %}

{% set haproxy_ip = salt['mine.get']('roles:haproxy', 'network.ip_addrs', 'grain').values()[0][0] %}

# Add MariaDB-Galera Repo
mariadb-repo:
  pkgrepo.managed:
    - comments:
      - '# MariaDB 10.0 Ubuntu repository list - managed by salt {{ grains['saltversion'] }}'
      - '# http://mirror.jmu.edu/pub/mariadb/repo/10.0/ubuntu'
    - name: deb http://ftp.utexas.edu/mariadb/repo/10.0/ubuntu precise main
    - dist: precise
    - file: {{ pillar['mdb_repo']['file'] }} 
    - keyserver: {{ pillar['mdb_repo']['keyserver'] }}
    - keyid: '{{ pillar['mdb_repo']['keyid'] }}'
    - require_in:
      - pkg: mariadb-pkgs


#Favor the MariaDB repo over the Ubuntu one. 
/etc/apt/preferences.d/MariaDB.pref:
  file.managed:
    - source: salt://galera/config/MariaDB.pref
    - group: root
    - mode: 644
    - template: jinja

# We have to make sure that mysql-common and libmysqlclient18 are taken from the 
# mariaDB repo and not the percona repo
apt_update_maria_repo:
  cmd.run:
    - name: apt-get update
    - require: 
      - pkgrepo: mariadb-repo
      - file: /etc/apt/preferences.d/MariaDB.pref

mysql-common:
  pkg:
    - installed

libmysqlclient18:
  pkg:
    - installed

python-mysqldb:
  pkg.installed

percona-repo:
  pkgrepo.managed:
  - name: deb http://repo.percona.com/apt precise  main
  - dist: precise
  - file: {{ pillar['percona_repo']['file'] }}
  - keyserver: {{ pillar['percona_repo']['keyserver'] }}
  - keyid: '{{ pillar['percona_repo']['keyid'] }}'
  - require_in:
    - pkg: xtrabackup-pkgs

apt_update: 
  cmd.run: 
    - name: apt-get update
    - require: 
      - pkgrepo: mariadb-repo 
      - pkgrepo: percona-repo

#Install xtrabackup packages
xtrabackup-pkgs:
  pkg.installed:
    - names:
      - percona-toolkit
      - percona-xtrabackup
    - require: 
      - pkgrepo: percona-repo
      - cmd: apt_update

#Pre-seed MariaDB install prompts
mariadb-debconf: 
  debconf.set:
    - name: mariadb-galera-server
    - data:
        'mysql-server/root_password': {'type':'string','value':{{ admin_password }}}
        'mysql-server/root_password_again': {'type':'string','value':{{ admin_password }}}
    - require:
      - pkg: debconf-utils
      - pkg: xtrabackup-pkgs
      - file: /etc/apt/preferences.d/MariaDB.pref


mariadb-pkgs:
  pkg.installed:
    - names:
      - mariadb-galera-server
      - galera
    - require:
      - pkgrepo: mariadb-repo
      - debconf: mariadb-debconf
      - cmd: apt_update

{% for cfgfile, info in pillar['mdb_cfg_files'].iteritems() %}
{{ info['path'] }}:
  file.managed:
    - source: {{ info['source'] }}
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: mariadb-pkgs
{% endfor %}

ensure_running:
  service: 
    - name: mysql
    - running
    - require: 
      - pkg: mariadb-pkgs


#Currently, Ubuntu and Debian's MariaDB servers use a special maintenance user to do routine maintenance. 
#Some tasks that fall outside of the maintenance category also are run as this user, including important 
#functions like stopping MySQL.
mysql_update_maint:
  cmd.run:
    - name: mysql -u root -p{{ admin_password }} -e "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '{{ pillar['mysql_config']['maintenance_password'] }}';"
    - require:
      - pkg: mariadb-pkgs
      - service: ensure_running

mysql_update_haproxy:
  cmd.run:
    - name: mysql -u root -p{{ admin_password }} mysql -e "INSERT INTO user (Host,User) values ('{{ haproxy_ip }}','haproxy');" || echo true
    - require:
      - pkg: mariadb-pkgs
      - service: ensure_running

#Creating the user specified in the heat template
{{ pillar['user_via_heat']['name'] }}:
  mysql_user.present:
    - host: '{{ pillar['user_via_heat']['remotehost'] }}'
    - password: "{{ pillar['user_via_heat']['password'] }}"
    - connection_user: root
    - connection_pass: {{ admin_password }}
    - connection_charset: utf8
    - require:
      - pkg: python-mysqldb
      - service: ensure_running

database_from_heat:
  mysql_database.present:
    - name: {{ pillar ['database']['name'] }}
    - connection_user: root
    - connection_pass: {{ admin_password }}
    - connection_charset: utf8
    - require: 
      - mysql_user: {{ pillar['user_via_heat']['name'] }}
      - service: ensure_running

user_grants:
  mysql_grants.present:
    - grant: all privileges
    - database: '{{ pillar['database']['name'] }}.*'
    - user: {{ pillar['user_via_heat']['name'] }}
    - host: '{{ pillar['user_via_heat']['remotehost'] }}'
    - connection_user: root
    - connection_pass: {{ admin_password }}
    - connection_charset: utf8
    - require:
      - mysql_user: {{ pillar['user_via_heat']['name'] }}
      - mysql_database: database_from_heat
      - service: ensure_running


## Move this to common salt state file? 
python-software-properties: 
  pkg: 
    - installed

## Move this to common salt state file? 
rsync:
  pkg:
    - installed

debconf-utils:
  pkg:
    - installed

debconf:
  pkg: 
    - installed

mysql_stop: 
  service: 
    - name: mysql 
    - dead

{% if grains['roles'][0] == 'db_bootstrap' %}
start_wsrep:
  cmd.run:
    - name: "service mysql start --wsrep-new-cluster"
    - require: 
      - pkg: mariadb-pkgs
      - service: mysql_stop
      - cmd: mysql_update_maint

{% endif %} 


{% if grains['roles'][0] != 'db_bootstrap' %} 
mysql:
  service.running:
    - reload: True
    - watch:
      {% for cfgfile, info in pillar['mdb_cfg_files'].iteritems() %}
      - file: {{ info['path'] }}
      {% endfor %}
    - require:
      - cmd: mysql_update_maint
      - pkg: rsync
      - pkg: mariadb-pkgs
{% endif %}
