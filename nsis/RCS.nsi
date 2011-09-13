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
	Var installALLINONE
	Var installDISTRIBUTED
	Var installUPGRADE
	
	Var installCollector
	Var installNetworkController
	Var installMaster
	Var installShard

	Var adminpass
	Var masterAddress
	Var masterCN
	Var masterLicense
	
	Var upgradeComponents
	
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
   !define SETUP_UPGRADE 1
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
  Page custom FuncCertificate FuncCertificateLeave
  Page custom FuncLicense FuncLicenseLeave
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
 
 	WriteRegDWORD HKLM "Software\HT\RCS" "installed" 0x00000001
	
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncUpgrade

	ReadRegDWORD $R0 HKLM "Software\HT\RCS" "installed"
	
	; RCS is not installed
	IntCmp $R0 1 +2 0 0
		Abort

  ; check which components we have
	ReadRegDWORD $R0 HKLM "Software\HT\RCS" "collector"
	IntCmp $R0 1 0 +3 +3
		StrCpy $upgradeComponents "$upgradeComponentsCollector$\r"
		${NSD_GetState} ${BST_CHECKED} $installCollector

	ReadRegDWORD $R0 HKLM "Software\HT\RCS" "networkcontroller"
	IntCmp $R0 1 0 +3 +3
		StrCpy $upgradeComponents "$upgradeComponentsNetwork Controller$\r"
		${NSD_GetState} ${BST_CHECKED} $installNetworkController

	ReadRegDWORD $R0 HKLM "Software\HT\RCS" "master"
	IntCmp $R0 1 0 +3 +3
		StrCpy $upgradeComponents "$upgradeComponentsMaster$\r"
		${NSD_GetState} ${BST_CHECKED} $installMaster

	ReadRegDWORD $R0 HKLM "Software\HT\RCS" "shard"
	IntCmp $R0 1 0 +3 +3
		StrCpy $upgradeComponents "$upgradeComponentsShard$\r"
		${NSD_GetState} ${BST_CHECKED} $installShard


  !insertmacro MUI_HEADER_TEXT "Installation Type" "Upgrade"

  nsDialogs::Create /NOUNLOAD 1018
  
  CreateFont $R1 "Arial" "8" "600"
  
  ${NSD_CreateLabel} 0 5u 100% 20u "The setup has detected that at least one RCS component is installed on this machine."
  ${NSD_CreateLabel} 0 25u 100% 20u  "If you continue the following components will be upgraded:"
  ${NSD_CreateLabel} 20u 40u 100% 50u  $upgradeComponents
  Pop $1
  SendMessage $1 ${WM_SETFONT} $R1 0
  
  ${NSD_CreateCheckBox} 20u 100u 200u 12u "YES, Upgrade."
  Pop $1
  SendMessage $1 ${WM_SETFONT} $R1 0
 
  nsDialogs::Show
FunctionEnd

Function FuncUpgradeLeave
	${NSD_GetState} $1 $installUPGRADE

	${If} $installUPGRADE != ${BST_CHECKED}
		MessageBox MB_OK|MB_ICONSTOP "Please check the upgrade option. If you don't want to upgrade exit the installer now."
    Abort
  ${EndIf}
  
  SetCurInstType SETUP_UPGRADE
  
FunctionEnd


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncInstallationType
   ${If} $installUPGRADE == ${BST_CHECKED}
		Abort
   ${EndIf}
   
  !insertmacro MUI_HEADER_TEXT "Installation Type" "Deployment Method"

  nsDialogs::Create /NOUNLOAD 1018
  
  CreateFont $R1 "Arial" "8" "600"
  
  ${NSD_CreateLabel} 0 5u 100% 10u "Please select the installation type you want:"
  ${NSD_CreateRadioButton} 20u 20u 200u 12u "All-in-one"
  Pop $1
  SendMessage $1 ${WM_SETFONT} $R1 0
  ${NSD_CreateLabel} 30u 35u 250u 25u "All the compoments will be installed on a single machine. Easy setup for small deployments."
  
  ${NSD_CreateRadioButton} 20u 60u 200u 12u "Distributed"
  Pop $2
  SendMessage $2 ${WM_SETFONT} $R1 0
  ${NSD_CreateLabel} 30u 75u 250u 25u "The installation is fully customizable. Each component can be installed on different machine to achieve maximum scalability. Suggested for big deployments."

  ${NSD_Check} $1

  nsDialogs::Show
FunctionEnd

Function FuncInstallationTypeLeave
  ${NSD_GetState} $1 $installALLINONE
  ${NSD_GetState} $2 $installDISTRIBUTED
  
  ; Automatically select all the components
  ${If} $installALLINONE == ${BST_CHECKED}
		${NSD_GetState} ${BST_CHECKED} $installCollector
		${NSD_GetState} ${BST_CHECKED} $installNetworkController
  	${NSD_GetState} ${BST_CHECKED} $installMaster
  ${EndIf}
