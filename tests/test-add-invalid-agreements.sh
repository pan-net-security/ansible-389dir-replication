#!/bin/bash

. test-params.sh
. test-common.sh

for i in $(seq 1 $servers); do
echo -----------
echo Adding invalid agreement to ldap-master0$i.test.pan-net.eu
dummyname=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-10} | head -n 1`
ldapmodify -h ldap-master0$i.test.pan-net.eu -x -D ${ldapdn} -w${ldappwd} << EOF
dn: cn=ro-to-${dummyname},cn=replica,cn="${ldapbdn}",cn=mapping tree,cn=config
changetype: add
objectclass: top
objectclass: nsds5replicationagreement
cn: ro-to-${dummyname}
nsds5replicahost: ${dummyname}
nsds5replicaport: 389
nsds5ReplicaBindDN: cn=replication manager
nsds5replicabindmethod: SIMPLE
nsds5replicaroot: ${ldapbdn}
description: example invalid agreement
nsds5replicaupdateschedule: 0000-0500 1
nsds5replicatedattributelist: (objectclass=*) $ EXCLUDE authorityRevocationList
nsds5replicacredentials: {DES}UXRbhvozeN9LWdueOEbPeQ==
EOF
done
