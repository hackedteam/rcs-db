@echo off

IF %1 == restart (
  net stop RCSAggregator
  net start RCSAggregator
) ELSE (
  net %1 RCSAggregator
)

