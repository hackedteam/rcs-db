;NSIS Modern User Interface

;--------------------------------
!include "MUI2.nsh"
  
!include nsDialogs.nsh
!include Sections.nsh
;--------------------------------
;General
	
  !define PACKAGE_NAME "RCS"
  !Define /file PACKAGE_VERSION "..\config\version.txt"

  ;Variables
  Var insttype
	Var installALLINONE
	Var installDISTRIBUTED
	Var installCollector
	Var installNetworkController
	Var installMaster
	Var installShard

	Var adminpass
	Var masteraddress
	
  ;Name and file
  Name "RCS"
  OutFile "RCS-${PACKAGE_VERSION}.exe"

  ;Default installation folder
  InstallDir "C:\RCS\"

  ShowInstDetails "show"
  ShowUnInstDetails "show"
  
  !include "WordFunc.nsh"
  
;--------------------------------
;Install types
   InstType "install"
   InstType "update"
   !define SETUP_INSTALL 0
   !define SETUP_UPDATE 1
;--------------------------------

;--------------------------------
;Interface Settings

  !define MUI_ABORTWARNING
  !define MUI_WELCOMEFINISHPAGE_BITMAP "HT.bmp"
  !define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH
  !define MUI_ICON "RCS.ico"
  !define MUI_UNICON "RCS.ico"
  BrandingText "]HackingTeam[ ${PACKAGE_NAME} (${PACKAGE_VERSION})"

;--------------------------------
;Pages

  !insertmacro MUI_PAGE_WELCOME
  Page custom FuncUpgrade FuncUpgradeLeave
  Page custom FuncInstallationType FuncInstallationTypeLeave
  Page custom FuncSelectComponents FuncSelectComponentsLeave
  Page custom FuncInsertCredentials FuncInsertCredentialsLeave
  Page custom FuncInsertAddress FuncInsertAddressLeave
  !insertmacro MUI_PAGE_INSTFILES

  !insertmacro MUI_UNPAGE_WELCOME
  !insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section "Update Section" SecUpdate
   SectionIn 2

   DetailPrint ""
   DetailPrint "Uninstalling RCSDB Service..."
   SimpleSC::StopService "RCSDB" 1
   SimpleSC::RemoveService "RCSDB"
   DetailPrint "done"
   
   SetDetailsPrint "textonly"
   DetailPrint "Removing previous version..."
   RMDir /r "$INSTDIR\Ruby"
   RMDir /r "$INSTDIR\DB\lib"
   RMDir /r "$INSTDIR\DB\bin"
   DetailPrint "done"
  
SectionEnd

