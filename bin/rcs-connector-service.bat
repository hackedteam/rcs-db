@echo off

IF %1 == restart (
  net stop RCSConnector
  net start RCSConnector
) ELSE (
  net %1 RCSConnector
)

