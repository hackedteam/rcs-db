@echo off

set CWD=%CD%
cd /D C:\RCS\DB

ruby bin\rcs-remove-version-seven %*

cd /D %CWD%
