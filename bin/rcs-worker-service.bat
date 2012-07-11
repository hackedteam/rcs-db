@echo off

IF %1 == restart (
  net stop RCSWorker
  net start RCSWorker
) ELSE (
  net %1 RCSWorker
)

