unit uVisImportPackage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Buttons, ComCtrls, StdCtrls, ActnList, Menus, sogrid, DefaultTranslator,
  uWaptConsoleRes, VirtualTrees, superobject,SearchEdit;

type

  { TVisImportPackage }

  TVisImportPackage = class(TForm)
    ActionList1: TActionList;
    ActionsImages: TImageList;
    ActPackageDuplicate: TAction;
    actRefresh: TAction;
    ActSearchExternalPackage: TAction;
    ActWAPTLocalConfig: TAction;
    BitBtn2: TBitBtn;
    ButExtRepoChange: TBitBtn;
    ButPackageDuplicate: TBitBtn;
    butSearchExternalPackages: TBitBtn;
    cbNewerThanMine: TCheckBox;
    cbNewestOnly: TCheckBox;
    EdSearch1: TSearchEdit;
    GridExternalPackages: TSOGrid;
    MenuItem25: TMenuItem;
    Panel1: TPanel;
    Panel8: TPanel;
    PopupMenuPackages: TPopupMenu;
    urlExternalRepo: TLabel;
    procedure ActPackageDuplicateExecute(Sender: TObject);
    procedure ActSearchExternalPackageExecute(Sender: TObject);
    procedure ActWAPTLocalConfigExecute(Sender: TObject);
    procedure ButExtRepoChangeClick(Sender: TObject);
    procedure cbNewerThanMineClick(Sender: TObject);
    procedure EdSearch1Execute(Sender: TObject);
    procedure EdSearch1KeyPress(Sender: TObject; var Key: char);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure GridExternalPackagesGetText(Sender: TBaseVirtualTree;
      Node: PVirtualNode; RowData, CellData: ISuperObject;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
  private
    function updateprogress(receiver: TObject; current, total: integer
      ): boolean;
    { private declarations }
  public
    { public declarations }
  end;

var
  VisImportPackage: TVisImportPackage;

implementation

uses uwaptconsole,tiscommon,soutils,waptcommon,
    dmwaptpython,uvisloading,uvisprivatekeyauth, uWaptRes,md5,uScaleDPI;

{$R *.lfm}

{ TVisImportPackage }

procedure TVisImportPackage.ButExtRepoChangeClick(Sender: TObject);
begin
  ActWAPTLocalConfigExecute(self);
  urlExternalRepo.Caption := format(rsUrl, [WaptTemplatesRepo]);
end;

procedure TVisImportPackage.cbNewerThanMineClick(Sender: TObject);
begin
  ActSearchExternalPackageExecute(Sender);
end;

procedure TVisImportPackage.EdSearch1Execute(Sender: TObject);
begin
  if EdSearch1.Modified then
    ActSearchExternalPackageExecute(Sender);
  EdSearch1.Modified:=False;
end;

procedure TVisImportPackage.EdSearch1KeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    EdSearch1.SelectAll;
    ActSearchExternalPackage.Execute;
  end;
end;

procedure TVisImportPackage.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  GridExternalPackages.SaveSettingsToIni(Appuserinipath) ;
end;

procedure TVisImportPackage.FormCreate(Sender: TObject);
begin
    ScaleDPI(Self,96); // 96 is the DPI you designed
    ScaleImageList(ActionsImages,96);

end;

procedure TVisImportPackage.FormShow(Sender: TObject);
begin
  GridExternalPackages.LoadSettingsFromIni(Appuserinipath) ;
  urlExternalRepo.Caption:=  WaptTemplatesRepo(AppIniFilename);
  ActSearchExternalPackage.Execute;
end;

procedure TVisImportPackage.GridExternalPackagesGetText(
  Sender: TBaseVirtualTree; Node: PVirtualNode; RowData,
  CellData: ISuperObject; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
begin
  if (CellText<>'') and  ( ((Sender as TSOGrid).Header.Columns[Column] as TSOGridColumn).PropertyName = 'size') then
  begin
    CellText := FormatFloat('# ##0 kB',StrToInt64(CellText) div 1024);
  end;
end;

procedure TVisImportPackage.ActWAPTLocalConfigExecute(Sender: TObject);
begin
  if (VisWaptGUI<>Nil) and  VisWaptGUI.EditIniFile then
  begin
    urlExternalRepo.Caption:=  WaptTemplatesRepo(AppIniFilename);
    GridExternalPackages.Clear;
    ActSearchExternalPackage.Execute;
  end;
end;

procedure TVisImportPackage.ActSearchExternalPackageExecute(Sender: TObject);
var
  expr: UTF8String;
  packages: ISuperObject;
  proxy:String;
begin
  EdSearch1.Modified:=False;
  if waptcommon.UseProxyForTemplates then
    proxy := '"'+waptcommon.HttpProxy+'"'
  else
    proxy := 'None';
  expr := format('waptdevutils.update_external_repo("%s","%s",proxy=%s,mywapt=mywapt,newer_only=%s,newest_only=%s)',
    [WaptTemplatesRepo(AppIniFilename) ,
      EdSearch1.Text, proxy,
      BoolToStr(cbNewerThanMine.Checked,'True','False'),
      BoolToStr(cbNewestOnly.Checked,'True','False')]);
  packages := DMPython.RunJSON(expr);
  GridExternalPackages.Data := packages;
end;

procedure TVisImportPackage.ActPackageDuplicateExecute(Sender: TObject);
var
  target,sourceDir: string;
  package,uploadResult, FileName, FileNames, listPackages,Sources,aDir: ISuperObject;

begin
  if not FileExists(GetWaptPrivateKeyPath) then
  begin
    ShowMessageFmt(rsPrivateKeyDoesntExist, [GetWaptPrivateKeyPath]);
    exit;
  end;

  if DefaultPackagePrefix='' then
  begin
    ShowMessage(rsWaptPackagePrefixMissing);
    ActWAPTLocalConfig.Execute;
    Exit;
  end;

  listPackages := TSuperObject.create(stArray);
  for package in GridExternalPackages.SelectedRows do
    listPackages.AsArray.Add(package.S['package']+'(='+package.S['version']+')');
  //calcule liste de tous les fichiers wapt + md5  nécessaires y compris les dépendances
  FileNames := DMPython.RunJSON(format('waptdevutils.get_packages_filenames(r"%s".decode(''utf8''),"%s")',
        [AppIniFilename,Join(',',listPackages)]));

  if MessageDlg(rsPackageDuplicateConfirmCaption, format(rsPackageDuplicateConfirm, [Join(',', listPackages)]),
        mtConfirmation, mbYesNoCancel, 0) <> mrYes then
    Exit;

  if not DirectoryExists(AppLocalDir + 'cache') then
    mkdir(AppLocalDir + 'cache');


  with  TVisLoading.Create(Self) do
  try
    Sources := TSuperObject.Create(stArray) ;
    //Téléchargement en batchs
    for Filename in FileNames do
    begin
      Application.ProcessMessages;
      ProgressTitle(
        format(rsDownloadingPackage, [Filename.AsArray[0].AsString]));
      target := AppLocalDir + 'cache\' + Filename.AsArray[0].AsString;
      try
        if not FileExists(target) or (MD5Print(MD5File(target)) <> Filename.AsArray[1].AsString) then
        begin
          IdWget(WaptTemplatesRepo(AppIniFilename) + '/' + Filename.AsArray[0].AsString,
            target, ProgressForm, @updateprogress, UseProxyForTemplates);
          if (MD5Print(MD5File(target)) <> Filename.AsArray[1].AsString) then
            raise Exception.CreateFmt(rsDownloadCurrupted,[Filename.AsArray[0].AsString]);
        end;
      except
        on e:Exception do
        begin
          ShowMessage(rsDlCanceled+' : '+e.Message);
          if FileExists(target) then
            DeleteFileUTF8(Target);
          exit;
        end;
      end;
    end;

    for Filename in FileNames do
    begin
      ProgressTitle(format(rsDuplicating, [Filename.AsArray[0].AsString]));
      Application.ProcessMessages;
      sourceDir := DMPython.RunJSON(
        Format('waptdevutils.duplicate_from_external_repo(r"%s",r"%s")',
        [AppIniFilename,AppLocalDir + 'cache\' + Filename.AsArray[0].AsString])).AsString;
      sources.AsArray.Add('r"'+sourceDir+'"');
    end;

    ProgressTitle(format(rsUploadingPackagesToWaptSrv, [IntToStr(Sources.AsArray.Length)]));
    Application.ProcessMessages;

    uploadResult := DMPython.RunJSON(
      format('mywapt.build_upload([%s],private_key_passwd=r"%s",wapt_server_user=r"%s",wapt_server_passwd=r"%s",inc_package_release=False)',
      [Join(',',sources) , privateKeyPassword, waptServerUser, waptServerPassword]),
      VisWaptGUI.jsonlog);
    if (uploadResult <> Nil) and (uploadResult.AsArray.length=Sources.AsArray.Length) then
    begin
      ShowMessage(format(rsDuplicateSuccess, [ Join(',', listPackages)])) ;
      ModalResult := mrOk;
    end
    else
      ShowMessage(rsDuplicateFailure);
  finally
    for aDir in Sources do
      DeleteDirectory(copy(aDir.AsString,3,length(aDir.AsString)-3),False);
    Free;
  end;
  ModalResult:=mrOK;
end;

function TVisImportPackage.updateprogress(receiver: TObject;
  current, total: integer): boolean;
begin
  if receiver <> nil then
    with (receiver as TVisLoading) do
    begin
      ProgressStep(current, total);
      Result := not StopRequired;
    end
  else
    Result := True;
end;



end.

