echo off

echo Generating RCS-Exploit NSIS installer...
makensis /V1 RCS-Exploits.nsi

echo Signing RCS-Exploits installer...
SignTool.exe sign /P password /f HT.pfx rcs-exploits-2012063001.exe

echo.
echo Generating RCS-Agent NSIS installer...
makensis /V1 RCS-Agents.nsi

echo Signing RCS-Agents installer...
SignTool.exe sign /P password /f HT.pfx rcs-agents-2012063001.exe

echo.
echo Generating RCS NSIS installer...
makensis /V1 RCS.nsi

echo Signing RCS installer...
SignTool.exe sign /P password /f HT.pfx rcs-setup-2012063001.exe
