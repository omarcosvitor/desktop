unit fmLiturgia;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.Collections, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, BusinessSkinForm, bsSkinCtrls,
  Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Mask, bsSkinBoxCtrls,
  bsdbctrls, bsribbon, Data.DB, bsColorCtrls, StrUtils, ShellApi,
  Vcl.DBCtrls, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.Comp.DataSet, FireDAC.Comp.Client;

type
  //Uma linha da lista de vídeos do canal: dados do feed mais a miniatura já
  //decodificada (a lista é owner-draw, então a imagem fica pronta na memória)
  TItemVideoYt = class
  public
    VideoId: string;
    Titulo: string;
    Publicado: TDateTime;
    Miniatura: TBitmap;
    destructor Destroy; override;
  end;

  TfLiturgia = class(TForm)
    bsBusinessSkinForm1: TbsBusinessSkinForm;
    GridPanel2: TGridPanel;
    btAdd: TbsSkinButton;
    bsSkinPanel1: TbsSkinPanel;
    lblItem: TbsSkinLabel;
    txtItem: TbsSkinEdit;
    bsSkinLabel2: TbsSkinLabel;
    cbItens: TbsSkinComboBox;
    ScrollBox1: TScrollBox;
    dsHinos: TDataSource;
    qrHinos: TFDQuery;
    pnlHinos: TbsSkinPanel;
    bsRibbonDivider10: TbsRibbonDivider;
    bsSkinPanel2: TbsSkinPanel;
    opcHinosOpc1: TbsSkinRadioButton;
    pnlHinosOpc1: TbsSkinPanel;
    skLitLabel: TbsSkinStdLabel;
    bsSkinPanel4: TbsSkinPanel;
    dbLitHinoLista: TbsSkinDBLookupComboBox;
    csCor: TbsSkinColorButton;
    bsSkinLabel3: TbsSkinLabel;
    btDel: TbsSkinButton;
    pnlAnotacoes: TbsSkinPanel;
    bsRibbonDivider1: TbsRibbonDivider;
    bsSkinPanel6: TbsSkinPanel;
    bsSkinStdLabel1: TbsSkinStdLabel;
    pnlSite: TbsSkinPanel;
    bsSkinSpeedButton1: TbsSkinSpeedButton;
    edtAnotacao: TbsSkinEdit;
    bsRibbonDivider2: TbsRibbonDivider;
    bsSkinPanel3: TbsSkinPanel;
    bsSkinStdLabel2: TbsSkinStdLabel;
    urlSite: TbsSkinURLEdit;
    bsSkinSpeedButton2: TbsSkinSpeedButton;
    pnlArquivo: TbsSkinPanel;
    bsRibbonDivider3: TbsRibbonDivider;
    bsSkinPanel7: TbsSkinPanel;
    bsSkinStdLabel3: TbsSkinStdLabel;
    edtDiretorio: TbsSkinEdit;
    bsSkinSpeedButton3: TbsSkinSpeedButton;
    bsSkinSpeedButton4: TbsSkinSpeedButton;
    edtDiretorioInfo: TbsSkinEdit;
    pnlItensAgendados: TbsSkinPanel;
    bsRibbonDivider4: TbsRibbonDivider;
    bsSkinPanel8: TbsSkinPanel;
    bsSkinStdLabel4: TbsSkinStdLabel;
    dblItem: TDBLookupComboBox;
    bsSkinPanel5: TbsSkinPanel;
    procedure cbItensChange(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure executaOpcoes();
    procedure opcHinosOpc1Click(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure bsSkinSpeedButton1Click(Sender: TObject);
    procedure btAddClick(Sender: TObject);
    procedure btDelClick(Sender: TObject);
    procedure txtItemKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure bsSkinSpeedButton2Click(Sender: TObject);
    function validaURL(url: string): string;
    procedure urlSiteExit(Sender: TObject);
    procedure bsSkinSpeedButton4Click(Sender: TObject);
    procedure edtDiretorioEnter(Sender: TObject);
    procedure edtDiretorioExit(Sender: TObject);
    procedure bsSkinSpeedButton3Click(Sender: TObject);
  private
    { Private declarations }
    //Bloco de busca de vídeos por canal do YouTube. Criado em tempo de
    //execução (mesma abordagem de fmVideoOn) para não mexer no .dfm e não
    //exigir pacote instalado na IDE.
    pnlYt: TbsSkinPanel;
    pnlChipsYt: TbsSkinPanel;
    edtCanalYt: TbsSkinEdit;
    btBuscaYt: TbsSkinSpeedButton;
    lblStatusYt: TbsSkinStdLabel;
    lstVideosYt: TListBox;
    tmrAutoYt: TTimer;
    videosYt: TObjectList<TItemVideoYt>;
    canaisYt: TStringList;   // 'UCxxx=Nome', mais recente primeiro
    buscandoYt: Boolean;
    cancelaYt: Boolean;
    autoBuscaYt: Boolean;
    videoIdYt: string;
    tituloVideoYt: string;
    alturaFormBase: Integer;
    alturaSiteBase: Integer;

    procedure criaControlesYt;
    procedure montaChipsYt;
    procedure carregaCanaisYt;
    procedure salvaCanalYt(const CanalId, Nome: string);
    procedure buscaCanalYt(const Entrada: string);
    procedure carregaMiniaturasYt;
    procedure limpaVideosYt;
    procedure statusYt(const Msg: string);
    procedure ajustaLayoutSite;
    procedure btBuscaYtClick(Sender: TObject);
    procedure chipYtClick(Sender: TObject);
    procedure edtCanalYtKeyPress(Sender: TObject; var Key: Char);
    procedure lstVideosYtDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure lstVideosYtClick(Sender: TObject);
    procedure tmrAutoYtTimer(Sender: TObject);
  protected
    procedure DoClose(var Action: TCloseAction); override;
  public
    { Public declarations }
    id: string;
    arquivoInicial: string;
    destructor Destroy; override;
  end;

var
  fLiturgia: TfLiturgia;

implementation

{$R *.dfm}

uses fmMenu, fmBuscaMusica, dmComponentes, fmIniciando, uYoutubeRSS,
  System.Math, Vcl.Imaging.jpeg;

const
  //Miniatura 16:9 reduzida: o suficiente para reconhecer o vídeo sem pesar a
  //lista nem a rede
  YT_LARG_THUMB = 96;
  YT_ALT_THUMB  = 54;
  YT_ALT_ITEM   = 62;
  //Altura do bloco YouTube acrescentada ao painel de link externo e à janela
  YT_ALT_BLOCO  = 232;
  YT_MAX_CHIPS  = 8;

destructor TItemVideoYt.Destroy;
begin
  Miniatura.Free;
  inherited;
end;

procedure TfLiturgia.edtDiretorioEnter(Sender: TObject);
begin
  edtDiretorio.Text := fmIndex.verificaURL(edtDiretorio.Text, edtDiretorioInfo, true);
end;

procedure TfLiturgia.edtDiretorioExit(Sender: TObject);
begin
  edtDiretorio.Text := fmIndex.verificaURL(edtDiretorio.Text, edtDiretorioInfo, false);
  edtDiretorio.SelStart := Length(edtDiretorio.Text);
  edtDiretorio.Perform(EM_SCROLLCARET, 0, 0);
end;

procedure TfLiturgia.bsSkinSpeedButton1Click(Sender: TObject);
begin
  fIniciando.AppCreateForm(TfBuscaMusica, fBuscaMusica);
  fBuscaMusica.ShowModal;
  if (fBuscaMusica.id) > 0
    then dbLitHinoLista.KeyValue := fBuscaMusica.id;
end;

procedure TfLiturgia.bsSkinSpeedButton2Click(Sender: TObject);
begin
  urlSite.text := validaURL(urlSite.text);
  fmIndex.abrirArquivo(urlSite.Text);
end;

procedure TfLiturgia.bsSkinSpeedButton3Click(Sender: TObject);
var
  dir: string;
begin
  dir := fmIndex.openDialog('pasta', '', 'Liturgia',false,edtDiretorio.Text);
  if dir <> '' then edtDiretorio.Text := dir;
  edtDiretorioExit(Sender);
end;

procedure TfLiturgia.bsSkinSpeedButton4Click(Sender: TObject);
var
  arq: string;
begin
  arq := fmIndex.openDialog('arquivo', '', 'Liturgia',false,ExtractFilePath(edtDiretorio.Text));
  if arq <> '' then edtDiretorio.Text := arq;
  edtDiretorioExit(Sender);
end;

procedure TfLiturgia.btAddClick(Sender: TObject);
var
  semana: string;
  tipo: string;
  subitem: string;
  param: string;
  itens: array of TParamItem;

  procedure Add(const p, v: string);
  begin
    SetLength(itens, Length(itens)+1);
    itens[High(itens)].Grupo := id;
    itens[High(itens)].Param := p;
    itens[High(itens)].Valor := v;
  end;
begin
  if (cbItens.ItemIndex < 0) then
  begin
    application.MessageBox('Escolha o tipo de item!', fmIndex.titulo, mb_ok + MB_ICONEXCLAMATION);
    cbItens.SetFocus;
    Exit;
  end;

  if (txtItem.Visible) and (Trim(txtItem.Text) = '') then
  begin
    application.MessageBox('Defina o nome do item!', fmIndex.titulo, mb_ok + MB_ICONEXCLAMATION);
    txtItem.SetFocus;
    Exit;
  end;

  if (pnlItensAgendados.Visible) and (trim(dblItem.KeyValue) = '') then
  begin
    application.MessageBox('Escolha o item!', fmIndex.titulo, mb_ok + MB_ICONEXCLAMATION);
    dblItem.SetFocus;
    Exit;
  end;

  semana := fmIndex.loadCol.Strings.Values['LITURGIA:SEMANA'];

  if (Trim(id) = '') then
    id := 'item_'+FormatDateTime('yyyymmddhhnnsszzz', Now);

  tipo := '';
  case cbItens.ItemIndex of
    0: tipo := 'anotacao';
    1: tipo := 'arquivo';
    2: tipo := 'categoria';
    3: tipo := 'itensagendados';
    4: tipo := 'musica';
    5: tipo := 'site';
  end;

  Add('tipo', tipo);
  Add('item', txtItem.Text);
  Add('cor', ColorToString(csCor.ColorValue));

  try
    fmIndex.gravaLog('btAddClick: pre-build id=' + id + ' pnlArquivo=' + BoolToStr(pnlArquivo.Visible, True) + ' edtDiretorio=' + edtDiretorio.Text + ' edtDiretorioInfo=' + edtDiretorioInfo.Text);
  except
    // silencioso
  end;

  if (pnlAnotacoes.Visible) then
  begin
    Add('subitem', edtAnotacao.Text);
  end
  else
  if (pnlItensAgendados.Visible) then
  begin
    Add('item', dblItem.Text);
    Add('subitem', '');
    Add('id', dblItem.KeyValue);
  end
  else
  if (pnlSite.Visible) then
  begin
    urlSite.text := validaURL(urlSite.text);
    //Quando o vídeo veio da busca por canal, o card mostra o nome dele; link
    //colado à mão continua exibindo a URL, que é a única informação que existe
    if (Trim(tituloVideoYt) <> '') and (ytVideoIdDeUrl(urlSite.Text) = videoIdYt)
      then Add('subitem', tituloVideoYt)
      else Add('subitem', 'Site '+urlSite.Text);
    Add('url', urlSite.Text);
    Add('video_id', videoIdYt);
    Add('video_titulo', tituloVideoYt);
  end
  else
  if (pnlArquivo.Visible) then
  begin
    edtDiretorio.Text := trim(edtDiretorio.Text);
    if (edtDiretorioInfo.Text = 'I')
      then param := ExtractFilePath(Application.ExeName)+edtDiretorio.Text
      else param := edtDiretorio.Text;

    if (Copy(param,Length(param),1) = '\') then
    begin
      Add('subtipo', 'dir');
      Add('subitem', 'Pasta '+edtDiretorio.Text);
    end
    else if FileExists(param) then
    begin
      Add('subtipo', 'arq');
      Add('subitem', 'Arquivo '+edtDiretorio.Text);
    end
    else if DirectoryExists(param) then
    begin
      edtDiretorio.Text := edtDiretorio.Text+'\';
      Add('subtipo', 'dir');
      Add('subitem', 'Pasta '+edtDiretorio.Text);
    end
    else
    begin
      Add('subtipo', 'arq');
      Add('subitem', 'Arquivo '+edtDiretorio.Text);
    end;

    Add('dir', edtDiretorio.Text);
    Add('dir_info', edtDiretorioInfo.Text);
  end
  else
  if (pnlHinos.Visible) then
  begin
    if (dbLitHinoLista.KeyValue < 0)
      then opcHinosOpc1.Checked := true;

    if opcHinosOpc1.Checked then
    begin
      Add('escolha', '1');
      Add('musica', '-1');
      Add('subtipo', 'escolha');
      subitem := 'Clique para escolher a música';
      Add('subitem', subitem);
    end
    else
    begin
      Add('escolha', '0');
      Add('musica', IntToStr(dbLitHinoLista.KeyValue));
      if (qrHinos.FieldByName('TIPO_HASD').AsString = 'S')
        then Add('subtipo', 'hasd')
      else if (qrHinos.FieldByName('TIPO_JA').AsString = 'S')
        then Add('subtipo', 'ja')
      else Add('subtipo', 'div');

      if (qrHinos.FieldByName('TIPO_HASD').AsString = 'S')
        then subitem := 'Hino nº '
        else subitem := 'Música ';
      subitem := subitem + qrHinos.FieldByName('NOME').AsString;
      Add('subitem', subitem);
    end;
  end;

  fmIndex.gravaParamLote(fmIndex.arq_liturgia, itens);

  try
    fmIndex.gravaLog('btAddClick: salvando item ' + id + ' tipo=' + tipo);
  except
    // silencioso: log falhou -> continua
  end;

  if fmIndex.lbLiturgia.Items.IndexOf(id) < 0 then
  begin
    fmIndex.lbLiturgia.Items.Add(id);
    fmIndex.salvaItensLiturgia;
    fmIndex.carregaItemLiturgia(id,fmIndex.lbLiturgia.Items.Count);
  end
  else fmIndex.carregaItemLiturgia(id);

  close;
end;

procedure TfLiturgia.btDelClick(Sender: TObject);
begin
  if (application.MessageBox('Deseja realmente excluir este item?', fmIndex.titulo, mb_yesno + mb_iconquestion) <> 6) then Exit;
  fmIndex.apagaItemLiturgia(id);
  Close;
end;

procedure TfLiturgia.cbItensChange(Sender: TObject);
const
  IDX_ANOTACAO       = 0;
  IDX_ARQUIVO        = 1;
  IDX_ITENSAGENDADOS = 3;
  IDX_MUSICA         = 4;
  IDX_SITE           = 5;
var
  idx: Integer;
begin
  idx := cbItens.ItemIndex;

  pnlAnotacoes.Visible      := (idx = IDX_ANOTACAO);
  pnlArquivo.Visible        := (idx = IDX_ARQUIVO);
  pnlItensAgendados.Visible := (idx = IDX_ITENSAGENDADOS);
  pnlHinos.Visible          := (idx = IDX_MUSICA);
  pnlSite.Visible           := (idx = IDX_SITE);

  lblItem.Visible := not pnlItensAgendados.Visible;
  txtItem.Visible := not pnlItensAgendados.Visible;

  if pnlSite.Visible then criaControlesYt;
  ajustaLayoutSite;

  if idx < 0 then Exit;
  executaOpcoes;
end;

procedure TfLiturgia.executaOpcoes;
var
  item: string;
begin
  try
    if (pnlHinos.Visible) then
    begin
      opcHinosOpc1Click(nil);
      qrHinos.Close;
      qrHinos.Open;
    end
    else if pnlItensAgendados.Visible then
    begin
      item := '';
      if (dblItem.KeyValue <> null) then
        item := dblItem.KeyValue;
      if not DM.cdsCategoriasItensAgendados.Active then
      begin
        DM.cdsCategoriasItensAgendados.CreateDataSet;
        DM.cdsCategoriasItensAgendados.IndexName := '';
        DM.cdsCategoriasItensAgendados.IndexFieldNames := 'NOME';
        DM.cdsCategoriasItensAgendados.LogChanges := False;
      end;

      if (FileExists(fmIndex.dir_dados + 'itensAgendadosCategorias.xml')) then
        DM.cdsCategoriasItensAgendados.LoadFromFile(fmIndex.dir_dados + 'itensAgendadosCategorias.xml');
      DM.cdsCategoriasItensAgendados.Open;
      dblItem.KeyValue := item;
    end;
  except
    // Silencioso - erros em opções não devem quebrar a UI
  end;
end;

procedure TfLiturgia.FormActivate(Sender: TObject);
var
  tipo: string;
  idx: Integer;
  function FindIndexForTipo(const code: string): Integer;
  var
    i: Integer;
    c: string;
  begin
    Result := -1;
    if Trim(code) = '' then Exit;
    // try direct code-index mapping (legacy behavior)
    Result := AnsiIndexStr(code, ['anotacao','arquivo','categoria','itensagendados','musica','site']);
    if (Result >= 0) and (Result < cbItens.Items.Count) then Exit;

    // fallback: match by partial label (case-insensitive)
    for i := 0 to cbItens.Items.Count - 1 do
    begin
      c := cbItens.Items[i];
      if AnsiContainsText(c, 'Anot') and ((code = 'anotacao')) then
      begin
        Result := i; Exit;
      end;
      if (AnsiContainsText(c, 'Arquiv') or AnsiContainsText(c, 'Diretor') or AnsiContainsText(c, 'Diret')) and (code = 'arquivo') then
      begin
        Result := i; Exit;
      end;
      if AnsiContainsText(c, 'Categor') and (code = 'categoria') then
      begin
        Result := i; Exit;
      end;
      if (AnsiContainsText(c, 'Itens') or AnsiContainsText(c, 'Agend')) and (code = 'itensagendados') then
      begin
        Result := i; Exit;
      end;
      if (AnsiContainsText(c, 'Músic') or AnsiContainsText(c, 'Musica') or AnsiContainsText(c, 'Hino')) and (code = 'musica') then
      begin
        Result := i; Exit;
      end;
      if AnsiContainsText(c, 'Site') and (code = 'site') then
      begin
        Result := i; Exit;
      end;
    end;
  end;
begin
  pnlAnotacoes.Visible := False;
  pnlHinos.Visible := False;
  pnlSite.Visible := False;
  pnlArquivo.Visible := False;
  pnlItensAgendados.Visible := False;
  ScrollBox1.Visible := True;

  if (Trim(id) = '') then
  begin
    btAdd.Caption := ' Adicionar';
    btAdd.ImageIndex := 44;
    btDel.Visible := False;
  end
  else
  begin
    btAdd.Caption := ' Salvar';
    btAdd.ImageIndex := 2;
    btDel.Visible := True;
  end;

  try
    fmIndex.gravaLog('FormActivate: carrega item ' + id);
    tipo := fmIndex.lerParam(id, 'tipo', '', fmIndex.arq_liturgia);

    // Prefill simple controls that do not require datasets
    if tipo = 'anotacao' then
      edtAnotacao.Text := fmIndex.lerParam(id, 'subitem', '', fmIndex.arq_liturgia)
    else
      edtAnotacao.Text := '';

    if tipo = 'site' then
    begin
      urlSite.Text := fmIndex.lerParam(id, 'url', '', fmIndex.arq_liturgia);
      videoIdYt := fmIndex.lerParam(id, 'video_id', '', fmIndex.arq_liturgia);
      tituloVideoYt := fmIndex.lerParam(id, 'video_titulo', '', fmIndex.arq_liturgia);
    end
    else
    begin
      urlSite.Text := '';
      videoIdYt := '';
      tituloVideoYt := '';
    end;

    if tipo = 'arquivo' then
    begin
      edtDiretorio.Text := fmIndex.lerParam(id, 'dir', '', fmIndex.arq_liturgia);
      edtDiretorioInfo.Text := fmIndex.lerParam(id, 'dir_info', '', fmIndex.arq_liturgia);
      edtDiretorio.SelStart := Length(edtDiretorio.Text);
      edtDiretorio.Perform(EM_SCROLLCARET, 0, 0);
    end
    else
    begin
      edtDiretorio.Text := '';
      edtDiretorioInfo.Text := '';
    end;

      opcHinosOpc1.Checked := (fmIndex.lerParam(id, 'escolha', '0', fmIndex.arq_liturgia) = '1');
      txtItem.Text := fmIndex.lerParam(id, 'item', '', fmIndex.arq_liturgia);
      csCor.ColorValue := StringToColor(fmIndex.lerParam(id, 'cor', '$004F0000', fmIndex.arq_liturgia));

      // Map and set ItemIndex so cbItensChange opens datasets before KeyValue assignment
      try
        idx := FindIndexForTipo(tipo);
        if idx >= 0 then
          cbItens.ItemIndex := idx
        else
        begin
          cbItens.ItemIndex := -1;
          fmIndex.gravaLog('FormActivate: tipo desconhecido para item ' + id + ' -> "' + tipo + '"');
        end;
      except
        cbItens.ItemIndex := -1;
        fmIndex.gravaLog('FormActivate: erro ao mapear tipo para item ' + id);
      end;

    // Ensure datasets and lookup lists are initialized
    cbItensChange(Sender);

    // Now safe to assign DB lookup KeyValues
    if tipo = 'itensagendados' then
      dblItem.KeyValue := fmIndex.lerParam(id, 'id', '', fmIndex.arq_liturgia)
    else
      dblItem.KeyValue := '';

    dbLitHinoLista.KeyValue := fmIndex.lerParam(id, 'musica', '-1', fmIndex.arq_liturgia);

  except
    cbItens.ItemIndex := -1;
    try fmIndex.gravaLog('FormActivate: excecao ao carregar item ' + id); except end;
  end;

  // Pré-preenchimento via drag-and-drop de arquivo na liturgia
  if (Trim(arquivoInicial) <> '') and (Trim(id) = '') then
  begin
    cbItens.ItemIndex := 1; // Arquivo
    cbItensChange(nil);
    edtDiretorio.Text := arquivoInicial;
    edtDiretorioExit(nil);
    arquivoInicial := '';
    if txtItem.CanFocus then txtItem.SetFocus;
  end;
end;

procedure TfLiturgia.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fmIndex.FormKeyUp(Sender, Key, Shift);
end;

procedure TfLiturgia.opcHinosOpc1Click(Sender: TObject);
begin
  pnlHinosOpc1.Visible := not opcHinosOpc1.Checked;
end;

procedure TfLiturgia.txtItemKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fmIndex.edtKeyUp(Sender,Key,Shift);
end;

procedure TfLiturgia.urlSiteExit(Sender: TObject);
begin
  urlSite.text := validaURL(urlSite.text);
  //URL trocada à mão invalida o título capturado do feed
  if (videoIdYt <> '') and (ytVideoIdDeUrl(urlSite.Text) <> videoIdYt) then
  begin
    videoIdYt := '';
    tituloVideoYt := '';
  end;
end;

function TfLiturgia.validaURL(url: string): string;
begin
  if (Copy(url,1,7) <> 'http://') and
     (Copy(url,1,8) <> 'https://') and
     (Copy(url,1,6) <> 'ftp://')
    then url := 'http://'+url;

  Result := url;
end;

{ ---------------------------------------------------------------------------
  Busca de vídeos por canal do YouTube (feed RSS público)
  --------------------------------------------------------------------------- }

procedure TfLiturgia.criaControlesYt;
var
  pnlLinha: TbsSkinPanel;
  lbl: TbsSkinStdLabel;
begin
  if Assigned(pnlYt) then Exit;

  videosYt := TObjectList<TItemVideoYt>.Create(True);
  canaisYt := TStringList.Create;

  //A altura do painel de link externo passa a ser calculada aqui: com o bloco
  //novo o AutoSize herdado do .dfm deixaria a janela sem espaço para a lista
  alturaSiteBase := pnlSite.Height;
  pnlSite.AutoSize := False;

  pnlYt := TbsSkinPanel.Create(Self);
  pnlYt.Parent := pnlSite;
  pnlYt.SkinData := DM.bsSkinData1;
  pnlYt.SkinDataName := 'panel';
  pnlYt.Caption := '';
  pnlYt.Top := pnlSite.Height;  // garante que entra abaixo do campo de URL
  pnlYt.Height := YT_ALT_BLOCO;
  pnlYt.Align := alTop;

  pnlLinha := TbsSkinPanel.Create(Self);
  pnlLinha.Parent := pnlYt;
  pnlLinha.SkinData := DM.bsSkinData1;
  pnlLinha.SkinDataName := 'panel';
  pnlLinha.Caption := '';
  pnlLinha.Height := 29;
  pnlLinha.Align := alTop;

  lbl := TbsSkinStdLabel.Create(Self);
  lbl.Parent := pnlLinha;
  lbl.SkinData := DM.bsSkinData1;
  lbl.SkinDataName := 'stdlabel';
  lbl.AutoSize := False;
  lbl.Caption := 'Canal:';
  lbl.Layout := tlCenter;
  lbl.Width := 45;
  lbl.AlignWithMargins := True;
  lbl.Margins.Left := 10;
  lbl.Align := alLeft;

  btBuscaYt := TbsSkinSpeedButton.Create(Self);
  btBuscaYt.Parent := pnlLinha;
  btBuscaYt.SkinData := DM.bsSkinData1;
  btBuscaYt.SkinDataName := 'toolbutton';
  btBuscaYt.Caption := ' Buscar';
  btBuscaYt.ShowCaption := True;
  btBuscaYt.Width := 95;
  btBuscaYt.AlignWithMargins := True;
  btBuscaYt.Margins.Right := 10;
  btBuscaYt.Align := alRight;
  btBuscaYt.OnClick := btBuscaYtClick;

  edtCanalYt := TbsSkinEdit.Create(Self);
  edtCanalYt.Parent := pnlLinha;
  edtCanalYt.SkinData := DM.bsSkinData1;
  edtCanalYt.SkinDataName := 'edit';
  edtCanalYt.AlignWithMargins := True;
  edtCanalYt.Margins.Top := 5;
  edtCanalYt.Margins.Bottom := 5;
  edtCanalYt.Align := alClient;
  edtCanalYt.Hint := 'Aceita @handle, link do canal ou ID (UC...)';
  edtCanalYt.ShowHint := True;
  edtCanalYt.OnKeyPress := edtCanalYtKeyPress;

  pnlChipsYt := TbsSkinPanel.Create(Self);
  pnlChipsYt.Parent := pnlYt;
  pnlChipsYt.SkinData := DM.bsSkinData1;
  pnlChipsYt.SkinDataName := 'panel';
  pnlChipsYt.Caption := '';
  pnlChipsYt.Height := 27;
  pnlChipsYt.Align := alTop;

  lblStatusYt := TbsSkinStdLabel.Create(Self);
  lblStatusYt.Parent := pnlYt;
  lblStatusYt.SkinData := DM.bsSkinData1;
  lblStatusYt.SkinDataName := 'stdlabel';
  lblStatusYt.AutoSize := False;
  lblStatusYt.Caption := '';
  lblStatusYt.Layout := tlCenter;
  lblStatusYt.Height := 18;
  lblStatusYt.AlignWithMargins := True;
  lblStatusYt.Margins.Left := 10;
  lblStatusYt.Margins.Top := 0;
  lblStatusYt.Margins.Bottom := 0;
  lblStatusYt.Align := alTop;

  lstVideosYt := TListBox.Create(Self);
  lstVideosYt.Parent := pnlYt;
  lstVideosYt.Style := lbOwnerDrawFixed;
  lstVideosYt.ItemHeight := YT_ALT_ITEM;
  lstVideosYt.AlignWithMargins := True;
  lstVideosYt.Margins.Left := 10;
  lstVideosYt.Margins.Right := 10;
  lstVideosYt.Margins.Bottom := 6;
  lstVideosYt.Align := alClient;
  lstVideosYt.OnDrawItem := lstVideosYtDrawItem;
  lstVideosYt.OnClick := lstVideosYtClick;

  //A busca no canal salvo só dispara depois que a janela aparece: fazê-la
  //dentro do OnActivate deixaria o formulário em branco durante a rede
  tmrAutoYt := TTimer.Create(Self);
  tmrAutoYt.Enabled := False;
  tmrAutoYt.Interval := 300;
  tmrAutoYt.OnTimer := tmrAutoYtTimer;

  carregaCanaisYt;
  montaChipsYt;
end;

procedure TfLiturgia.carregaCanaisYt;
var
  partes: TArray<string>;
  i: Integer;
  ultimo: string;
begin
  canaisYt.Clear;
  //Lista curta: 'UCxxx=Nome' separados por '|' num único parâmetro do config
  partes := SplitString(fmIndex.lerParam('Liturgia', 'CanaisYoutube', ''), '|');
  for i := 0 to High(partes) do
    if Trim(partes[i]) <> '' then
      canaisYt.Add(Trim(partes[i]));

  ultimo := fmIndex.lerParam('Liturgia', 'CanalYoutubeUltimo', '');
  if (Trim(ultimo) = '') and (canaisYt.Count > 0) then
    ultimo := canaisYt.Names[0];
  edtCanalYt.Text := ultimo;
end;

procedure TfLiturgia.salvaCanalYt(const CanalId, Nome: string);
var
  i: Integer;
  nome_limpo, lista: string;
begin
  if Trim(CanalId) = '' then Exit;

  //'|' é o separador da lista e '=' separa id do nome: nome não pode contê-los
  nome_limpo := Trim(StringReplace(Nome, '|', '/', [rfReplaceAll]));
  nome_limpo := Trim(StringReplace(nome_limpo, '=', '-', [rfReplaceAll]));
  if nome_limpo = '' then nome_limpo := CanalId;

  for i := canaisYt.Count - 1 downto 0 do
    if SameText(canaisYt.Names[i], CanalId) then canaisYt.Delete(i);

  canaisYt.Insert(0, CanalId + '=' + nome_limpo);
  while canaisYt.Count > YT_MAX_CHIPS do
    canaisYt.Delete(canaisYt.Count - 1);

  lista := '';
  for i := 0 to canaisYt.Count - 1 do
  begin
    if lista <> '' then lista := lista + '|';
    lista := lista + canaisYt[i];
  end;

  fmIndex.gravaParam('Liturgia', 'CanaisYoutube', lista);
  fmIndex.gravaParam('Liturgia', 'CanalYoutubeUltimo', CanalId);
  montaChipsYt;
end;

procedure TfLiturgia.montaChipsYt;
var
  i, esq: Integer;
  chip: TbsSkinSpeedButton;
  nome: string;
begin
  if not Assigned(pnlChipsYt) then Exit;

  for i := pnlChipsYt.ControlCount - 1 downto 0 do
    pnlChipsYt.Controls[i].Free;

  esq := 10;
  for i := 0 to canaisYt.Count - 1 do
  begin
    nome := canaisYt.ValueFromIndex[i];
    if Trim(nome) = '' then nome := canaisYt.Names[i];
    chip := TbsSkinSpeedButton.Create(Self);
    chip.Parent := pnlChipsYt;
    chip.SkinData := DM.bsSkinData1;
    chip.SkinDataName := 'toolbutton';
    chip.Caption := ' ' + nome + ' ';
    chip.ShowCaption := True;
    chip.Hint := canaisYt.Names[i];
    chip.ShowHint := True;
    chip.Tag := i;
    chip.Height := 21;
    chip.Top := 3;
    chip.Left := esq;
    chip.Width := Canvas.TextWidth(chip.Caption) + 20;
    chip.OnClick := chipYtClick;

    Inc(esq, chip.Width + 6);
    //Sem quebra de linha: o excesso fica fora da faixa em vez de empurrar a lista
    if esq > pnlChipsYt.Width - 10 then Break;
  end;

  pnlChipsYt.Visible := canaisYt.Count > 0;
end;

procedure TfLiturgia.statusYt(const Msg: string);
begin
  if not Assigned(lblStatusYt) then Exit;
  lblStatusYt.Caption := Msg;
  lblStatusYt.Update;
end;

procedure TfLiturgia.limpaVideosYt;
begin
  if Assigned(lstVideosYt) then lstVideosYt.Items.Clear;
  if Assigned(videosYt) then videosYt.Clear;
end;

procedure TfLiturgia.buscaCanalYt(const Entrada: string);
var
  canal_id, canal_nome: string;
  videos: TYoutubeVideos;
  item: TItemVideoYt;
  i: Integer;
begin
  if buscandoYt or not Assigned(lstVideosYt) then Exit;

  if Trim(Entrada) = '' then
  begin
    statusYt('Informe o canal: @handle, link do canal ou ID (UC...).');
    Exit;
  end;

  buscandoYt := True;
  cancelaYt := False;
  btBuscaYt.Enabled := False;
  Screen.Cursor := crHourGlass;
  try
    limpaVideosYt;
    statusYt('Procurando o canal...');
    Application.ProcessMessages;

    if not ytResolveCanal(Trim(Entrada), canal_id) then
    begin
      statusYt('Canal não encontrado. Confira o @handle, o link ou o ID.');
      Exit;
    end;

    statusYt('Lendo os vídeos do canal...');
    Application.ProcessMessages;

    if not ytBuscaVideos(canal_id, YT_MAX_VIDEOS, videos, canal_nome) then
    begin
      statusYt('Não foi possível ler os vídeos deste canal.');
      Exit;
    end;

    for i := 0 to High(videos) do
    begin
      item := TItemVideoYt.Create;
      item.VideoId := videos[i].VideoId;
      item.Titulo := videos[i].Titulo;
      item.Publicado := videos[i].Publicado;
      videosYt.Add(item);
      lstVideosYt.Items.AddObject(item.Titulo, item);
    end;

    if Trim(canal_nome) = '' then canal_nome := canal_id;
    statusYt(canal_nome + ' - ' + IntToStr(lstVideosYt.Items.Count) +
             ' vídeo(s). Clique para usar.');
    salvaCanalYt(canal_id, canal_nome);
    carregaMiniaturasYt;
  finally
    Screen.Cursor := crDefault;
    if Assigned(btBuscaYt) then btBuscaYt.Enabled := True;
    buscandoYt := False;
  end;
end;

procedure TfLiturgia.carregaMiniaturasYt;
var
  i: Integer;
  ms: TMemoryStream;
  jpg: TJPEGImage;
  item: TItemVideoYt;
begin
  //Miniaturas entram uma a uma, depois da lista já montada: a janela continua
  //utilizável enquanto as imagens chegam
  for i := 0 to videosYt.Count - 1 do
  begin
    if cancelaYt then Exit;
    item := videosYt[i];
    if Assigned(item.Miniatura) then Continue;

    ms := TMemoryStream.Create;
    try
      try
        if ytBaixaBinario(ytThumbUrl(item.VideoId), ms) and (ms.Size > 0) then
        begin
          ms.Position := 0;
          jpg := TJPEGImage.Create;
          try
            jpg.LoadFromStream(ms);
            item.Miniatura := TBitmap.Create;
            item.Miniatura.PixelFormat := pf24bit;
            item.Miniatura.SetSize(YT_LARG_THUMB, YT_ALT_THUMB);
            item.Miniatura.Canvas.StretchDraw(
              Rect(0, 0, YT_LARG_THUMB, YT_ALT_THUMB), jpg);
          finally
            jpg.Free;
          end;
        end;
      except
        //Miniatura é enfeite: falha nela não interrompe a lista
        FreeAndNil(item.Miniatura);
      end;
    finally
      ms.Free;
    end;

    if cancelaYt then Exit;
    lstVideosYt.Invalidate;
    Application.ProcessMessages;
  end;
end;

procedure TfLiturgia.lstVideosYtDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  cv: TCanvas;
  item: TItemVideoYt;
  r_thumb, r_texto: TRect;
  data: string;
begin
  cv := lstVideosYt.Canvas;
  if odSelected in State
    then cv.Brush.Color := clHighlight
    else cv.Brush.Color := lstVideosYt.Color;
  cv.FillRect(ARect);

  if (Index < 0) or (Index >= lstVideosYt.Items.Count) then Exit;
  item := TItemVideoYt(lstVideosYt.Items.Objects[Index]);
  if item = nil then Exit;

  r_thumb := Rect(ARect.Left + 4, ARect.Top + 4,
                  ARect.Left + 4 + YT_LARG_THUMB, ARect.Top + 4 + YT_ALT_THUMB);
  if Assigned(item.Miniatura) then
    cv.StretchDraw(r_thumb, item.Miniatura)
  else
  begin
    cv.Brush.Color := clBtnFace;
    cv.FillRect(r_thumb);
  end;

  cv.Brush.Style := bsClear;
  if odSelected in State
    then cv.Font.Color := clHighlightText
    else cv.Font.Color := clWindowText;

  cv.Font.Style := [fsBold];
  r_texto := Rect(r_thumb.Right + 8, ARect.Top + 4, ARect.Right - 4, ARect.Top + 38);
  DrawText(cv.Handle, PChar(item.Titulo), -1, r_texto,
           DT_LEFT or DT_WORDBREAK or DT_END_ELLIPSIS or DT_NOPREFIX);

  cv.Font.Style := [];
  if not (odSelected in State) then cv.Font.Color := clGrayText;
  if item.Publicado > 0
    then data := FormatDateTime('dd/mm/yyyy hh:nn', item.Publicado)
    else data := '';
  r_texto := Rect(r_thumb.Right + 8, ARect.Bottom - 20, ARect.Right - 4, ARect.Bottom - 4);
  DrawText(cv.Handle, PChar(data), -1, r_texto,
           DT_LEFT or DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX);

  cv.Brush.Style := bsSolid;
end;

procedure TfLiturgia.lstVideosYtClick(Sender: TObject);
var
  item: TItemVideoYt;
begin
  if lstVideosYt.ItemIndex < 0 then Exit;
  item := TItemVideoYt(lstVideosYt.Items.Objects[lstVideosYt.ItemIndex]);
  if item = nil then Exit;

  videoIdYt := item.VideoId;
  tituloVideoYt := item.Titulo;
  urlSite.Text := ytUrlVideo(item.VideoId);
  txtItem.Text := item.Titulo;
  statusYt('Vídeo escolhido: ' + item.Titulo);
end;

procedure TfLiturgia.btBuscaYtClick(Sender: TObject);
begin
  autoBuscaYt := True;
  buscaCanalYt(edtCanalYt.Text);
end;

procedure TfLiturgia.chipYtClick(Sender: TObject);
var
  i: Integer;
begin
  i := TComponent(Sender).Tag;
  if (i < 0) or (i >= canaisYt.Count) then Exit;
  edtCanalYt.Text := canaisYt.Names[i];
  autoBuscaYt := True;
  //A busca refaz a faixa de chips, o que destruiria este botão ainda dentro do
  //clique dele: por isso ela sai da pilha do evento
  tmrAutoYt.Enabled := True;
end;

procedure TfLiturgia.edtCanalYtKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;  // evita o beep do edit
    btBuscaYtClick(Sender);
  end;
end;

procedure TfLiturgia.tmrAutoYtTimer(Sender: TObject);
begin
  tmrAutoYt.Enabled := False;
  if not pnlSite.Visible then Exit;

  if buscandoYt then
  begin
    //Busca anterior ainda baixando miniaturas: interrompe e tenta de novo
    cancelaYt := True;
    tmrAutoYt.Enabled := True;
    Exit;
  end;

  buscaCanalYt(edtCanalYt.Text);
end;

procedure TfLiturgia.ajustaLayoutSite;
begin
  if alturaFormBase = 0 then alturaFormBase := ClientHeight;

  if pnlSite.Visible and Assigned(pnlYt) then
  begin
    pnlSite.Height := alturaSiteBase + YT_ALT_BLOCO;
    ClientHeight := alturaFormBase + YT_ALT_BLOCO;

    //A janela cresce para baixo: sem isso ela sai da área útil da tela
    if Top + Height > Screen.WorkAreaRect.Bottom then
      Top := Max(Screen.WorkAreaRect.Top, Screen.WorkAreaRect.Bottom - Height);

    //Uma única tentativa automática por abertura, no último canal usado
    if (not autoBuscaYt) and (not buscandoYt) and
       (lstVideosYt.Items.Count = 0) and (Trim(edtCanalYt.Text) <> '') then
    begin
      autoBuscaYt := True;
      tmrAutoYt.Enabled := True;
    end;
  end
  else
  begin
    if Assigned(pnlYt) then pnlSite.Height := alturaSiteBase;
    ClientHeight := alturaFormBase;
  end;
end;

procedure TfLiturgia.DoClose(var Action: TCloseAction);
begin
  //Interrompe o download de miniaturas em andamento
  cancelaYt := True;
  inherited;
end;

destructor TfLiturgia.Destroy;
begin
  cancelaYt := True;
  FreeAndNil(videosYt);
  FreeAndNil(canaisYt);
  inherited;
end;

end.
