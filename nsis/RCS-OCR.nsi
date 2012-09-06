;NSIS Modern User Interface

;--------------------------------
!include "MUI2.nsh"
  
!include nsDialogs.nsh
!include Sections.nsh
!include LogicLib.nsh
;--------------------------------
;General
  
  !define PACKAGE_NAME "RCS-OCR"
  !Define /file PACKAGE_VERSION "..\config\VERSION_BUILD"

  ;Name and file
  Name "RCS-OCR"
  OutFile "rcs-ocr-${PACKAGE_VERSION}.exe"

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
  DetailPrint "Extracting OCR files..."
  SetDetailsPrint "textonly"
  !cd '..'
  SetOutPath "$INSTDIR\DB\ocr"
  File /r "ocr\*.*"

  SetOutPath "$INSTDIR\DB\lib"
  File "lib\rcs-ocr.rb"

  SetOutPath "$INSTDIR\DB\lib\rcs-ocr-release"
  File /r "lib\rcs-ocr-release\*.*"

  SetOutPath "$INSTDIR\DB\bin"
  File /r "bin\rcs-ocr"

  SetDetailsPrint "both"
  DetailPrint "done"

  ReadRegDWORD $R0 HKLM "Software\HT\RCS" "ocr"
  IntCmp $R0 1 alreadyinstalled

    DetailPrint "Creating service RCS OCR..."
    nsExec::Exec "$INSTDIR\DB\bin\nssm.exe install RCSOCR $INSTDIR\Ruby\bin\ruby.exe $INSTDIR\DB\bin\rcs-ocr"
    SimpleSC::SetServiceFailure "RCSOCR" "0" "" "" "1" "60000" "1" "60000" "1" "60000"
    WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSOCR" "DisplayName" "RCS OCR"
    WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\RCSOCR" "Description" "Remote Control System OCR processor"
    DetailPrint "done"

    WriteRegDWORD HKLM "Software\HT\RCS" "ocr" 0x00000001

    nsExec::Exec "reg import $INSTDIR\DB\ocr\ocr-key.reg"

    DetailPrint "Starting RCS OCR..."
    SimpleSC::StartService "RCSOCR" "" 30
    Goto done

  alreadyinstalled:
    DetailPrint "ReStarting RCS OCR..."
    SimpleSC::RestartService "RCSOCR" "" 30

  done:

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
    MessageBox MB_OK "RCS OCR can be installed only if RCS is already installed"
    Quit

FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
