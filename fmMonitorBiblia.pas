unit fmMonitorBiblia;

{
  Projeção da Bíblia no segundo monitor.

  O texto deixou de ser desenhado por TLabel: label não tem como ser animado -
  o GDI não mistura transparência em texto de controle, e reposicionar por
  AutoSize pisca a cada troca de versículo. No lugar entrou uma superfície
  própria com buffer duplo, que monta cada quadro em três camadas:

    fundo (cor do painel + imagem) -> versículo que sai -> versículo que entra

  As duas camadas de texto são misturadas por AlphaBlend numa faixa do tamanho
  do texto, e não na tela inteira: assim a transição custa poucos
  milissegundos por quadro mesmo em 1080p.

  Os TLabel continuam na janela, invisíveis, porque é neles que a janela
  principal grava fonte, cor e tamanho vindos da configuração - o desenho lê
  dali. O mesmo vale para o TImage do fundo, que continua sendo posicionado
  por ajustaImagem.
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TfMonitorBiblia = class(TForm)
    pnlBiblia: TPanel;
    imgBiblia: TImage;
    lmdBibliaTxt: TLabel;
    lmdBibliaInfo: TLabel;
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    { Private declarations }
    pbTexto: TPaintBox;
    tmrAnim: TTimer;

    bmpFundo: TBitmap;    //cor do painel + imagem, sem texto
    bmpQuadro: TBitmap;   //quadro montado, entregue de uma vez à tela
    bmpFaixa: TBitmap;    //faixa do texto durante a mistura

    fundoValido: Boolean;
    corFundo: TColor;

    textoAtual, infoAtual: string;
    textoAnterior, infoAnterior: string;

    animando: Boolean;
    animInicio: Cardinal;
    animDuracao: Cardinal;
    animTipo: Integer;    //0 nenhuma, 1 suave, 2 deslizar

    procedure criaSuperficie;
    procedure montaFundo;
    procedure pbTextoPaint(Sender: TObject);
    procedure tmrAnimTimer(Sender: TObject);
    procedure calculaLayout(cv: TCanvas; const Texto, Info: string;
      out rTexto, rInfo: TRect);
    procedure escreveCamada(cv: TCanvas; const Texto, Info: string;
      const rTexto, rInfo: TRect);
    procedure desenhaCamada(alvo: TBitmap; const Texto, Info: string;
      dy: Integer; alfa: Byte);
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { Public declarations }
    //Troca o texto projetado, animando a saída do anterior e a entrada do novo
    procedure defineTexto(const Texto, Info: string);
    //Cor ou imagem de fundo mudaram: o fundo é refeito no próximo quadro
    procedure invalidaFundo;
  end;

var
  fMonitorBiblia: TfMonitorBiblia;

implementation

{$R *.dfm}

uses fmMenu, System.Math;

const
  //Quadro a cada 15 ms; o avanço da animação é medido por relógio, então
  //máquina lenta perde quadros mas não estica a duração
  INTERVALO_QUADRO = 15;
  //Limites da duração configurável, em milissegundos
  DUR_MIN = 80;
  DUR_MAX = 2000;
  //Deslocamento vertical do modo "deslizar", em fração da altura da tela
  DESLOC_FRACAO = 0.06;
  //Margem lateral do texto, igual à que o ajuste por AutoSize usava
  MARGEM = 10;

{ TfMonitorBiblia }

procedure TfMonitorBiblia.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if (fmIndex.ckMesmaJanela.checked = true) then Exit;
  Params.WndParent := 0;
end;

procedure TfMonitorBiblia.FormCreate(Sender: TObject);
begin
  criaSuperficie;
end;

procedure TfMonitorBiblia.criaSuperficie;
begin
  bmpFundo := TBitmap.Create;
  bmpFundo.PixelFormat := pf24bit;
  bmpQuadro := TBitmap.Create;
  bmpQuadro.PixelFormat := pf24bit;
  bmpFaixa := TBitmap.Create;
  bmpFaixa.PixelFormat := pf24bit;

  //O desenho passa a ser todo da superfície: os controles continuam existindo
  //só como portadores da configuração
  lmdBibliaTxt.Visible := False;
  lmdBibliaInfo.Visible := False;
  imgBiblia.Visible := False;

  pbTexto := TPaintBox.Create(Self);
  pbTexto.Parent := pnlBiblia;
  pbTexto.Align := alClient;
  pbTexto.OnPaint := pbTextoPaint;

  tmrAnim := TTimer.Create(Self);
  tmrAnim.Enabled := False;
  tmrAnim.Interval := INTERVALO_QUADRO;
  tmrAnim.OnTimer := tmrAnimTimer;

  fundoValido := False;
end;

procedure TfMonitorBiblia.FormDestroy(Sender: TObject);
begin
  FreeAndNil(bmpFundo);
  FreeAndNil(bmpQuadro);
  FreeAndNil(bmpFaixa);
end;

procedure TfMonitorBiblia.FormResize(Sender: TObject);
begin
  invalidaFundo;
end;

procedure TfMonitorBiblia.invalidaFundo;
begin
  fundoValido := False;
  if Assigned(pbTexto) then pbTexto.Invalidate;
end;

procedure TfMonitorBiblia.montaFundo;
var
  cv: TCanvas;
begin
  bmpFundo.SetSize(Max(1, pnlBiblia.ClientWidth), Max(1, pnlBiblia.ClientHeight));
  cv := bmpFundo.Canvas;

  corFundo := pnlBiblia.Color;
  cv.Brush.Color := corFundo;
  cv.Brush.Style := bsSolid;
  cv.FillRect(Rect(0, 0, bmpFundo.Width, bmpFundo.Height));

  //A imagem continua posicionada por ajustaImagem, na janela principal: aqui
  //só se aproveita o retângulo que ela calculou
  if Assigned(imgBiblia.Picture.Graphic) and
     (not imgBiblia.Picture.Graphic.Empty) then
    cv.StretchDraw(imgBiblia.BoundsRect, imgBiblia.Picture.Graphic);

  fundoValido := True;
end;

procedure TfMonitorBiblia.calculaLayout(cv: TCanvas; const Texto, Info: string;
  out rTexto, rInfo: TRect);
var
  larg, topo, altTexto, altInfo: Integer;
  r: TRect;
begin
  larg := Max(1, bmpQuadro.Width - (MARGEM * 2));

  altTexto := 0;
  if Trim(Texto) <> '' then
  begin
    cv.Font := lmdBibliaTxt.Font;
    r := Rect(0, 0, larg, 0);
    Winapi.Windows.DrawText(cv.Handle, PChar(Texto), Length(Texto), r,
      DT_CALCRECT or DT_WORDBREAK or DT_CENTER or DT_NOPREFIX);
    altTexto := r.Bottom - r.Top;
  end;

  //Bloco do versículo centralizado na tela, como antes
  topo := (bmpQuadro.Height - altTexto) div 2;
  rTexto := Rect(MARGEM, topo, MARGEM + larg, topo + altTexto);

  altInfo := 0;
  if Trim(Info) <> '' then
  begin
    cv.Font := lmdBibliaInfo.Font;
    r := Rect(0, 0, larg, 0);
    Winapi.Windows.DrawText(cv.Handle, PChar(Info), Length(Info), r,
      DT_CALCRECT or DT_WORDBREAK or DT_RIGHT or DT_NOPREFIX);
    altInfo := r.Bottom - r.Top;
  end;

  //Referência da passagem logo abaixo do texto, alinhada à direita
  rInfo := Rect(MARGEM, rTexto.Bottom, bmpQuadro.Width - MARGEM,
                rTexto.Bottom + altInfo);
end;

procedure TfMonitorBiblia.escreveCamada(cv: TCanvas; const Texto, Info: string;
  const rTexto, rInfo: TRect);
var
  r: TRect;
begin
  SetBkMode(cv.Handle, TRANSPARENT);

  if Trim(Texto) <> '' then
  begin
    cv.Font := lmdBibliaTxt.Font;
    r := rTexto;
    Winapi.Windows.DrawText(cv.Handle, PChar(Texto), Length(Texto), r,
      DT_WORDBREAK or DT_CENTER or DT_NOPREFIX);
  end;

  if Trim(Info) <> '' then
  begin
    cv.Font := lmdBibliaInfo.Font;
    r := rInfo;
    Winapi.Windows.DrawText(cv.Handle, PChar(Info), Length(Info), r,
      DT_WORDBREAK or DT_RIGHT or DT_NOPREFIX);
  end;
end;

procedure TfMonitorBiblia.desenhaCamada(alvo: TBitmap; const Texto, Info: string;
  dy: Integer; alfa: Byte);
var
  rTexto, rInfo, faixa: TRect;
  mistura: TBlendFunction;
begin
  if (alfa = 0) or ((Trim(Texto) = '') and (Trim(Info) = '')) then Exit;

  calculaLayout(alvo.Canvas, Texto, Info, rTexto, rInfo);
  OffsetRect(rTexto, 0, dy);
  OffsetRect(rInfo, 0, dy);

  //Opaco não precisa de mistura: escreve direto e sai
  if alfa >= 250 then
  begin
    escreveCamada(alvo.Canvas, Texto, Info, rTexto, rInfo);
    Exit;
  end;

  //Só a faixa ocupada pelo texto é misturada, e não a tela inteira
  faixa := Rect(0, Min(rTexto.Top, rInfo.Top), alvo.Width,
                Max(rTexto.Bottom, rInfo.Bottom));
  faixa.Top := Max(0, faixa.Top);
  faixa.Bottom := Min(alvo.Height, faixa.Bottom);
  if (faixa.Bottom - faixa.Top) <= 0 then Exit;

  bmpFaixa.SetSize(faixa.Right - faixa.Left, faixa.Bottom - faixa.Top);
  //A faixa parte do que já está montado no quadro: o texto é escrito sobre o
  //fundo verdadeiro, e a mistura não deixa halo
  BitBlt(bmpFaixa.Canvas.Handle, 0, 0, bmpFaixa.Width, bmpFaixa.Height,
         alvo.Canvas.Handle, faixa.Left, faixa.Top, SRCCOPY);

  OffsetRect(rTexto, -faixa.Left, -faixa.Top);
  OffsetRect(rInfo, -faixa.Left, -faixa.Top);
  escreveCamada(bmpFaixa.Canvas, Texto, Info, rTexto, rInfo);

  mistura.BlendOp := AC_SRC_OVER;
  mistura.BlendFlags := 0;
  mistura.SourceConstantAlpha := alfa;
  mistura.AlphaFormat := 0;

  //Qualificado: TForm também tem uma propriedade AlphaBlend
  Winapi.Windows.AlphaBlend(alvo.Canvas.Handle, faixa.Left, faixa.Top,
    bmpFaixa.Width, bmpFaixa.Height,
    bmpFaixa.Canvas.Handle, 0, 0, bmpFaixa.Width, bmpFaixa.Height, mistura);
end;

procedure TfMonitorBiblia.pbTextoPaint(Sender: TObject);
var
  t: Double;
  desloc, dyAnterior, dyAtual: Integer;
  passado: Cardinal;
begin
  if not Assigned(bmpQuadro) then Exit;

  if (bmpFundo.Width <> pnlBiblia.ClientWidth) or
     (bmpFundo.Height <> pnlBiblia.ClientHeight) or
     (corFundo <> pnlBiblia.Color) then
    fundoValido := False;

  if not fundoValido then montaFundo;

  bmpQuadro.SetSize(bmpFundo.Width, bmpFundo.Height);
  BitBlt(bmpQuadro.Canvas.Handle, 0, 0, bmpQuadro.Width, bmpQuadro.Height,
         bmpFundo.Canvas.Handle, 0, 0, SRCCOPY);

  if animando then
  begin
    passado := GetTickCount - animInicio;
    if passado >= animDuracao then t := 1
    else t := passado / animDuracao;
    //Suaviza começo e fim: entrada linear denuncia o corte tanto quanto o
    //corte seco que ela substitui
    t := t * t * (3 - 2 * t);

    dyAnterior := 0;
    dyAtual := 0;
    if animTipo = 2 then
    begin
      desloc := Trunc(bmpQuadro.Height * DESLOC_FRACAO);
      dyAnterior := -Trunc(desloc * t);
      dyAtual := Trunc(desloc * (1 - t));
    end;

    desenhaCamada(bmpQuadro, textoAnterior, infoAnterior, dyAnterior,
                  Round(255 * (1 - t)));
    desenhaCamada(bmpQuadro, textoAtual, infoAtual, dyAtual, Round(255 * t));
  end
  else
    desenhaCamada(bmpQuadro, textoAtual, infoAtual, 0, 255);

  BitBlt(pbTexto.Canvas.Handle, 0, 0, pbTexto.Width, pbTexto.Height,
         bmpQuadro.Canvas.Handle, 0, 0, SRCCOPY);
end;

procedure TfMonitorBiblia.tmrAnimTimer(Sender: TObject);
begin
  if (GetTickCount - animInicio) >= animDuracao then
  begin
    animando := False;
    tmrAnim.Enabled := False;
    textoAnterior := '';
    infoAnterior := '';
  end;

  //Repaint, e não Invalidate: o quadro precisa sair agora, não quando a fila
  //de mensagens permitir
  if Assigned(pbTexto) then pbTexto.Repaint;
end;

procedure TfMonitorBiblia.defineTexto(const Texto, Info: string);
begin
  if not Assigned(pbTexto) then Exit;

  //A janela principal reenvia os mesmos dados em várias situações: sem esta
  //saída a transição recomeçaria sozinha. Ainda assim redesenha, porque o que
  //mudou pode ter sido fonte, cor ou tamanho da mesma passagem
  if (Texto = textoAtual) and (Info = infoAtual) then
  begin
    pbTexto.Invalidate;
    Exit;
  end;

  animTipo := StrToIntDef(fmIndex.lerParam('Biblia', 'Transicao', '1'), 1);
  animDuracao := EnsureRange(
    StrToIntDef(fmIndex.lerParam('Biblia', 'TransicaoMs', '350'), 350),
    DUR_MIN, DUR_MAX);

  textoAnterior := textoAtual;
  infoAnterior := infoAtual;
  textoAtual := Texto;
  infoAtual := Info;

  if animTipo <= 0 then
  begin
    animando := False;
    tmrAnim.Enabled := False;
    textoAnterior := '';
    infoAnterior := '';
    pbTexto.Repaint;
    Exit;
  end;

  animInicio := GetTickCount;
  animando := True;
  tmrAnim.Enabled := True;
  pbTexto.Repaint;
end;

procedure TfMonitorBiblia.FormActivate(Sender: TObject);
begin
  fmIndex.btExp_Biblia.ImageIndex := 11;
end;

procedure TfMonitorBiblia.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  tmrAnim.Enabled := False;
  animando := False;

  //A janela principal cria outra instância a cada abertura e só esconde a
  //anterior: sem soltar os bitmaps, cada ciclo deixaria para trás três telas
  //cheias de memória
  bmpFundo.SetSize(0, 0);
  bmpQuadro.SetSize(0, 0);
  bmpFaixa.SetSize(0, 0);
  fundoValido := False;

  fmIndex.fadeJanela(Self, 0);

  fmIndex.btExp_Biblia.ImageIndex := 10;
end;

procedure TfMonitorBiblia.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fmIndex.FormKeyUp(Sender, Key, Shift);
end;

end.
