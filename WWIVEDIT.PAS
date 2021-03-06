PROGRAM WWIVEdit(Input,Output);
(******************************************************************************
 **                                                                          **
 **                             WWIVEdit Version 2.3                         **
 **                           Copyright (c) 1991-1992                        **
 **                        By Adam Caldwell (The Emporer)                    **
 **                            Last Modified : 9/27/92                       **
 **                          1@16470 (Link), 1@6470 (Net)                    **
 **                     [The First Galactic Empire Net/Link]                 **
 **                              BBS: (614) 593-7836                         **
 **                             Voice: (614) 594-3051                        **
 **                                                                          **
 ** Purpose : WWIV is a full screen editor designed specifically for use with**
 ** the WWIV 4.xx BBS system.  It takes advantage of many of the features    **
 ** features of WWIV such as colors, Macros, and WWIV specific formatting    **
 ** functions.                                                               **
 ** It is a Word Processor like editor that I have written to be             **
 ** easily Extendable (if you understand my programming style :-)            **
 **                                                                          **
 ** This source code (with ceartain exceptions is Copyrighted by             **
 ** Adam Caldwell, however this code may be freely modified and distributed  **
 ** so long as:                                                              **
 **    1) No Fee is charged for this or any product derived from this code   **
 **    2) Any modifications that you make are CLEARLY noted as not being     **
 **       my code (ie, initial it) if you distrubute modified versions       **
 **    3) You don't change this message header in any way [including removal **
 **       of it]                                                             **
 **    4) Do NOT use the naming convention WEDITSxx.ZIP when distributing it **
 **       This is reserved for *official* releases                           **
 **                                                                          **
 ******************************************************************************)
{$I WEGLOBAL.PAS}

USES DOS, WEVars, WEKbd, WETime, WEString, WEFunc1,
     WELine, WEHelp, WEOutput, WEInit, WEInput, WEDefaul, WEESM,
     WESetup, WEFile,WEChat, WETag, WWIVOutp, WEReply, WEMemory,
     WEUser, WEFunc, WEMouse, WEDos, WEDictn, WEComp, WEQuote, cursors

{$IFDEF OVERLAY}
     ,Overlay
{$ENDIF};

{$IFDEF OVERLAY}
  {$O WEDictN}
  {$O WEHelp}
  {$O WEReply}
  {$O WEChat}
  {$O WEDos}
  {$O WEComp}
  {$O WETag}
  {$O WESetup}
  {$O WEDefaul}
  {$O WETag}
  {$O WEQuote}
  {$O WETitle}
  {$O Cursors}
  {$O WEUser}
  {$O WEFunc1}
  {$O WEFossil}
{$ENDIF}



procedure release_timeslice;
var regs : registers;
begin
     Inline(
                               {      ; DESQview PAUSE function}
        $53                  {      PUSH BX}
        /$BB/$00/$10    {      MOV BX,$1000}
        /$50                   {      PUSH AX}
        /$B8/$1A/$10           {      MOV AX,$101A}
        /$CD/$15               {      INT $15}
        /$89/$D8               {      MOV AX,BX}
        /$CD/$15               {      INT $15}
        /$B8/$25/$10           {      MOV AX,$1025}
        /$CD/$15               {      INT $15}
        /$58                   {      POP AX}
        /$5B                   {      POP BX}
      );
    regs.ax:=$1680;
    intr($2f,regs);
    {intr($f4,regs);}
    intr($28,regs);
end;




PROCEDURE MakeResultFile(i:integer; title:string);
TYPE
  FeditS = RECORD
             title:string[81];
             anon : integer;
           END;
VAR
  t:text;
  f:file of fedits;
  fed:FeditS;

