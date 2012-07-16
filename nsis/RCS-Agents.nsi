;NSIS Modern User Interface

;--------------------------------
!include "MUI2.nsh"
  
!include nsDialogs.nsh
!include Sections.nsh
!include LogicLib.nsh
;--------------------------------
;General
  
  !define PACKAGE_NAME "RCS-Agents"
  !Define /file PACKAGE_VERSION "..\config\VERSION_BUILD"

  ;Name and file
  Name "RCS-Agents"
  OutFile "rcs-agents-${PACKAGE_VERSION}.exe"

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

;--------------------------------
;Languages

  !insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Installer Sections

Section "Install Section" SecInstall

  SetDetailsPrint "both"
  DetailPrint "Extracting Agents files..."
  SetDetailsPrint "textonly"
  !cd '..'
  SetOutPath "$INSTDIR\DB\cores"
  File /r "cores\*.*"

  SetDetailsPrint "both"
  DetailPrint "done"

  DetailPrint "ReStarting RCS DB..."
  SimpleSC::RestartService "RCSDB" "" 30

  SetDetailsPrint "both"
  DetailPrint "done"
  
  !cd "nsis"
  
SectionEnd


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Function .onInit

  ${IfNot} ${RunningX64}
    MessageBox MB_OK "RCS can be installed only on 64 bit systems"
    Quit
  ${EndIf}

  ReadRegDWORD $R0 HKLM "Software\HT\RCS" "installed"

  ; RCS is not installed
  IntCmp $R0 1 +3 0 0
    MessageBox MB_OK "RCS Agents can be installed only if RCS is already installed"
    Quit

FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
