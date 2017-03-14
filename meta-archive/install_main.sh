#!/bin/bash

s=/meta-archive; cd $s || exit 1;

exec >> >(tee -ai $s/install_main.sh.log)
exec 2>&1

echo "Download and setup additional software..."
echo "Executing script01.sh..."
bash $s/script01.sh >& $s/script01.sh.log < /dev/null
chown -R oracle:dba $s

/etc/init.d/oracle-xe start

echo "Setup APEX application"
echo "Executing script02.sh..."
su oracle -p -c $s/script02.sh >& $s/script02.sh.log < /dev/null

[ "zero$MA_DEMO$MA_IMPORT" = "zero" ] && exit 0

echo "Optionally install demo data..."
echo "Executing script03.sh..."
su oracle -p -c $s/script03.sh >& $s/script03.sh.log < /dev/null

echo "Optionally preparing import user data script..."
echo "Preparing script04.sh..."

cat > $s/script04.sh <<EOF
#!/bin/bash

# import user data

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=\$ORACLE_HOME/bin:\$PATH
export ORACLE_SID=XE

[ "zero$MA_IMPORT" = "zero" ] || time bash -c "find $MA_DATA | sort | $s/Import.pl"
EOF

chmod +x $s/script04.sh

echo "Stopping Oracle..."
/etc/init.d/oracle-xe stop