BEGIN
  IF length(title)>80 THEN
    title:=copy(title,1,80);
  assign(t,'RESULT.ED');
  assign(f,'FEDIT.INF');
  CASE Setting.ResultType OF
    0 : ;
    1 : IF (i<>0) OR TitleChanged THEN
        BEGIN
          rewrite(t);
          writeln(t,i);
          writeln(t,title);
          close(t);
        END ELSE
        BEGIN
          {$I-} erase(t); {$I+}
          i:=ioresult;
        END;
    2 : IF TitleChanged OR (i<>0) THEN
        BEGIN
          rewrite(f);
          fed.title:=title;
          fed.title[length(title)+1]:=#0;
          fed.anon:=i;
          write(f,fed);
          close(f);
        END;
  END;
END;



FUNCTION Done(VAR Cmd:EdFun):boolean;
{ Asks whether or not user wants to save, Abort, or Resume, and handles
  calls to EditTagline }
VAR
  ch:char;
  OkSet : CharSet;
  TagS:string;
  TagCh:string;
BEGIN
  Ansic('0');
  OkSet:=['A','S','R','D','C',ESC];
  IF NOT (Cmd IN [AbortPost,QuietExitAndSave]) THEN
  BEGIN
    IF NOT Setting.DisableUserTag THEN BEGIN
      TagS:=Gets(XSTR+19);
      OkSet:=OkSet+['T'];
      TagCh:='T'
    END ELSE BEGIN
      TagS:='';
      TagCh:=''
    END;
    StatusLine3(Gets(XSTR+20)+TagS+' [ASRDC'+TagCh+'] > '+C1);
    IF Cmd=ExitAndSave
      THEN ch:='S'
      ELSE ch:=ReadSet(OkSet);
    IF ch=#27 THEN ch:='R';
    ansic('0');
    IF ch='A' THEN
    BEGIN
      gotoxy(6,WindowBottom+1);
      clreol;
      XWrite(21);
      ch:=ReadSet(['Y','N',ENTERKey,ESC]);
      IF ch <>'Y'
        THEN ch:='R'
        ELSE ch:='A'
    END;
    IF ch='R' THEN
    BEGIN
      StatusLine3('');
      ShowMaxLines
    END
    ELSE IF Ch='T' THEN
    BEGIN
      EditTaglines;
      ForcedRedisplay;
    END
    ELSE IF ch='D' THEN
    BEGIN
      EditDefaults;
      ForcedRedisplay;
    END
    ELSE IF ch='C' THEN
      SpellCheck;
    Done:=ch IN ['S','A'];
    IF ch ='A' THEN nl;
    IF ch='S' THEN cmd:=ExitAndSave;
  END;
  IF (Setting.ReplyType>0) AND (cmd IN [QuietExitAndSave,ExitAndSave]) AND
     (NOT HandleReply) THEN Done:=False;
END;

PROCEDURE ForceDone;
{ Yell at the user for going over line limit }
BEGIN
  StatusLine1(c6+'No More Lines Left.'+chr(7)+c0);
END;


PROCEDURE PrintOutput;
{ Prints the current text buffer to the screen }
VAR
  i, j, s : integer;
  ccol : char;

BEGIN
  clrscr;
  ccol:='0';
  ansic(ccol);
  writeln(title);
  i:=0;
  WHILE i < Highline DO
  BEGIN
    inc(i);
    IF cmpLeftI(Line^[i]^.l,'/C:') THEN
      Center(RightS(Line^[i]^.l,len(i)-3))
    ELSE
    FOR j:=1 TO Len(i) DO
    BEGIN
      IF Line^[i]^.c[j]<>ccol THEN BEGIN
        ccol:=Line^[i]^.c[j];
        ansic(ccol);
      END;
      write(Line^[i]^.l[j]);
    END;
    IF checkAbort THEN i:=HighLine;
    writeln;
    ccol:='0';
    ansic('0');
  END;
  pausescr;
  ForcedRedisplay;
END;

PROCEDURE RemoveLast;
BEGIN
  dec(cy);
  DeleteLine(cy);
END;

PROCEDURE DoSlash(VAR fun : Edfun);
VAR
  s:string;
  dummy:integer;
  t:text;
  tmp : LineType;
  cc : char;
  i : integer;
