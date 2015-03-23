# This builds the users and grants specific in the pillar file
{% set haproxy_ip = salt['mine.get']('roles:haproxy', 'network.ip_addrs', 'grain').values()[0][0] %}

#Creating the user specified in the pillar file
{{ pillar['user_via_heat']['name'] }}:
  mysql_user.present:
    - host: '{{ pillar['user_via_heat']['remotehost'] }}'
    - password: "{{ pillar['user_via_heat']['password'] }}"
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8

#Creating the database specific in the pillar file
database_from_heat:
  mysql_database.present:
    - name: {{ pillar ['database']['name'] }}
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8
    - require:
      - mysql_user: {{ pillar['user_via_heat']['name'] }}

#Adding the permissions specified in the pillar file
user_grants:
  mysql_grants.present:
    - grant: all privileges
    - database: '{{ pillar['database']['name'] }}.*'
    - user: {{ pillar['user_via_heat']['name'] }}
    - host: '{{ pillar['user_via_heat']['remotehost'] }}'
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8
    - require:
      - mysql_user: {{ pillar['user_via_heat']['name'] }}
      - mysql_database: database_from_heat

haproxy:
  mysql_user.present:
    - host: {{ haproxy_ip }}
    - allow_passwordless: True
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8