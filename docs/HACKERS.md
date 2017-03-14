# For Hackers

Most of the code is in the **Import.pl** file. The file implements importing RAW and JPG files into database and indexing. 
You can call **Import.pl** from root or oracle users. Use commandline and long-form options documented in the script itself.
Optionally you have to define some http_proxy before calling the script. Import phase uses Internet only to fetch Google Maps info.

Rest of the code is the APEX application which implements browsing and searching archive. For archive to be browsed you have to
import something first.

Most of passwords are "secret" by default. You can change any of them freely but the ORACLE database MA user password which 
is hardcoded in the **Import.pl**. Use METAARCHIVE/secret apex
username/password to access to META workspace and application code. Use ORACLE database
MA/secret username/password, ORACLE_SID=XE and port=1521 to access database schema directly.

Use **Import.pl** to populate database. Navigate to http://localhost:8080/apex/f?p=101 to browse database.
Navigate to http://localhost:8080/apex to modify application.

## Credentials:

ORACLE:
* SYS/secret
* SYSTEM/secret
* MA/secret

APEX:
* ADMIN/secret
* WS=META/USER=METAARCHIVE/secret

** My archive occupies above 1.3tb of disk space on SATA HD. 10 years (2006-2016), more than 120000 shots taken by DSLRs, Android smatrphones and tablets. Importing the whole archive using 5 threads on 4 core CPU takes ~2 days.**



