@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-db-license %*

cd /D %CWD%
