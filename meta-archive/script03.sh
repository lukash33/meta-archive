#!/bin/bash

# load demo data

[ "zero$MA_DEMO" = "zero" ] && exit 0

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE

bzip2 -d < MA.dmp.bz2 > /u01/app/oracle/admin/XE/dpdump/MA.dmp

for file in MA.MA_FILES MA.MA_PATHS; do
time impdp system/$PASSWORD CONTENT=DATA_ONLY DUMPFILE=MA.dmp TABLES=$file DIRECTORY=DATA_PUMP_DIR LOGFILE=MA.imp.$file.log;
done

rm -f /u01/app/oracle/admin/XE/dpdump/MA.dmp
