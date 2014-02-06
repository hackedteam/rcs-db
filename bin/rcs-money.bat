@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-money %*

cd /D %CWD%
