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
  
  !define PACKAGE_NAME "RCS-Translate"
  !Define /file PACKAGE_VERSION "..\config\VERSION_BUILD"

  ;Name and file
  Name "RCS-Translate"
  OutFile "rcs-translate-${PACKAGE_VERSION}.exe"

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

  DetailPrint "Stopping RCS Translate..."
  SimpleSC::StopService "RCSTranslate" 1

  !cd '..'

  SetOutPath "$INSTDIR\DB\lib"
  File "lib\rcs-translate.rb"

  SetOutPath "$INSTDIR\DB\lib\rcs-translate-release"
  File /r "lib\rcs-translate-release\*.*"

  SetOutPath "$INSTDIR\DB\bin"
  File /r "bin\rcs-translate"

  SetDetailsPrint "both"
  DetailPrint "done"

  ReadRegDWORD $R0 HKLM "Software\HT\RCS" "translate"
  IntCmp $R0 1 alreadyinstalled

  DetailPrint "Creating service RCS Translate..."
  nsExec::Exec "$INSTDIR\DB\bin\nssm.exe install RCSTranslate $INSTDIR\Ruby\bin\ruby.exe $INSTDIR\DB\bin\rcs-translate"
  SimpleSC::SetServiceFailure "RCSTranslate" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
  WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSTranslate" "DisplayName" "RCS Translate"
  WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSTranslate" "Description" "Remote Control System Translate processor"
  DetailPrint "done"

  WriteRegDWORD HKLM "Software\HT\RCS" "translate" 0x00000001

  alreadyinstalled:

  DetailPrint "Starting RCS Translate..."
  SimpleSC::StartService "RCSTranslate" "" 30

  !cd "nsis"

  DetailPrint "Writing uninstall informations..."
  SetDetailsPrint "textonly"
  WriteUninstaller "$INSTDIR\setup\RCS-ORC-uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "DisplayName" "RCS Translate"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "DisplayIcon" "$INSTDIR\setup\RCS.ico"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "DisplayVersion" "${PACKAGE_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "UninstallString" "$INSTDIR\setup\RCS-Translate-uninstall.exe"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "NoModify" 0x00000001
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "NoRepair" 0x00000001
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate" "InstDir" "$INSTDIR"

  SetDetailsPrint "both"

SectionEnd

Section Uninstall
  DetailPrint "Stopping RCS Translate Services..."
  SimpleSC::StopService "RCSTranslate" 1
  DetailPrint "done"

  DetailPrint "Removing RCS Translate Services..."
  SimpleSC::RemoveService "RCSTranslate"
  DetailPrint "done"

  DetailPrint ""
  DetailPrint "Deleting files..."
  SetDetailsPrint "textonly"
  ReadRegStr $INSTDIR HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCS" "InstDir"

  RMDir /r "$INSTDIR\DB\lib\rcs-translate-release"
  Delete "$INSTDIR\DB\lib\rcs-translate.rb"

  SetDetailsPrint "both"
  DetailPrint "done"

  DetailPrint ""
  DetailPrint "Removing registry keys..."
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\RCSTranslate"
  DeleteRegKey HKLM "Software\HT\RCS\translate"
  DetailPrint "done"

SectionEnd


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Function .onInit

	; check that 8.3.x is already installed
	FileOpen $4 "$INSTDIR\DB\config\VERSION" r
	FileRead $4 $1
	FileClose $4
	${StrStr} $0 $1 "8.3"
	${If} $0 == ""
  	MessageBox MB_OK "This version can only be installed on 8.3.x systems, you have $1"
  	Quit
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
    MessageBox MB_OK "RCS Translate can be installed only if RCS is already installed"
    Quit

FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
