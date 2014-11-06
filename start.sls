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