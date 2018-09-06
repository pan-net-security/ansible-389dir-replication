# ansible-389dir-replication

This is a role that sets up replication for [389dir (aka Fedora directory server)](http://directory.fedoraproject.org).

There is some kind of support for multi-master and some support for master-slave scenarios (see below).

## Requirements

Ansible 2.3+, required for `ldap_attr` and `ldap_entry` modules.

`python-ldap` pip package required for those modules to work (see official Ansible docs)

For setting up TLS replication don't use Ubuntu 16.04 on server nodes (https://lists.fedoraproject.org/archives/list/389-users@lists.fedoraproject.org/thread/662AR4TV4ASSKUWJVYMRXMVND3NNX65N/).

## Understanding replication

Best place to start:

* https://access.redhat.com/documentation/en-us/red_hat_directory_server/10/html/deployment_guide/designing_the_replication_process#Introduction_to_Replication-Replication_Concepts

Terms used in this role:

* master - "supplier"
* slave - "consumer"
* ro - "master->slave" replication
* rw - "master->master" replication

## How to use this role

1) Make sure your 389-ds servers are already set up and you have dirmanager-level access to it
2) Decide whether you're setting up multi-master (rw) or master-slave (ro) replica
3) Pick the replication user name and password. The role creates that user for you, unless you explicitly specify not to do so (see [Role variables])
4) Pick the sample playbook and run it.

### Master-master replication sample playbook

