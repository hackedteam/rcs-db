@echo off

IF %1 == restart (
  net stop RCSIntelligence
  net start RCSIntelligence
) ELSE (
  net %1 RCSIntelligence
)

