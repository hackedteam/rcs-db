!macro FileSearch
Function FileSearch
Exch $R0 ;search for
Exch
Exch $R1 ;input file
Push $R2
Push $R3
Push $R4
Push $R5
Push $R6
Push $R7
Push $R8
Push $R9
 
  StrLen $R4 $R0
  StrCpy $R7 0
  StrCpy $R8 0
 
  ClearErrors
  FileOpen $R2 $R1 r
  IfErrors Done
 
  LoopRead:
    ClearErrors
    FileRead $R2 $R3
    IfErrors DoneRead
 
    IntOp $R7 $R7 + 1
    StrCpy $R5 -1
    StrCpy $R9 0
 
    LoopParse:
      IntOp $R5 $R5 + 1
      StrCpy $R6 $R3 $R4 $R5
      StrCmp $R6 "" 0 +4
        StrCmp $R9 1 LoopRead
          IntOp $R7 $R7 - 1
          Goto LoopRead
      StrCmp $R6 $R0 0 LoopParse
        StrCpy $R9 1
        IntOp $R8 $R8 + 1
        Goto LoopParse
 
  DoneRead:
    FileClose $R2
  Done:
    StrCpy $R0 $R8
    StrCpy $R1 $R7
 
Pop $R9
Pop $R8
Pop $R7
Pop $R6
Pop $R5
Pop $R4
Pop $R3
Pop $R2
Exch $R1 ;number of lines found on
Exch
Exch $R0 ;output count found
FunctionEnd
!macroend