Set up [full-mesh multimaster](https://access.redhat.com/documentation/en-us/red_hat_directory_server/10/html/deployment_guide/Designing_the_Replication_Process-Common_Replication_Scenarios#Multi_Master_Replication-Multi_Master_Replication_Configuration_A_Four_Suppliers) replica between all hosts in `ldap-masters` group.

```
- hosts: ldap_masters    # or localhost, depending on your group_vars setup
  become: yes
  vars:
    - ldap389_suffix: "dc=test,dc=com"               # Which area is being replicated
    - ldap389_master_authdn: "cn=root"               # User, which is able to create entries in this area
    - ldap389_master_authdn_password: "rootmaster"   # It's password, plaintext
    - ldap389_replica_type: "rw"                     # master-master fullmesh
    - ldap389_masters: "{{ groups['ldap-master'] }}" # list of servers belonging to fullmesh group
    - ldap389_replication_user: "mmreptest"          # replication user - used by 389 to authenticate against peers. This user is created by this role unless you set `ldap389_create_replication_user` to `false`
    - ldap389_replication_password: "test"           # replication user password
    - ldap389_disable_ansible_log: false             # if you set this to true (default), sensitive information will NOT be present in Ansible outputs
  roles:
    - ansible-389dir-replication
```

### Master-slave replication

Set up full-mesh master-slave replica between all hosts in `ldap-masters` and `ldap-slaves` lists.

Sample:

```
 +---------------------rw-------------------+
 | +-------------------wr-----------------+ |
 | |  +------rw------+   +-----rw-----+   | |
 | |  | +----wr----+ |   |+----wr----+|   | |
 | v  | v          | v   |v          |v   | v
+--------+        +--------+        +--------+
+        + --rw-> +        + --rw-> +        +
+ Ldap01 + <-wr-- + Ldap02 + <-wr-- + Ldap03 +  <--- MASTERS, all to all, all to slaves
+        +        +        +        +        +
++++++++++        +--------+        +--------+
 |  |   |      +----+  |  |           |   | |
 |  |   |      |       |  |           |   | |
 |  +---+------+----+  |  |           |   | |
 |  +---+------+-ro-+--+--+-----------+   | |
 |  |   +------+----+--+--+---ro---------+| |
 r  |          |    |  |  |              || r
 o  |  +----ro-+    |  |  +------ro---+  || o
 |  |  |            |  |              |  || |
 |  |  |            |  |  +-----------+--++ |
 v  v  v            v  v  v           v  v  v
+--------+        +--------+        +--------+
+        + --rw-> +        + --rw-> +        +
+ Ldap04 + <-wr-- + Ldap05 + <-wr-- + Ldap06 +  <--- SLAVES, ro from every MASTER
+        +        +        +        +        +
++++++++++        +--------+        +--------+
```

Requires multi-master (previous paragraph) to be already set up! Role itself ASSUMES (== does not do the check) that master-master replication between `ldap_masters` is perfectly working.

In case you need both replications to be set up, create rw replica in one play and ro replica in the other.

```
- hosts: ldap_masters    # or localhost, depending on your group_vars setup
  become: yes
  vars:
    - ldap389_suffix: "dc=test,dc=com"                 # which area is being replicated
    - ldap389_master_authdn: "cn=root"                 # DN for connecting to master hosts
    - ldap389_master_authdn_password: "rootmaster"     # passwd for connecting to master hosts
    - ldap389_slave_authdn: "cn=root"                  # DN for connecting to slave hosts
    - ldap389_slave_authdn_password: "rootslave"       # passwd for connecting to slave hosts
    - ldap389_replica_type: "ro"                       # master-slave replication
    - ldap389_masters: "{{ groups['ldap-master'] }}"   # list of master hosts
    - ldap389_slaves: "{{ groups['ldap-slave'] }}"     # list of slave hosts
    - ldap389_replication_user: "msreptest"            # replication user - used by 389 to authenticate against peers. This user is created by this role unless you set `ldap389_create_replication_user` to `false`
    - ldap389_replication_password: "test"             # replication user password
    - ldap389_disable_ansible_log: false               # if you set this to true (default), sensitive information will NOT be present in Ansible outputs
  roles:
    - ansible-389dir-replication
```

All tasks are delegated to localhost, and thus expect the deployer instance being able to connect to remote ldap hosts.

You need to supply (the same) authdn users/passwords for master servers and the same for slave servers, in case you're setting up a ro replication.

## Role variables

### Mandatory (no defaults)

* `ldap389_replica_type`: `'ro'` or `'rw'`
* `ldap389_replication_user`: username for replication DN. The same password will be used for every host participating replication agreements.
* `ldap389_replication_password`: password for `ldap389_replication_user`
* `ldap389_master_authdn`: dn for connecting to LDAP master servers
* `ldap389_master_authdn_password`: password for `ldap389_authdn`
* `ldap389_slave_authdn`: dn for connecting to LDAP slave servers
* `ldap389_slave_authdn_password`: password for `ldap389_slave_authdn`
* `ldap389_masters`: list of ldap master hosts. Required in both (rw|ro) cases.
* `ldap389_slaves`: list of ldap slave hosts. Required for `'ro'` `ldap389_replica_type` only.
* `ldap389_suffix`: suffix for which replica is going to be set up.

### Optional
* `ldap389_replication_tls`: setup replication agreements over TLS.
* `ldap389_replication_port`: defaults to 389 for non-tls and 636 for tls agreements.
* `ldap389_replica_bind_method`: whether to use cert auth or password. Defaults to and only tested with `SIMPLE`.
* `ldap389_changelogdir`: directory where ldap changelog will be stored. Defaults to some value that is fine for both Fedora and Ubuntu.
* `ldap389_disable_ansible_log`: There is a `ldapsearch` shell command used for fetching invalid replication agreements, that reveals your authdn password unless you leave the default `True`. It's safe to kkeep the default value unless you're debugging some deep problem.
* `ldap389_conn_schema`: either `ldap://` or `ldaps://`. This scheme is used for connections to remote servers.
* `ldap389_create_replication_user`: In case you set up this user elsewhere, change default `true` to `false`.

## License

GPL

## Author Information

* Michal Medvecky <michal@medvecky.net>
* Attila Szlovak <aszlovak@motivum.sk>
* Deutsche Telekom Pan-Net s.r.o.

## Notes
-----

No sausages have been harmed during the development of this Ansible role.
