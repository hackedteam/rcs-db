@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-db-log %*

cd /D %CWD%