Section "Install Section" SecInstall
 
  SectionIn 1 2
 
 	Return
 
  SetDetailsPrint "textonly"
  DetailPrint "Extracting common files..."

  !cd '..\..'
  SetOutPath "$INSTDIR\Ruby"
  #File /r "Ruby\*.*"

  !cd 'DB'
  SetOutPath "$INSTDIR\DB\setup"
  File "nsis\RCS.ico"

  SetOutPath "$INSTDIR\DB\bin"
  File /r "bin\*.*"
  
  SetOutPath "$INSTDIR\DB\lib"
  File "lib\rcs-db.rb"
  File "lib\rcs-worker.rb"
  
  SetOutPath "$INSTDIR\DB\lib\rcs-db-release"
  #File /r "lib\rcs-db-release\*.*"

  SetOutPath "$INSTDIR\DB\lib\rcs-worker-release"
  #File /r "lib\rcs-worker-release\*.*"
  
  SetOutPath "$INSTDIR\DB\config"
  File "config\trace.yaml"
  File "config\version.txt"
  DetailPrint "done"
  
  SetDetailsPrint "both"
    
  DetailPrint "Setting up the path..."
  ReadRegStr $R0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
  StrCpy $R0 "$R0;$INSTDIR\DB\bin;$INSTDIR\Ruby\bin"
  WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path" "$R0"
  DetailPrint "done" 

  ; fresh install
  ${If} $insttype == ${SETUP_INSTALL}
    DetailPrint ""
    DetailPrint "Writing the configuration..."
    SetDetailsPrint "textonly"
    CopyFiles /SILENT $cert "$INSTDIR\Collector\config\rcs-ca.pem"
    CopyFiles /SILENT $sign "$INSTDIR\Collector\config\rcs-server.sig"
    ; write the config yaml
    nsExec::Exec  "$INSTDIR\Ruby\bin\ruby.exe $INSTDIR\Collector\bin\rcs-db-config --defaults --db-address $addr"
    SetDetailsPrint "both"
    DetailPrint "done"
  ${EndIf}
    
    
  DetailPrint ""

  DetailPrint "Adding firewall rule for port 4444/tcp..."
  nsExec::ExecToLog 'netsh firewall add portopening TCP 4444 "RCSDB"'

  DetailPrint "Starting RCSDB..."
  SimpleSC::InstallService "RCSDB" "RCS DB" "16" "2" "$INSTDIR\DB\bin\srvany" "" "" ""
  SimpleSC::SetServiceFailure "RCSDB" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
  WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSDB\Parameters" "Application" "$INSTDIR\Ruby\bin\ruby.exe $INSTDIR\DB\bin\rcs-db"
  SimpleSC::StartService "RCSDB" ""
   
  DetailPrint "Writing uninstall informations..."
  SetDetailsPrint "textonly"
  WriteUninstaller "$INSTDIR\DB\setup\RCSDB-uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "DisplayName" "RCS Collector"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "DisplayIcon" "$INSTDIR\DB\setup\RCS.ico"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "DisplayVersion" "${PACKAGE_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "UninstallString" "$INSTDIR\DB\setup\RCSDB-uninstall.exe"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "NoModify" 0x00000001
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "NoRepair" 0x00000001
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "InstDir" "$INSTDIR"

  SetDetailsPrint "both"
 
SectionEnd

Section Uninstall

  DetailPrint "Removing firewall rule for 4444/tcp..."
  nsExec::ExecToLog 'netsh firewall delete portopening TCP 4444'

  DetailPrint "Stopping RCSDB Service..."
  SimpleSC::StopService "RCSDB" 1
  SimpleSC::RemoveService "RCSDB"
  DetailPrint "done"

  DetailPrint ""
  DetailPrint "Deleting files..."
  SetDetailsPrint "textonly"
  ReadRegStr $INSTDIR HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB" "InstDir"
  RMDir /r "$INSTDIR\DB"
  ; #TODO: delete ruby if not rcsdb
  RMDir /r "$INSTDIR\Ruby"
  RMDir /r "$INSTDIR"
  SetDetailsPrint "both"
  DetailPrint "done"

  DetailPrint ""
  DetailPrint "Removing registry keys..."
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSDB"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Run\RCSDB"
	DetailPrint "done"

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

SectionEnd

;--------------------------------
;Installer Functions

Function .onInit
	
	Return
	
   IfFileExists "$INSTDIR\DB\config\version.txt" 0 +4
      SetCurInstType 1
      MessageBox MB_YESNO|MB_ICONQUESTION "RCS is already installed.$\nDo you want to update?" IDYES +2 IDNO 0
         Quit
   
   GetCurInstType $insttype
   Return
FunctionEnd



Function FuncUpgrade
FunctionEnd

Function FuncUpgradeLeave
FunctionEnd



Function FuncInstallationType
  !insertmacro MUI_HEADER_TEXT "Installation Type" "Method selection"

  nsDialogs::Create /NOUNLOAD 1018
  
  ${NSD_CreateLabel} 0 5u 100% 10u "Please select the installation type you want:"
  ${NSD_CreateRadioButton} 20u 20u 200u 12u "All-in-one"
  Pop $1
  ${NSD_CreateRadioButton} 20u 40u 200u 12u "Distributed"
  Pop $2

  ${NSD_Check} $1

  nsDialogs::Show
FunctionEnd

Function FuncInstallationTypeLeave
  ${NSD_GetState} $1 $installALLINONE
  ${NSD_GetState} $2 $installDISTRIBUTED
FunctionEnd


Function FuncSelectComponents
   ${If} $installALLINONE == ${BST_CHECKED}
		Abort
   ${EndIf}

  !insertmacro MUI_HEADER_TEXT "Installation Type" "Components selection"

  nsDialogs::Create /NOUNLOAD 1018
  
  ${NSD_CreateLabel} 0 5u 100% 10u "Front End:"
  ${NSD_CreateCheckBox} 20u 20u 200u 12u "Collector"
  Pop $1
  ${NSD_CreateCheckBox} 20u 35u 200u 12u "Network Controller"
  Pop $2

  ${NSD_CreateLabel} 0 60u 100% 10u "Back End:"
  ${NSD_CreateCheckBox} 20u 75u 200u 12u "Master Node"
  Pop $3
  ${NSD_CreateCheckBox} 20u 90u 200u 12u "Shard"
  Pop $4
  
  nsDialogs::Show
FunctionEnd

Function FuncSelectComponentsLeave
  ${NSD_GetState} $1 $installCollector
  ${NSD_GetState} $2 $installNetworkController
  ${NSD_GetState} $3 $installMaster
  ${NSD_GetState} $4 $installShard
FunctionEnd


Function FuncInsertCredentials
  !insertmacro MUI_HEADER_TEXT "Configuration settings" "Please enter configuration settings."

  nsDialogs::Create /NOUNLOAD 1018

  ${NSD_CreateLabel} 0 5u 100% 10u "Account for the 'admin' user:"
  ${NSD_CreateLabel} 5u 22u 40u 10u "Password:"
  ${NSD_CreatePassword} 50u 20u 200u 12u ""
  Pop $1

  ${NSD_SetFocus} $1
  
  nsDialogs::Show
FunctionEnd

Function FuncInsertCredentialsLeave
	${NSD_GetText} $1 $adminpass

  StrCmp $adminpass "" 0 +3
  	MessageBox MB_OK|MB_ICONSTOP "Password for user 'admin' cannot be empty"
    Abort
FunctionEnd


Function FuncInsertAddress
  ${If} $installALLINONE == ${BST_CHECKED}
    StrCpy $masteraddress "localhost"
		Abort
  ${EndIf}
  ${If} $installMaster == ${BST_CHECKED}
    StrCpy $masteraddress "localhost"
		Abort
  ${EndIf}
    
  !insertmacro MUI_HEADER_TEXT "Configuration settings" "Please enter configuration settings."

  nsDialogs::Create /NOUNLOAD 1018

  ${NSD_CreateLabel} 0 40u 100% 10u "Address of the Master Node:"
  ${NSD_CreateLabel} 5u 57u 40u 10u "Hostname:"
  ${NSD_CreateText} 50u 55u 200u 12u ""
  Pop $1

  ${NSD_SetFocus} $1
  
  nsDialogs::Show
FunctionEnd

Function FuncInsertAddressLeave
	${NSD_GetText} $1 $masteraddress

  StrCmp $masteraddress "" 0 +3
  	MessageBox MB_OK|MB_ICONSTOP "Address for Master Node cannot be empty"
    Abort
FunctionEnd