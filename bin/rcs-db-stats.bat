@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-db-stats %*

cd /D %CWD%