BEGIN
  s:=TransformString(Line^[cy-1]^.l);
  IF cmpleft('/DEFAULTS',s) THEN
  BEGIN
    RemoveLast;
    EditDefaults;
    ForcedRedisplay;
  END;
  IF s='/HELP' THEN
  BEGIN
    RemoveLast;
    Help;
  END;
  IF s='/CLR' THEN
  BEGIN
    FOR cy:=1 TO MaxLines DO
      InitLine(Line^[cy]^);
    cy:=1;
    HighLine:=0;
  END;
  IF s='/RL' THEN
  BEGIN
    RemoveLast;
    RemoveLast;
  END;
  IF s='/LI' THEN
  BEGIN
    RemoveLast;
    PrintOutput;
  END;
  IF (s='/TI') AND AllowTitleChange THEN
  BEGIN
    RemoveLast;
    gotoxy(9,1);
    ansic('0');
    write(title);
    ansic('0');
    cc := '0';
    InitLine(tmp);
    FOR i:=1 TO Length(title) DO
      IF title[i]=^C THEN BEGIN
        cc:=title[i+1];
        i:=i+1;
      END
      ELSE BEGIN
        tmp.l:=tmp.l+title[i];
        tmp.c:=tmp.c+cc;
      END;

    IF LineEditor(tmp,9,1,length(tmp.l)+1,60,Setting.AllowColorChangeInTitle) THEN
    BEGIN
      LineToString(tmp,title);
      TitleChanged:=TRUE;
    END
    ELSE
       BEGIN gotoxy(9,1); ansic('1'); write(title); END;
  END;
  IF (s='/CHECK') OR (s='/SPELL') THEN BEGIN
    RemoveLast;
{$IFDEF BETA}
    WriteOutputFile(StartupDir+cstr(usernum)+'.TXT',dummy,TRUE);
{$ENDIF}
    SpellCheck;
{$IFDEF BETA}
    assign(t,startupDir+cstr(usernum)+'.TXT');
    {$I-} erase(t); {$I+} IF IOResult=0 THEN ;
{$ENDIF}
  END;
  IF s='/RD' THEN BEGIN
    RemoveLast;
    DoFun(RedisplayAll,' ');
  END;
  IF (length(s)<=4) AND (cmpLeft(s,'/ES') OR cmpLeft(s,'/S')) THEN
    Fun:=QuietExitAndSave;
  IF s='/ABT' THEN Fun:=AbortPost;
  IF ((s='/QUOTE') OR (s='/Q')) THEN
  BEGIN
    RemoveLast;
    CASE setting.quoter OF
      1 : Macro(^Q);
      2 : IF Exists(QuoteFile) THEN
          BEGIN
            IF MaxLines-Highline<=5 THEN
            BEGIN
              StatusLine3('You don''t have enough lines left.');
              AfterNext:=ClrStatLine3;
            END ELSE BEGIN
              IF PerformQuote(QuoteTmp,MaxLines-HighLine-5) THEN
              BEGIN
                ReadInputFile(cy,QuoteTmp);
                clrscr;
                cy:=HighLine+1;
                EraseF(QuoteTmp);
                cx:=1;
                ViewTop:=cy-3;
                IF ViewTop<1 THEN ViewTop:=1;
                ViewBottom:=ViewTop+WindowHeight;
                IF ViewBottom>MaxLines THEN
                BEGIN
                  ViewBottom:=MaxLines;
                  ViewTop:=ViewBottom-WindowHeight
                END;
              END;
              ForcedRedisplay
            END
          END
          ELSE BEGIN
            StatusLine3(Gets(XStr+25));
            AfterNext:=ClrStatLine3;
          END
    END;
  END;
END;


FUNCTION EditText:EdFun;
VAR
  ch :char;
  fun : edfun;
  Any,done : boolean;
  s : string;

