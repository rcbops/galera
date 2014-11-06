#Creating the user specified in the heat template
{{ pillar['user_via_heat']['name'] }}:
  mysql_user.present:
    - host: '{{ pillar['user_via_heat']['remotehost'] }}'
    - password: "{{ pillar['user_via_heat']['password'] }}"
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8


database_from_heat:
  mysql_database.present:
    - name: {{ pillar ['database']['name'] }}
    - connection_user: root
    - connection_pass: {{ pillar['mysql_config']['admin_password'] }}
    - connection_charset: utf8
    - require: 
      - mysql_user: {{ pillar['user_via_heat']['name'] }}


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