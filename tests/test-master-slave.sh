#!/bin/bash

. test-params.sh
. test-common.sh

echo "Testing master-slave replication ..."

for i in $(seq 1 $servers); do
  echo -----------
  echo Adding entry to ldap-master0$i.test.pan-net.eu
  ldapmodify -h ldap-master0$i.test.pan-net.eu -x -D ${ldapmasterdn} -w${ldapmasterpwd} << EOF
dn: uid=slave-repl-test-$i,$ldapbdn
changetype: add
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: slave-repl-test-$i
sn: Test
cn: Replication
EOF
  if [ $? -ne 0 ]; then
          fail=1
            echo "Adding entry to ldap-master0$i failed."
          fi
  sleep 10

  echo Checking entry on slave servers
  check_entry slave "uid=slave-repl-test-${i}"

  echo Removing entry from ldap-master0$i
  ldapmodify -h ldap-master0$i.test.pan-net.eu \
             -x \
             -D ${ldapmasterdn} \
             -w${ldapmasterpwd} << EOF
dn: uid=slave-repl-test-$i,$ldapbdn
changetype: delete
EOF

  if [ $? -ne 0 ]; then
      fail=1
      echo "Removing entry from ldap-master0$i failed."
  fi
  echo -----------
done

for i in $(seq 1 $servers); do
  echo -----------
  echo "Adding entry to ldap-slave0$i.test.pan-net.eu (should fail)"
  ldapmodify -h ldap-slave0$i.test.pan-net.eu \
             -x \
             -D ${ldapslavedn} \
             -w${ldapslavepwd} << EOF
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
  if [ $? -ne 10 ]; then
    echo "Writing to ldap-slave0$i should fail"
    fail=1
  fi
done

echo "Here are all ro-agreement statuses on master servers:"

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
              "(&(cn=ro*)(objectClass=nsDS5ReplicationAgreement))" \
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
                     "(&(cn=ro*)(objectClass=nsDS5ReplicationAgreement))" \
                     "cn" \
                     "nsds5replicaLastUpdateStatus" | \
                     egrep 'nsds5replicaLastUpdateStatus: (Error \()?[01](\))? ' | \
                     wc -l`
  if [ $count -ne $(($servers)) ]; then
      echo -e "\\n\\nERROR: I expected $(($servers)) RO agreements with status ![01] on ldap-master0$i.test.pan-net.eu, but got $count. Please examine the output above."
      exit 1
  fi
done

echo "OK, agreements look good"

. test-exit.sh