FunctionEnd


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncSelectComponents
   ${If} $installUPGRADE == ${BST_CHECKED}
   ${OrIf} $installALLINONE == ${BST_CHECKED}
		Abort
   ${EndIf}

  !insertmacro MUI_HEADER_TEXT "Installation Type" "Components selection"
  
  CreateFont $R1 "Arial" "8" "600"
  
  nsDialogs::Create /NOUNLOAD 1018
  
  ${NSD_CreateLabel} 0 0u 100% 10u "Frontend:"
  Pop $0
  SendMessage $0 ${WM_SETFONT} $R1 0
  ${NSD_CreateCheckBox} 20u 10u 200u 12u "Collector"
  Pop $1
  SendMessage $1 ${WM_SETFONT} $R1 0
  ${NSD_CreateLabel} 30u 23u 300u 25u "Service responsible for the data collection from the agents. It has to be exposed on the internet with a public IP address."

  ${NSD_CreateCheckBox} 20u 45u 200u 12u "Network Controller"
  Pop $2
  SendMessage $2 ${WM_SETFONT} $R1 0
  ${NSD_CreateLabel} 30u 58u 300u 15u "Service responsible for the communications with Anonymizers and Injection Proxies."

  ${NSD_CreateLabel} 0 70u 100% 10u "Backend:"
  Pop $0
  SendMessage $0 ${WM_SETFONT} $R1 0
  ${NSD_CreateCheckBox} 20u 80u 200u 12u "Master Node"
  Pop $3
  SendMessage $3 ${WM_SETFONT} $R1 0
  ${NSD_CreateLabel} 30u 93u 300u 15u "The Application Server and the primary node for the Database."

  ${NSD_CreateCheckBox} 20u 110u 200u 12u "Shard"
  Pop $4
  SendMessage $4 ${WM_SETFONT} $R1 0
  ${NSD_CreateLabel} 30u 123u 280u 25u "Distributed single shard of the Database. It needs at least one Master node to be connected to."
  
  nsDialogs::Show
FunctionEnd

Function FuncSelectComponentsLeave
  ${NSD_GetState} $1 $installCollector
  ${NSD_GetState} $2 $installNetworkController
  ${NSD_GetState} $3 $installMaster
  ${NSD_GetState} $4 $installShard
FunctionEnd



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncCertificate
   ${If} $installUPGRADE == ${BST_CHECKED}
		Abort
   ${EndIf}
   ${If} $installMaster != ${BST_CHECKED} 
   ${AndIf} $installDISTRIBUTED == ${BST_CHECKED}
		 Abort
   ${EndIf}
   
   !insertmacro MUI_HEADER_TEXT "Configuration settings: Certificate" "Please enter configuration settings."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateLabel} 0 5u 100% 10u "Certificate Common Name (hostname or IP address):"
   ${NSD_CreateLabel} 5u 22u 20u 10u "CN:"
   ${NSD_CreateText} 30u 20u 200u 12u ""
   Pop $1

   ${NSD_SetFocus} $1
   nsDialogs::Show
FunctionEnd

Function FuncCertificateLeave
	${NSD_GetText} $1 $masterCN

  StrCmp $masterCN "" 0 +3
  	MessageBox MB_OK|MB_ICONSTOP "Certificate CN cannot be empty"
    Abort
    
  ${StrFilter} $masterCN "12" "-." "" $0
  StrCmp $0 $masterCN +3 0
    MessageBox MB_OK|MB_ICONSTOP "Certificate CN can only contain alphanumeric characters, hyphens and dots"
    Abort
    
FunctionEnd



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncLicense
   ${If} $installUPGRADE == ${BST_CHECKED}
   ${AndIf} $installMaster != ${BST_CHECKED}
		Abort
   ${EndIf}
   ${If} $installMaster != ${BST_CHECKED} 
   ${AndIf} $installDISTRIBUTED == ${BST_CHECKED}
		 Abort
   ${EndIf}
  
   !insertmacro MUI_HEADER_TEXT "Configuration settings: License" "Please enter configuration settings."

   nsDialogs::Create /NOUNLOAD 1018

   ${NSD_CreateLabel} 0 5u 100% 10u "License file:"
   ${NSD_CreateLabel} 5u 22u 40u 10u "License:"
   ${NSD_CreateFileRequest} 50u 20u 145u 12u ""
   Pop $1
   ${NSD_CreateBrowseButton} 200u 20u 50u 12u "Browse..."
   Pop $0
   GetFunctionAddress $2 BrowseClickFunction
   nsDialogs::OnClick /NOUNLOAD $0 $2

   ${NSD_SetFocus} $1
   nsDialogs::Show
FunctionEnd

Function FuncLicenseLeave
   ${NSD_GetText} $1 $masterLicense

   StrCmp $masterLicense "" 0 +3
      MessageBox MB_OK|MB_ICONSTOP "License file cannot be empty"
      Abort

   IfFileExists $masterLicense +3 0
      MessageBox MB_OK|MB_ICONSTOP "Cannot read license file"
      Abort
FunctionEnd

Function BrowseClickFunction
   nsDialogs::SelectFileDialog /NOUNLOAD open "" "License files (*.lic)|*.lic"
   Pop $0

   SendMessage $1 ${WM_SETTEXT} 0 STR:$0
FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncInsertCredentials
   ${If} $installUPGRADE == ${BST_CHECKED}
		Abort
   ${EndIf}
  !insertmacro MUI_HEADER_TEXT "Configuration settings: Admin account" "Please enter configuration settings."

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



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Function FuncInsertAddress
   ${If} $installUPGRADE == ${BST_CHECKED}
		Abort
   ${EndIf}
  ${If} $installALLINONE == ${BST_CHECKED} 
  ${OrIf} $installMaster == ${BST_CHECKED}
    StrCpy $masterAddress "localhost"
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
	${NSD_GetText} $1 $masterAddress

  StrCmp $masterAddress "" 0 +3
  	MessageBox MB_OK|MB_ICONSTOP "Address for Master Node cannot be empty"
    Abort
FunctionEnd