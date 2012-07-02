@echo off

set CWD=%CD%
cd /D C:\RCS\DB

bin\baretail.exe log\mongoc.log log\mongos.log log\mongod.log

cd /D %CWD%
