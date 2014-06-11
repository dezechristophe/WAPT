unit uVisServerPostconf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls,
  Graphics, Dialogs, ComCtrls, StdCtrls, ExtCtrls, Buttons, ActnList,
  EditBtn;

type

  { TVisWAPTServerPostConf }

  TVisWAPTServerPostConf = class(TForm)
    ActCheckDNS: TAction;
    ActCreateKey: TAction;
    ActCancel: TAction;
    actWriteConfStartServe: TAction;
    ActManual: TAction;
    ActNext: TAction;
    actPrevious: TAction;
    ActionList1: TActionList;
    ButPrevious: TBitBtn;
    ButNext: TBitBtn;
    BitBtn3: TBitBtn;
    BitBtn4: TBitBtn;
    BitBtn5: TBitBtn;
    BitBtn6: TBitBtn;
    cbManualURL: TCheckBox;
    DirectoryCert: TDirectoryEdit;
    edCommonName: TEdit;
    edCountry: TEdit;
    EdSourcesRoot: TLabeledEdit;
    edEmail: TEdit;
    EdPwd1: TEdit;
    EdPrivateKeyFN: TEdit;
    edLocality: TEdit;
    edOrganization: TEdit;
    EdOrgName: TEdit;
    EdPwd2: TEdit;
    edUnit: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label2: TLabel;
    EdWAPTServerName: TLabeledEdit;
    edWAPTRepoURL: TLabeledEdit;
    edWAPTServerURL: TLabeledEdit;
    Label3: TLabel;
    Label9: TLabel;
    EdWaptServerIP: TLabeledEdit;
    EdWaptInifile: TMemo;
    EdTemplatesRepoURL: TLabeledEdit;
    EdDefaultPrefix: TLabeledEdit;
    PagesControl: TPageControl;
    Panel1: TPanel;
    pgParameters: TTabSheet;
    pgPassword: TTabSheet;
    Shape1: TShape;
    StaticText1: TStaticText;
    pgFinish: TTabSheet;
    pgDevparam: TTabSheet;
    TabSheet3: TTabSheet;
    procedure ActCheckDNSExecute(Sender: TObject);
    procedure ActCreateKeyExecute(Sender: TObject);
    procedure ActCreateKeyUpdate(Sender: TObject);
    procedure ActManualExecute(Sender: TObject);
    procedure ActManualUpdate(Sender: TObject);
    procedure ActNextExecute(Sender: TObject);
    procedure ActNextUpdate(Sender: TObject);
    procedure actPreviousExecute(Sender: TObject);
    procedure actPreviousUpdate(Sender: TObject);
    procedure actWriteConfStartServeExecute(Sender: TObject);
    procedure BitBtn3Click(Sender: TObject);
    procedure EdOrgNameExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PagesControlChange(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  VisWAPTServerPostConf: TVisWAPTServerPostConf;

implementation
uses Windows,WaptCommon,tisinifiles,superobject,tiscommon,tisstrings,IniFiles;
{$R *.lfm}

{ TVisWAPTServerPostConf }

// qad %(key)s python format
function pyformat(template:String;params:ISuperobject):String;
var
  key,value:ISuperObject;
begin
  Result := template;
  for key in params.AsObject.GetNames do
    Result := StringReplace(Result,'%('+key.AsString+')s',params.S[key.AsString],[rfReplaceAll]);
end;

function CreateSelfSignedCert(orgname,
        wapt_base_dir,
        destdir,
        country,
        locality,
        organization,
        orgunit,
        commonname,
        email:String
    ):String;
var
  opensslbin,opensslcfg,opensslcfg_fn,destpem,destcrt : String;
  params : ISuperObject;
begin
    destpem := AppendPathDelim(destdir)+orgname+'.pem';
    destcrt := AppendPathDelim(destdir)+orgname+'.crt';
    if not DirectoryExists(destdir) then
        mkdir(destdir);
    params := TSuperObject.Create;
    params.S['country'] := country;
    params.S['locality'] :=locality;
    params.S['organization'] := organization;
    params.S['unit'] := orgunit;
    params.S['commonname'] := commonname;
    params.S['email'] := email;

    opensslbin :=  AppendPathDelim(wapt_base_dir)+'lib\site-packages\M2Crypto\openssl.exe';
    opensslcfg :=  pyformat(FileToString(AppendPathDelim(wapt_base_dir) + 'templates\openssl_template.cfg'),params);
    opensslcfg_fn := AppendPathDelim(destdir)+'openssl.cfg';
    StringToFile(opensslcfg_fn,opensslcfg);
    try
      SetEnvironmentVariable(PAnsiChar('OPENSSL_CONF'),PAnsiChar(opensslcfg_fn));
      if ExecuteProcess(opensslbin,'req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "'+destpem+'" -out "'+destcrt+'"',[]) <> 0 then
        result :=''
      else
        result := destpem;
    finally
      SysUtils.DeleteFile(opensslcfg_fn);
    end;
end;

function GetWaptServerURL: String;
begin
  result := IniReadString(WaptIniFilename,'Global','wapt_server');
end;

function GetWaptRepoURL: Utf8String;
begin
  result := IniReadString(WaptIniFilename,'Global','repo_url');
  if Result = '' then
      Result:='http://wapt/wapt';
  if result[length(result)] = '/' then
    result := copy(result,1,length(result)-1);
end;


procedure TVisWAPTServerPostConf.FormCreate(Sender: TObject);
begin
  PagesControl.ShowTabs:=False;
  PagesControl.ActivePageIndex:=0;
end;

procedure TVisWAPTServerPostConf.FormShow(Sender: TObject);
begin
  EdWAPTServerName.Text:='srvwapt.'+GetDNSDomain;
  if IniHasKey(WaptIniFilename,'global','default_package_prefix') then
    EdDefaultPrefix.Text:=IniReadString(WaptIniFilename,'global','default_package_prefix');
  if IniHasKey(WaptIniFilename,'global','default_sources_root') then
    EdSourcesRoot.Text:=IniReadString(WaptIniFilename,'global','default_sources_root');
  if IniHasKey(WaptIniFilename,'global','templates_repo_url') then
    EdTemplatesRepoURL.Text:=IniReadString(WaptIniFilename,'global','templates_repo_url');
end;

procedure TVisWAPTServerPostConf.PagesControlChange(Sender: TObject);
var
  ini:TMemIniFile;

begin
  if PagesControl.ActivePage = pgFinish then
  try
    ini := TMemIniFile.Create(WaptIniFilename);
    ini.WriteString('global','repo_url',edWAPTRepoURL.Text);
    ini.WriteString('global','wapt_server',edWAPTServerURL.Text);
    ini.WriteString('global','private_key',EdPrivateKeyFN.Text);
    ini.WriteString('global','templates_repo_url','http://wapt.tranquil.it/wapt');
    ini.WriteString('global','default_sources_root','c:\waptdev');
    ini.WriteString('global','default_package_prefix','test');
    ini.WriteString('global','loglevel','warning');
    EdWaptInifile.Lines.Clear;
    ini.GetStrings(EdWaptInifile.Lines);
  finally
    ini.Free;
  end;
end;

procedure TVisWAPTServerPostConf.ActManualUpdate(Sender: TObject);
begin
  if not ActManual.Checked then
  begin
    edWAPTRepoURL.Enabled := False;
    edWAPTServerURL.Enabled := False;
    edWAPTRepoURL.Text := Format('http://%s:8080/wapt',[EdWAPTServerName.Text]);
    edWAPTServerURL.Text := Format('http://%s:8080',[EdWAPTServerName.Text]);
  end
  else
  begin
    edWAPTRepoURL.Enabled := True;
    edWAPTServerURL.Enabled := True;
  end;
end;

procedure TVisWAPTServerPostConf.ActNextExecute(Sender: TObject);
begin
  PagesControl.ActivePageIndex := PagesControl.ActivePageIndex + 1;
end;

procedure TVisWAPTServerPostConf.ActNextUpdate(Sender: TObject);
begin
  if PagesControl.ActivePage = pgParameters then
    ActNext.Enabled := EdWaptServerIP.Text<>''
  else if PagesControl.ActivePage = pgPassword then
    ActNext.Enabled := (EdPwd1.Text<>'') and (EdPwd1.Text = EdPwd2.Text)
  else if PagesControl.ActivePage = pgPassword then
    ActNext.Enabled := (EdPwd1.Text<>'') and (EdPwd1.Text = EdPwd2.Text)
  else
    ActNext.Enabled := PagesControl.ActivePageIndex<PagesControl.PageCount-1;
end;

procedure TVisWAPTServerPostConf.actPreviousExecute(Sender: TObject);
begin
  PagesControl.ActivePageIndex := PagesControl.ActivePageIndex - 1;
end;

procedure TVisWAPTServerPostConf.actPreviousUpdate(Sender: TObject);
begin
  actPrevious.Enabled:=PagesControl.ActivePageIndex>0;
end;

procedure TVisWAPTServerPostConf.actWriteConfStartServeExecute(Sender: TObject);
var
  ini:TMemIniFile;
  status:Integer;
begin
  try
    ini := TMemIniFile.Create(WaptIniFilename);
    ini.SetStrings(EdWaptInifile.Lines);
    ini.UpdateFile;
    RunTask('net stop waptserver',Status);
    RunTask('net start waptserver',Status);
    if status<>0 then
      ShowMessage('Impossible de démarrer le service waptserver');
    RunTask('net stop waptservice',Status);
    RunTask('net start waptservice',Status);
    if status<>0 then
      ShowMessage('Impossible de démarrer le service waptservice');

{    if GetServiceStatusByName('','waptserver') = ssRunning then
      StopServiceByName('', 'waptserver');
    if GetServiceStatusByName('','waptserver') = ssStopped then
      if not StartServiceByName('','waptserver') then
        ShowMessage('Impossible de démarrer le service waptserver');
    if GetServiceStatusByName('','waptservice') = ssRunning then
      StopServiceByName('', 'waptservice');
    if not StartServiceByName('','waptservice') then
      ShowMessage('Impossible de démarrer le service waptservice');
}
  finally
    ini.Free;
  end;
end;

procedure TVisWAPTServerPostConf.BitBtn3Click(Sender: TObject);
begin
  if MessageDlg('Confirmer','Voulez-vous vraiment annuler la post-configuration du serveur WAPT ?',mtConfirmation,mbYesNoCancel,0) = mrYes then
    Close;
end;

procedure TVisWAPTServerPostConf.ActManualExecute(Sender: TObject);
begin
  ActManual.Checked := not ActManual.Checked;
end;

procedure TVisWAPTServerPostConf.ActCreateKeyExecute(Sender: TObject);
begin
  EdPrivateKeyFN.Text := CreateSelfSignedCert( EdOrgName.Text,WaptBaseDir,DirectoryCert.Text,
    edCountry.Text,edLocality.Text,edOrganization.Text,edUnit.Text,edCommonName.Text,edEmail.Text);
end;

procedure TVisWAPTServerPostConf.ActCheckDNSExecute(Sender: TObject);
var
  cnames,ips : ISuperObject;
begin
  ips := Nil;
  cnames := DNSCNAMEQuery(EdWAPTServerName.Text);
  if (cnames<>Nil) and (cnames.AsArray.Length>0) then
    ips := DNSAQuery(cnames.AsArray[0].AsString)
  else
    ips := DNSAQuery(EdWAPTServerName.Text);

  if (ips<>Nil) and (ips.AsArray.Length>0) then
    EdWaptServerIP.text := ips.AsArray[0].AsString
  else
    EdWaptServerIP.text := '';

end;

procedure TVisWAPTServerPostConf.ActCreateKeyUpdate(Sender: TObject);
var
   TargetKeyFN:String;
begin
  TargetKeyFN := AppendPathDelim(DirectoryCert.Text)+EdOrgName.Text+'.pem';
  ActCreateKey.Enabled := (DirectoryCert.Text<>'') and (EdOrgName.Text<>'') and not FileExists(TargetKeyFN);
  if FileExists(TargetKeyFN) then
    EdPrivateKeyFN.Text := TargetKeyFN;
end;

function MakeIdent(st:String):String;
var
  i:integer;
begin
  result :='';
  for i := 1 to length(st) do
    if CharIsValidIdentifierLetter(st[i]) then
      result := Result+st[i];
end;

procedure TVisWAPTServerPostConf.EdOrgNameExit(Sender: TObject);
begin
  EdOrgName.Text:= MakeIdent(EdOrgName.Text);
end;

end.
