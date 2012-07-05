@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-db-mongo-log %*

cd /D %CWD%
