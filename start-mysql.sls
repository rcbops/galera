{% if grains['roles'][0] == 'db_bootstrap' %}
start_wsrep:
  cmd.run:
    - name: "service mysql start --wsrep-new-cluster"
{% endif %} 


{% if grains['roles'][0] != 'db_bootstrap' %} 
mysql:
  service.running:
    - reload: True
{% endif %}