#!/bin/bash

. test-params.sh
. test-common.sh

echo "Testing master-master replication ..."

for i in $(seq 1 $servers); do
  echo -----------
  echo Adding entry to ldap-master0$i.test.pan-net.eu
  ldapmodify -h ldap-master0$i.test.pan-net.eu \
             -x \
             -D ${ldapmasterdn} \
             -w${ldapmasterpwd} << EOF
dn: uid=repl-test-$i,$ldapbdn
changetype: add
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: repl-test-$i
sn: Test
cn: Replication
EOF
  sleep 10
  echo Checking entry on other servers
  check_entry master "uid=repl-test-${i}"
  echo Removing entry from $i
  ldapmodify -h ldap-master0$i.test.pan-net.eu \
             -x \
             -D ${ldapmasterdn} \
             -w${ldapmasterpwd} << EOF
dn: uid=repl-test-$i,$ldapbdn
changetype: delete
EOF
  echo -----------
done

echo "This is the agreement status on all servers:"

for i in $(seq 1 $servers); do
  echo -e "ldap-master0$i: \\n"
  $ldapsearch -H ldap://ldap-master0$i.test.pan-net.eu:389 \
              -x \
              -D ${ldapmasterdn} \
              -w${ldapmasterpwd} \
              -b "cn=mapping tree,cn=config" \
              -s sub \
              -a always \
              -z 1000 \
              "(&(cn=rw*)(objectClass=nsDS5ReplicationAgreement))" \
              "cn" \
              "nsds5replicaLastUpdateStatus" \
              "nsDS5ReplicaId"
  count=`$ldapsearch -H ldap://ldap-master0$i.test.pan-net.eu:389 \
                     -x \
                     -D ${ldapmasterdn} \
                     -w${ldapmasterpwd} \
                     -b "cn=mapping tree,cn=config" \
                     -s sub \
                     -a always \
                     -z 1000 \
                     "(&(cn=rw*)(objectClass=nsDS5ReplicationAgreement))" \
                     "cn" \
                     "nsds5replicaLastUpdateStatus" | \
                     egrep 'nsds5replicaLastUpdateStatus: (Error \()?[01](\))? ' | \
                     wc -l`
  if [ $count -ne $(($servers-1)) ]; then
      echo -e "\\n\\nERROR: I expected $(($servers-1)) with error ![01] agreements on ldap-master0$i.test.pan-net.eu, but got $count. Please examine the output above."
      exit 1
  fi
done

echo "OK, agreements look good."
. test-exit.sh
