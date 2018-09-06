function check_entry {

if [ "$1" == "master" ]; then
  dn=$ldapmasterdn
  pwd=$ldapmasterpwd
else
  dn=$ldapslavedn
  pwd=$ldapslavepwd
fi

for s in $(seq 1 $servers); do
  echo -n "Checking $2 on ldap-${1}0${s} ... "
  res[$s]=`$ldapsearch  -H ldap://ldap-${1}0${s}.test.pan-net.eu:389 -x -D $dn -w$pwd -b "$ldapbdn" "($2)" | grep uid: | wc -l`
  echo -n "${res[$s]} results "
  if [ ${res[$s]} -ne 1 ]; then
      echo $fchar
      fail=1
  else
      echo $okchar
  fi
done
}
