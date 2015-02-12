haproxy:
  salt.state:
    - tgt: 'roles:haproxy'
    - tgt_type: grain
    - sls:
      - galera.haproxy-setup
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
      - galera.stop-mysql
    - requires:
      - salt: setup
db2-stop:
  salt.state:
    - tgt: '*db2*'
    - sls:
      - galera.stop-mysql
    - requires:
      - salt: bootstrap-stop
db3-stop:
  salt.state:
    - tgt: '*db3*'
    - sls:
      - galera.stop-mysql
    - requires:
      - salt: db2-stop
bootstrap-start:
  salt.state:
    - tgt: 'roles:db_bootstrap'
    - tgt_type: grain
    - sls:
      - galera.start-mysql
    - requires:
      - salt: db3-stop
non-bootstrap-start:
  salt.state:
    - tgt: 'roles:db'
    - tgt_type: grain
    - sls:
      - galera.start-mysql
    - require:
      - salt: bootstrap-start
build-db:
  salt.state:
    - tgt: 'roles:db_bootstrap'
    - tgt_type: grain
    - sls:
      - galera.build-db
    - require:
      - salt: non-bootstrap-start