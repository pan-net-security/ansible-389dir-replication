# ldap-389-tests

The purpose of those tests is to test master-master and master-slave replication feature with the 389 installed.

What it does:

- launch 4 master and 4 slave docker containers
- setup 389 using 389dir role
- setup master-master replication between 4 master hosts
- on each master host, write something, then read it from all masters
- setup master-slave replication: on every master server, setup master-slave replication 
- add one invalid agreement to every master server -> this is for testing if they vanish after next run
- on each master host, write something, then read it from all slaves
- stop all containers

## Prerequisities

* Runner with dind (docker in docker), privilege to run new containers and create Docker networks
* `ldap-utils` (ldapsearch, ldapmodify) on runner container
* Privileged mode for Docker is required - we launch containers with systemd (so we can have environment "similar" to the real one)

## Known issues

* There is a `sleep 4` (arbitrary value) statement after every LDAP write, because LDAP replication needs time for propagation. We've seen situations where all agreements were OK, sleep was performed, but the change did not propagate. On next run (without code change), everything went fine.
* This testing pipeline is pretty complex and hard to simulate locally. It's possible to add `sleep` statement to `gitlab-ci.yml` and then `docker exec -it <container> bash` on the right runner (line 8 of pipeline output, like `Running on runner-3aba11dd-project-455-concurrent-0 via runner-3aba11dd-autoscale-1507706271-513a5e51...`). Of course you need to have ssh keys and access permission to the runner environment.

