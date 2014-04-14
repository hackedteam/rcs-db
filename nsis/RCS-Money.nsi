;NSIS Modern User Interface

;--------------------------------
!include "MUI2.nsh"
  
!include nsDialogs.nsh
!include Sections.nsh
!include LogicLib.nsh
!include WinVer.nsh
!include StrFunc.nsh
${StrStr}

;--------------------------------
;General
  
  !define PACKAGE_NAME "RCS-Money"
  !Define /file PACKAGE_VERSION "..\config\VERSION_BUILD"

  ;Name and file
  Name "RCS-Money"
  OutFile "rcs-money-${PACKAGE_VERSION}.exe"

  ;Default installation folder
  InstallDir "C:\RCS\"

  ShowInstDetails "show"
  ShowUnInstDetails "show"
  
  !include "WordFunc.nsh"

;--------------------------------

!macro _RunningX64 _a _b _t _f
  !insertmacro _LOGICLIB_TEMP
  System::Call kernel32::GetCurrentProcess()i.s
  System::Call kernel32::IsWow64Process(is,*i.s)
  Pop $_LOGICLIB_TEMP
  !insertmacro _!= $_LOGICLIB_TEMP 0 `${_t}` `${_f}`
!macroend

!define RunningX64 `"" RunningX64 ""`

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
  !insertmacro MUI_PAGE_INSTFILES

  ;Uninstaller pages
  !insertmacro MUI_UNPAGE_WELCOME
  !insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section "Install Section" SecInstall
  SetDetailsPrint "both"

  DetailPrint "Extracting files..."
  SetDetailsPrint "textonly"
  !cd '..'

  SetOutPath "$INSTDIR\DB\lib"
  File "lib\rcs-money.rb"

  SetOutPath "$INSTDIR\DB\lib\rcs-money-release"
  File /r "lib\rcs-money-release\*.*"

  SetOutPath "$INSTDIR\DB\bin"
  File /r "bin-release\rcs-money"

  SetOutPath "$INSTDIR\DB\bin"
  File /r "bin-release\rcs-money.bat"

  SetDetailsPrint "both"
  DetailPrint "Done"

  ReadRegDWORD $R0 HKLM "Software\HT\RCS" "money"
  IntCmp $R0 1 alreadyinstalled

  DetailPrint "Creating service RCS Money..."
  nsExec::Exec "$INSTDIR\DB\bin\nssm.exe install RCSMoney $INSTDIR\Ruby\bin\ruby.exe $INSTDIR\DB\bin\rcs-money"
  SimpleSC::SetServiceFailure "RCSMoney" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
  WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSMoney" "DisplayName" "RCS Money"
  WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSMoney" "Description" "Remote Control System Money Module"
  DetailPrint "Done"

  DetailPrint "Writing Windows registry..."
  WriteRegDWORD HKLM "Software\HT\RCS" "money" 0x00000001

  alreadyinstalled:

  DetailPrint "Stopping RCS Money..."
  SimpleSC::StopService "RCSMoney"
  Sleep 5000

  DetailPrint "Starting RCS Money..."
  SimpleSC::StartService "RCSMoney"
  Sleep 5000

  !cd "nsis"

  DetailPrint "Writing uninstall informations..."
  SetDetailsPrint "textonly"
  WriteUninstaller "$INSTDIR\setup\RCS-Money-uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "DisplayName" "RCS Money"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "DisplayIcon" "$INSTDIR\setup\RCS.ico"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "DisplayVersion" "${PACKAGE_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "UninstallString" "$INSTDIR\setup\RCS-Money-uninstall.exe"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "NoModify" 0x00000001
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "NoRepair" 0x00000001
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney" "InstDir" "$INSTDIR"

  SetDetailsPrint "both"

SectionEnd

Section Uninstall
  DetailPrint "Stopping RCS Money service..."
  SimpleSC::StopService "RCSMoney" 1
  DetailPrint "Done"

  DetailPrint "Removing RCS Money service..."
  SimpleSC::RemoveService "RCSMoney"
  DetailPrint "Done"

  DetailPrint "Deleting files..."
  SetDetailsPrint "textonly"
  ReadRegStr $INSTDIR HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCS" "InstDir"

  RMDir /r "$INSTDIR\DB\money"
  RMDir /r "$INSTDIR\DB\lib\rcs-money-release"
  Delete "$INSTDIR\DB\lib\rcs-money.rb"

  SetDetailsPrint "both"
  DetailPrint "Done"

  DetailPrint ""
  DetailPrint "Removing registry keys..."
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSMoney"
  DeleteRegKey HKLM "Software\HT\RCS\money"
  DetailPrint "Done"

SectionEnd


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Function .onInit

  ; check that 9.2.x is already installed
  FileOpen $4 "$INSTDIR\DB\config\VERSION" r
  FileRead $4 $1
  FileClose $4
  ${If} $1 != ""
     ${StrStr} $0 $1 "9.2"
     ${If} $0 == ""
       MessageBox MB_OK "This version can only be installed on 9.2.x systems, you have $1"
       Quit
     ${EndIf}
  ${EndIf}

  ${IfNot} ${RunningX64}
    MessageBox MB_OK "RCS can be installed only on 64 bit systems"
    Quit
  ${EndIf}

  ${If} ${IsWin2008R2}
  ${AndIfNot} ${AtLeastServicePack} 1
    MessageBox MB_OK "Please install Windows Server 2008 R2 SP1 before installing RCS"
  ${EndIf}

  ${IfNot} ${AtLeastWin2008R2}
    ${IfNot} ${AtLeastWin7}
      MessageBox MB_OK "RCS can be installed only on Windows Server 2008 R2 or above"
      Quit
    ${EndIf}
  ${EndIf}

  ReadRegDWORD $R0 HKLM "Software\HT\RCS" "installed"

  ; RCS is not installed
  IntCmp $R0 1 +3 0 0
    MessageBox MB_OK "RCS Money can be installed only if RCS is already installed"
    Quit

FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
