@echo off

IF %1 == restart (
  net stop RCSMasterConfig
  net start RCSMasterConfig
  net stop RCSShard
  net start RCSShard
  net stop RCSMasterRouter
  net start RCSMasterRouter
) ELSE (
  net %1 RCSMasterConfig
  net %1 RCSMasterRouter
  net %1 RCSShard
)


