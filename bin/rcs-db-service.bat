@echo off

IF %1 == restart (
  net stop RCSDB
  net start RCSDB
) ELSE (
  net %1 RCSDB
)