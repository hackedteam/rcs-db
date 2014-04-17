@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-db-status %*

cd /D %CWD%
