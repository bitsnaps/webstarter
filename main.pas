unit main;

{$mode delphi}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Menus, ATLinkLabel, UniqueInstance, IniFiles;

{ TfmMain }

type
  TfmMain = class(TForm)
    btnStart: TButton;
    btnStop: TButton;
    Label1: TLabel;
    Label2: TLabel;
    lbDbStatus: TLabel;
    lbWebStatus: TLabel;
    lbUrl: TLinkLabel;
    pmTray: TPopupMenu;
    miExit: TMenuItem;
    miShow: TMenuItem;
    MainTrayIcon: TTrayIcon;
    OneInstance: TUniqueInstance;
    procedure btnStopClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure MainTrayIconClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miShowClick(Sender: TObject);
  private
    { private declarations }
    function ProcessRunning(ProcessName: string): Boolean;
    procedure SetCurrentPath(Path: string);
    procedure StopServer(SectionName: string);
  public
    { public declarations }
  end;

var
  fmMain: TfmMain;
  iniFile: TIniFile;

implementation

uses
  process, LCLIntf;

const
  AUTO_RUN = 'autorun';
  WEB_SERVER = 'web_server';
  DB_SERVER = 'db_server';
  ENABLE = 'enable';
  EXEC_DIR = 'exec_dir';
  CMD_START = 'command_start';
  CMD_STOP = 'command_stop';
  BROWSER = 'browser';
  FULL_URL = 'full_url';
  BROWSER_PATH = 'browser_path';

  STARTED = 'Started';
  STOPPED = 'Stopped';

{$R *.lfm}

{ TfmMain }


function ExecuteProcess(Command: AnsiString): Boolean;
var
   RunProgram: TProcess;
begin
  Result := False;
   RunProgram := TProcess.Create(nil);
   try
     // Old way (Deprecated)
     RunProgram.CommandLine := Command;

     //RunProgram.Executable := Command;
     //RunProgram.Parameters.Add('-h');
     // This will wait the process until it's stop
     //RunProgram.Options := RunProgram.Options + [poWaitOnExit];

     RunProgram.ShowWindow := swoHIDE;
     RunProgram.Execute;
     Result := True;
   finally
     RunProgram.Free;
   end;
end;

procedure TfmMain.SetCurrentPath(Path: string);
begin
 	if Path <> EmptyStr then
  		chdir( Path )
   else
     chdir( ExtractFilePath(Application.ExeName) );
end;

procedure TfmMain.btnStartClick(Sender: TObject);
var
   ExecDir, CmdStart: string;
begin

   // Check if Web server is enabled
   if iniFile.ReadBool(WEB_SERVER, ENABLE, False) then begin
     ExecDir := iniFile.ReadString(WEB_SERVER, EXEC_DIR, GetCurrentDir);
     SetCurrentPath(ExecDir);
     CmdStart := iniFile.ReadString(WEB_SERVER, CMD_START, EmptyStr);
    // Start the Web server
    if CmdStart <> EmptyStr then
    if not ExecuteProcess(CmdStart) then begin
     MessageDlg('Error', 'Cannot run ' + WEB_SERVER, mtWarning, [mbOK], 0);
     lbWebStatus.Caption:= STOPPED;
    end else begin
    	lbWebStatus.Caption:= STARTED;
    end;
   end;

   // Check if DB server section is enabled
   if iniFile.ReadBool(DB_SERVER, ENABLE, False) then begin
     ExecDir := iniFile.ReadString(DB_SERVER, EXEC_DIR, GetCurrentDir);
     SetCurrentPath(ExecDir);
     CmdStart := iniFile.ReadString(DB_SERVER, CMD_START, EmptyStr);

    // Start the DB server
    if CmdStart <> EmptyStr then
    if not ExecuteProcess(CmdStart) then begin
     MessageDlg('Error', 'Cannot run ' + DB_SERVER, mtWarning, [mbOK], 0);
     lbDbStatus.Caption:= STOPPED;
    end else begin
    	lbDbStatus.Caption:= STARTED;
    end;
   end;

end;

procedure TfmMain.FormActivate(Sender: TObject);
var
   AutoRun: Boolean;
   CmdBrowse: string;
