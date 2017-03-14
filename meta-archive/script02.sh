#!/bin/bash

export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE

sqlplus / as sysdba <<EOF
REM drop user APEX_040000 cascade;
alter user APEX_050100 account unlock identified by $PASSWORD;
create user MA default tablespace USERS identified by $PASSWORD;
alter user MA quota unlimited on USERS;
grant CONNECT, RESOURCE, create view, create sequence, create library to MA;
EOF

# Change APEX port: How to Configure Oracle Application Express (APEX) & the Embedded PL/SQL Gateway (EPG) in an 11G DB (Doc ID 457621.1)
sqlplus / as sysdba <<EOF
SELECT dbms_xdb.gethttpport() FROM DUAL;
exec DBMS_XDB.SETHTTPPORT(8080);
SELECT dbms_xdb.gethttpport() FROM DUAL;
COMMIT;
EOF

# Do not apply this fix to APEX > 5.0:
cat > /dev/null <<DONE
# Note: High Virtual Circuit Waits When Working with the Apex Application Using XDB (Doc ID 1136313.1):
sqlplus / as sysdba <<EOF
DECLARE
v_cfg XMLTYPE;
BEGIN
SELECT UpdateXML(dbms_xdb.cfg_get(),'/xdbconfig/sysconfig/call-timeout/text()','300','xmlns="http://xmlns.oracle.com/xdb/xdbconfig.xsd"') INTO v_cfg FROM dual;
DBMS_XDB.CFG_UPDATE(v_cfg);
COMMIT;
END;
/
EOF
DONE

# nls_numeric_characters causing error in translated app APEX 4.0 https://community.oracle.com/thread/2193431
sqlplus / as sysdba <<EOF
alter system set NLS_NUMERIC_CHARACTERS='. ' scope=spfile;
alter system set sga_max_size=960M scope=spfile;
alter system set pga_aggregate_target=64M scope=spfile;
purge dba_recyclebin;
startup force;
EOF

sqlplus APEX_050100/$PASSWORD <<EOF
@meta-workspace.sql
EOF

sqlplus MA/$PASSWORD <<EOF
@metaarchive-app.sql
EOF

cat > $ORACLE_HOME/lib/ma_import.c <<EOF
//
// to compile:
//   gcc -fpic -shared -nostdlib -o ma_import.so ma_import.c
//
// to declare:
//   create or replace library ma_import_lib as '/u01/app/oracle/product/11.2.0/xe/lib/ma_import.so';
//   create or replace function ma_import_single (url in char) return char as external name "ma_import_single" library ma_import_lib language C parameters (url, url length, return);
//
// to use:
//   select ma_import_single('http://mybirdphotos.info/wp-content/uploads/2012/03/CSC_0213.jpg') from dual;
//
// 
//

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

char *ma_import_single(char *url, int *url_len) {
        char *log = "/meta-archive/Import.pl.single.log";
        char full_cmd[4000];
        static char out[4000];
        int out_len;
        FILE *LOG;
        sprintf(full_cmd,"/meta-archive/Import.pl --threads=1 '%s' 2>&1 > %s",url,log);
        system(full_cmd);
        LOG = fopen(log,"r"); 
        out_len = fread(out,1,4000,LOG); 
        fclose(LOG); 
        if(out_len < 0) { perror("log read error"); } 
        out[out_len]=0;
        return(out);
}
EOF
gcc -fpic -shared -nostdlib -o $ORACLE_HOME/lib/ma_import.so $ORACLE_HOME/lib/ma_import.c

sqlplus MA/$PASSWORD <<EOF
create or replace library ma_import_lib as '/u01/app/oracle/product/11.2.0/xe/lib/ma_import.so';
/
create or replace function ma_import_single (url in char) return char as external name "ma_import_single" library ma_import_lib language C parameters (url, url length, return);
/
EOF
