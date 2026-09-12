unit uFundoMusical;

{
  Fundo musical do apelo: toca um arquivo em laço, com volume próprio, sem
  passar pelo áudio do resto do programa.

  Não usa a BASS de propósito. As variáveis bass_musica e bass_channel são
  globais, compartilhadas por fmMenu, fmMusica e fmEditorSlides, e o fmMusica
  chama BASS_Free() ao fechar uma música - o que derruba o dispositivo inteiro,
  não só o canal dela. Projetar e fechar um hino no meio do apelo levaria o
  fundo musical junto.

  Também não usa o MediaPlayer1 da janela principal: ele é único, é dono do
  painel de controle do player e é parado por qualquer outra reprodução. O
  fundo musical precisa conviver com o que estiver tocando ou sendo projetado.

  Sobra o MCI por string, com alias próprio. É o mesmo caminho que o programa
  já usa para tocar áudio de arquivo, e cada alias abre um dispositivo
  separado, então o fundo fica isolado dos demais.
}

interface

uses
  System.Classes, System.SysUtils;

const
  //Fundo musical toca sob a voz de quem prega: volume inicial baixo
  FMUS_VOL_PADRAO = 40;
  //Intervalo esperado das chamadas de fmusPulso, em milissegundos
  FMUS_PULSO_MS = 200;

//Começa a tocar; Erro traz a mensagem quando devolve False
function fmusToca(const Arquivo: string; Volume: Integer; Repetir: Boolean;
  out Erro: string): Boolean;
//Pede o fim com esmaecimento - quem encerra de fato é fmusPulso
procedure fmusPara;
//Encerra na hora, sem esmaecer (fechamento do programa)
procedure fmusParaJa;
function fmusTocando: Boolean;
function fmusEsmaecendo: Boolean;
procedure fmusDefineVolume(Volume: Integer);
//Chamado por um cronômetro enquanto toca: refaz o laço e conduz o esmaecimento
procedure fmusPulso;

implementation

uses
  Winapi.Windows, Winapi.MMSystem, System.Math;

const
  ALIAS_MCI = 'louvorja_fundo';
  //Esmaecimento de entrada e de saída, em milissegundos
  FADE_MS = 1200;

var
  FAberto: Boolean = False;
  FRepetir: Boolean = False;
  FSaindo: Boolean = False;
  FVolumeAlvo: Integer = FMUS_VOL_PADRAO;
  FVolumeAtual: Integer = 0;

function comando(const Cmd: string; Resposta: PChar = nil;
  Tam: Integer = 0): Boolean;
begin
  Result := mciSendString(PChar(Cmd), Resposta, Tam, 0) = 0;
end;

function modoMci: string;
var
  buf: array[0..63] of Char;
begin
  Result := '';
  FillChar(buf, SizeOf(buf), 0);
  if comando('status ' + ALIAS_MCI + ' mode', @buf[0], Length(buf)) then
    Result := LowerCase(Trim(string(buf)));
end;

procedure aplicaVolume(Valor: Integer);
begin
  FVolumeAtual := EnsureRange(Valor, 0, 100);
  //O MCI trabalha de 0 a 1000. Nem todo dispositivo aceita o comando; quando
  //recusa, o fundo toca no volume cheio - ruim, mas melhor que não tocar
  comando('setaudio ' + ALIAS_MCI + ' volume to ' + IntToStr(FVolumeAtual * 10));
end;

procedure fecha;
begin
  FSaindo := False;
  if not FAberto then Exit;
  comando('stop ' + ALIAS_MCI);
  comando('close ' + ALIAS_MCI);
  FAberto := False;
  FVolumeAtual := 0;
end;

function fmusToca(const Arquivo: string; Volume: Integer; Repetir: Boolean;
  out Erro: string): Boolean;
var
  cod: MCIERROR;
  buf: array[0..255] of Char;
begin
  Result := False;
  Erro := '';

  if Trim(Arquivo) = '' then
  begin
    Erro := 'Nenhum fundo musical escolhido.';
    Exit;
  end;
  if not FileExists(Arquivo) then
  begin
    Erro := 'Arquivo não encontrado: ' + Arquivo;
    Exit;
  end;

  fecha;

  //mpegvideo cobre mp3, wav e wma; sem informar o tipo o MCI decide pela
  //extensão, o que falha em parte dos arquivos
  cod := mciSendString(PChar('open "' + Arquivo + '" type mpegvideo alias ' +
                             ALIAS_MCI), nil, 0, 0);
  if cod <> 0 then
    cod := mciSendString(PChar('open "' + Arquivo + '" alias ' + ALIAS_MCI),
                         nil, 0, 0);

  if cod <> 0 then
  begin
    FillChar(buf, SizeOf(buf), 0);
    mciGetErrorString(cod, @buf[0], Length(buf));
    Erro := Trim(string(buf));
    if Erro = '' then Erro := 'Não foi possível abrir o arquivo de áudio.';
    Exit;
  end;

  FAberto := True;
  FRepetir := Repetir;
  FSaindo := False;
  FVolumeAlvo := EnsureRange(Volume, 0, 100);
  //Entra esmaecendo: fundo musical que começa no volume cheio atropela quem
  //está falando
  aplicaVolume(0);

  if not comando('play ' + ALIAS_MCI) then
  begin
    Erro := 'Não foi possível reproduzir o arquivo.';
    fecha;
    Exit;
  end;

  Result := True;
end;

procedure fmusPara;
begin
  if FAberto then FSaindo := True;
end;

procedure fmusParaJa;
begin
  fecha;
end;

function fmusTocando: Boolean;
begin
  Result := FAberto;
end;

function fmusEsmaecendo: Boolean;
begin
  Result := FAberto and FSaindo;
end;

procedure fmusDefineVolume(Volume: Integer);
begin
  FVolumeAlvo := EnsureRange(Volume, 0, 100);
  //Durante o esmaecimento o alvo só vale para a próxima vez
  if FAberto and (not FSaindo) then aplicaVolume(FVolumeAlvo);
end;

procedure fmusPulso;
var
  passo: Integer;
begin
  if not FAberto then Exit;

  passo := Max(1, Round(100 * FMUS_PULSO_MS / FADE_MS));

  if FSaindo then
  begin
    if FVolumeAtual <= passo then fecha
    else aplicaVolume(FVolumeAtual - passo);
    Exit;
  end;

  if FVolumeAtual < FVolumeAlvo then
    aplicaVolume(Min(FVolumeAlvo, FVolumeAtual + passo));

  //Faixa terminou: com laço ligado volta ao começo, senão encerra sozinha
  if modoMci = 'stopped' then
  begin
    if FRepetir then
    begin
      comando('seek ' + ALIAS_MCI + ' to start');
      comando('play ' + ALIAS_MCI);
    end
    else
      fecha;
  end;
end;

initialization

finalization
  fmusParaJa;

end.