begin
   if iniFile.ReadBool(BROWSER, ENABLE, False) then begin
    lbUrl.Link := iniFile.ReadString(BROWSER, FULL_URL, EmptyStr);
    lbUrl.Caption:= lbUrl.Link;
   end;

   // Read Ini file
   AutoRun := iniFile.ReadBool(Application.Title, AUTO_RUN, False);

   if AutoRun then begin
    btnStart.Click;
    Sleep(2000);
   	// Open the browser at the end
    CmdBrowse := iniFile.ReadString(BROWSER, BROWSER_PATH, '');
    if CmdBrowse <> EmptyStr then
    	ExecuteProcess(CmdBrowse + ' ' + lbUrl.Link)
    else
      OpenURL(lbUrl.Link);
   end;

end;

procedure TfmMain.btnStopClick(Sender: TObject);
begin
  StopServer(WEB_SERVER);
  StopServer(DB_SERVER);
end;

procedure TfmMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if (lbWebStatus.Caption = STARTED) or (lbDbStatus.Caption = STARTED) then
  if MessageDlg('Stop servers?', 'Do you want to stop servers?', mtConfirmation,
  mbYesNo, 0) = mrYes then begin
   try
     // Stop the web server before exit
     if lbWebStatus.Caption = STARTED then
     	StopServer(WEB_SERVER);

     // Stop the DB server before exit
     if lbDbStatus.Caption = STARTED then
     	StopServer(DB_SERVER);
   except
   end;
    CloseAction := caFree;
  end else
  	CloseAction := caNone;
end;

function TfmMain.ProcessRunning(ProcessName: string): Boolean;
begin
  if ProcessName = WEB_SERVER then begin
  	Result := lbWebStatus.Caption = STARTED;
  end else begin
     Result := lbDbStatus.Caption = STARTED;
  end;
end;

procedure TfmMain.StopServer(SectionName: string);
var
   CmdStop, ExecDir: string;
begin
  if not ProcessRunning(SectionName) then
   Exit;

 ExecDir := iniFile.ReadString(SectionName, EXEC_DIR, GetCurrentDir);
 SetCurrentPath(ExecDir);

 CmdStop := iniFile.ReadString(SectionName, CMD_STOP, EmptyStr);
 if CmdStop <> EmptyStr then
  if ExecuteProcess(CmdStop) then begin

   if SectionName = WEB_SERVER then
    lbWebStatus.Caption := STOPPED
   else
     lbDbStatus.Caption := STOPPED;

  end;

end;

procedure TfmMain.FormCreate(Sender: TObject);
var
   IniFileName: string;
   StrList: TStringList;
begin
   IniFileName := Application.Title+'.ini';
   if FileExists( IniFileName ) then begin
     iniFile := TIniFile.Create(IniFileName);
   end else begin
        if MessageDlg('INI File not found', 'The INI file could not be found, would you like to create a new one?',
        mtConfirmation, mbYesNo, 0) = mrYes then begin
          StrList := TStringList.Create;
					StrList.Add('['+Application.Title+']');
          StrList.Add(AUTO_RUN+'=0');
          StrList.Add('');
          StrList.Add('['+WEB_SERVER+']');
          StrList.Add(ENABLE  + '=1');
          StrList.Add(EXEC_DIR + '=c:\xampp');
          StrList.Add(CMD_START+ '=apache\bin\httpd.exe');
          StrList.Add(CMD_STOP + '=apache\bin\pv -f -k httpd.exe -q');
          StrList.Add('');
          StrList.Add('['+DB_SERVER+']');
          StrList.Add(ENABLE+'=1');
          StrList.Add(EXEC_DIR + '=c:\xampp');
          StrList.Add(CMD_START + '="mysql\bin\mysqld.exe" --standalone');
          StrList.Add(CMD_STOP + '=mysql\bin\mysqladmin -u root shutdown');
          StrList.Add('');
          StrList.Add('['+BROWSER+']');
          StrList.Add(ENABLE + '=1');
          StrList.Add(BROWSER_PATH + '=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe');
          StrList.Add(FULL_URL + '=http://localhost/website');
          StrList.SaveToFile(IniFileName);
          StrList.Free;
        end else
        	Application.Terminate; // Close the app if no ini file can be created!
   end;
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  iniFile.Free;
end;

procedure TfmMain.FormWindowStateChange(Sender: TObject);
begin
  if WindowState = wsMinimized then begin
   Hide;
   ShowInTaskBar := stNever;
   MainTrayIcon.ShowBalloonHint;
  end;
end;

procedure TfmMain.MainTrayIconClick(Sender: TObject);
begin
  Visible := not Visible;
  if Visible then
  	ShowInTaskBar := stDefault;
end;

procedure TfmMain.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfmMain.miShowClick(Sender: TObject);
begin
  if Visible then
     Hide
  else
    begin
      WindowState := wsNormal;
      Show;
    end;
end;

end.