BEGIN
  Highline:=MaxLines;
  WHILE (HighLine>0) AND (Len(HighLine)=0) DO
    dec(Highline);
  REPEAT
    IF (cy>HighLine) AND (Len(cy)>0) THEN
      HighLine:=cy;
    IF cy>MaxLines THEN BEGIN
      write(^G);
      cy:=MaxLines;
    END;
    IF highline+1=MaxLines THEN
      StatusLine3(c6+'One Line Left!'+c0);
    IF highline=MaxLines THEN
      ForceDone;

    s:='';
    REPEAT
      IF (length(s)>0) AND (pos(s[1],Escaped)>0) THEN
      BEGIN
        ch:=GetKey(TRUE);
        IF (Actual) then s:=s+ch;
        Done:=GetFun(s,fun,any) OR ((NOT Actual) AND (Fun<>None));
      END ELSE BEGIN
        ch:=GetKey(FALSE);
        s:=s+ch;
        Done := GetFun(s,fun,any);
      END;
      IF (Not Any) THEN
      BEGIN
        IF (s[1]=#0) AND Setting.WWIVEditMacrosOk
          THEN WWIVEditMacro(s[2]);
        s:='';
        END;
    UNTIL Done;
    s:='';
    DoFun(fun,ch);

    IF (Fun=Enter) AND (len(cy-1)>1) AND (character(cy-1,1)='/') THEN
      DoSlash(Fun);

    IF Setting.SmoothScroll THEN
    BEGIN
      IF cy=ViewTop-1 THEN
        ScrollWindowDown(1,WindowTop,LineLen,WindowBottom);

      IF cy=ViewBottom+1 THEN
        ScrollWindowUp(1,WindowTop,LineLen,WindowBottom);
      Redisplay;
    END;
    ResetViewport;
    IF cy>MaxLines THEN cy:=MaxLines;
    Drain;
    IF (not KeyPressed) OR (Fun=Enter) THEN
      redisplay;                    { Redisplay Everything that has changed   }
  UNTIL (fun IN [AbortPost,ExitAndSave,NormalExit,QuietExitAndSave]);
  ReDisplay; { In case there are still keystrokes in the buffer [macro] }
  EditText:=Fun;
END;
{$IFDEF DEBUG}
VAR
  OldExit : Pointer;
PROCEDURE ErrorHandler; far;
BEGIN
  IF ErrorAddr<>NIL THEN
  BEGIN
    writeln;
    writeln;
    writeln('A fatal error has occurred.');
    write('The problem was caused by: ');
    CASE ExitCode OF
{$IFDEF BETA}
        1 : write('invalid DOS function call');
        6 : write('invalid file handle');
        8 : write('not enough memory');
       12 : write('invalid file access code');
       15 : write('invalid drive number');
      200 : write('divide by zero');
      202 : write('stack overflow');
      204 : write('invalid pointer operation');
{$ENDIF}
        2 : write('file not found');
        3 : write('path not found');
        4 : write('too many files open');
        5 : write('file access denied');
      100 : write('disk read error');
      101 : write('disk write error');
      106 : write('invalid numeric format');
      203 : write('heap overflow');
      208 : write('overlay manager not installed');
      209 : write('overlay file read error');
{$IFDEF DEBUG}
       16 : write('can not remove current directory');
       17 : write('can not rename accross drives');
      102 : write('file not assigned');
      103 : write('file not open');
      104 : write('file not open for input');
      105 : write('file not open for output');
      201 : write('range check');
      205 : write('floating point overflow');
      206 : write('floating point underflow');
      207 : write('invalid floating point operation');
      210 : write('object not initialized');
      211 : write('call to abstract method');
      212 : write('stream registration error');
      213 : write('collection index out of range');
      214 : write('collection overflow error');
{$ENDIF}
    ELSE write('unknown')
    END;
    writeln;
    writeln;
    writeln('Please report the following information to the author:');
  END;
  ExitProc:=OldExit;
END;
{$ENDIF}

PROCEDURE Terminate; far;
VAR
  t:text;
BEGIN
  MergeLocalInput;  { fix a long standing problem with hanging up in chat mode! }
{
  assign(t,StartupDir+'CRASH\U'+cstr(usernum)+'.TXT');
  rewrite(t);
  SaveLines(t,1,HighLine);
  close(t);
}
  MemCleanup;
  ErrorLevel:=1;
  halt(ErrorLevel);
END;

PROCEDURE Setup;
TYPE
  PArray = ARRAY[0..25] OF Pointer;
VAR
  p:^PArray;
  st:string;
  ignore:word;
{ Mainly conditional compilation stuff... Just wanted to clean up the main }
BEGIN
  st:=getenv('WWIV_FP');
  IF st<>'' THEN
  BEGIN
    p:=ptr(hexval(copy(st,1,4)),hexval(copy(st,6,4)));
    p^[20] := @terminate;
  END;
  {$V-}Fsplit(ParamStr(0),StartupDir,st,st);  {$V+}
{$IFDEF DEBUG}
  OldExit:=ExitProc;
  ExitProc:=@ErrorHandler;
{$ENDIF}
{$IFDEF OVERLAY}
  OvrInit(ParamStr(0));
  IF ovrResult<>OvrOk THEN
  BEGIN
    OvrInit(StartupDir+'WWIVEDIT.OVR');
    IF ovrResult<>ovrOk THEN
    BEGIN
      XWritelns(22,23);
      MemCleanup;
      ErrorLevel:=1;
      Halt(ErrorLevel);
    END;
  END;
{  OvrInitEMS;  Do not use this... will cause problems }
  Drain;
{$ENDIF}
  Ignore:=InitMouse;
  Initialize;                                                  Drain;
  clrscr;                        { Clear the Screen }
END;

PROCEDURE Cleanup(Result:edfun);
VAR
  ch:char;
  ReturnCode : integer;          { The number returned in RESULT.ED }
  f:file;

BEGIN
  IF Result=AbortPost THEN ClrScr;   { If the Sysop aborts it with ALT-A then clear the screen }
  IF Result = QuietExitAndSave THEN
    StatusLine1('');
  ReturnCode:=0;
  IF Result IN [ExitAndSave,QuietExitAndSave] THEN
  BEGIN
    IF Info.AskTag AND NOT Setting.DisableUserTag THEN
    BEGIN
      StatusLine3(Gets(XSTR+24));
      ch:=ReadSet(['Y','N',#13]);
      IF ch = 'N' THEN Setting.DisableUserTag := TRUE;
    END;
    WriteOutputFile(Filename,ReturnCode,false);
    MakeResultFile(Returncode, Title);
    ErrorLevel:=0;
  END ELSE ErrorLevel:=1;
  SaveInfo;
  nl;
  ansic('0'); clreol;
  assign(f,DictDir+'IGNORE.DIC');
  {$I-} erase(f); {$I+}
  IF IOResult=0 THEN ;
{$IFDEF DISTRIBUTION}
  assign(f,'EDITOR.INF');
  {$I-} erase(f); {$I+}
  IF IOResult=0 THEN ;
{$ENDIF}
  IF Setting.mouse AND MouseInstalled THEN HideMouse;
  IF Setting.ChangeCursor AND NOT InsertMode THEN Cursor(Underscore);
  MemCleanup;
END;

VAR
  Result : edfun;                { The Result of the Visual Edit }

BEGIN { Main }
  Setup;                         { Initialize overlays, read in config }
  ReadInputFile(1,Filename);     { Read in the Input file }
  ShowHeader;                    { Show the message header }
  Redisplay;                     { Show the file - If one was read it }
  REPEAT
    ansic(CurrentColor);
    gotoxy(cx,cy+WindowTop-ViewTop); { Put the cursor in the right position }
    result := EditText;              { Do a visual Edit and get the result  }
  UNTIL Done(Result);                { True it the user saves or aborts     }
  Cleanup(Result);
  Halt(ErrorLevel);
END.  { Main }
