@echo off

IF %1 == restart (
  net stop RCSOCR
  net start RCSOCR
) ELSE (
  net %1 RCSOCR
)

