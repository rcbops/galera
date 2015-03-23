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

python-software-properties: 
  pkg: 
    - installed

rsync:
  pkg:
    - installed

debconf-utils:
  pkg:
    - installed

debconf:
  pkg: 
    - installed

mysql-common:
  pkg:
    - installed

libmysqlclient18:
  pkg:
    - installed

python-mysqldb:
  pkg:
    - installed

socat:
  pkg:
    - installed

netcat:
  pkg:
    - installed

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
mysql_update_maint_password:
  mysql_user.present:
    - name: debian-sys-maint
    - host: localhost
    - password: '{{ pillar['mysql_config']['maintenance_password'] }}'
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8
    - require:
      - pkg: mariadb-pkgs
      - service: ensure_running

mysql_update_maint:
  mysql_grants.present:
    - grant: all privileges
    - database: '*.*'
    - user: debian-sys-maint
    - host: localhost
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8
    - require:
      - pkg: mariadb-pkgs
      - service: ensure_running