@echo off

IF %1 == restart (
  net stop RCSTranslate
  net start RCSTranslate
) ELSE (
  net %1 RCSTranslate
)

