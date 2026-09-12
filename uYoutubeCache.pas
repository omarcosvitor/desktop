unit uYoutubeCache;

{
  Cache local dos vídeos dos canais fixados, usado como reserva quando não há
  internet na hora do culto.

  Regras, nesta ordem:
    - por canal, só os YT_CACHE_VIDEOS mais recentes do feed;
    - dentro desses, só os publicados nos últimos YT_CACHE_DIAS dias;
    - o que sai dessa janela é apagado do disco, inclusive sem rede - a data de
      publicação fica gravada no índice de cada canal justamente para que a
      limpeza não dependa do feed.

  O download é feito pelo yt-dlp: o feed RSS não expõe a mídia e o player
  online do programa é um iframe, então não há caminho interno para o arquivo.
  Com o ffmpeg disponível o yt-dlp junta vídeo e áudio separados e alcança
  1080p ou mais; sem ele só existe formato progressivo, que o YouTube limita a
  720p. Nos dois casos a preferência é H.264 + AAC: o player interno usa MCI,
  que depende dos codecs do Windows e não costuma abrir VP9 nem AV1.
}

interface

uses
  System.Classes, System.SysUtils;

const
  //Vídeos mantidos por canal e janela de retenção, em dias
  YT_CACHE_VIDEOS = 5;
  YT_CACHE_DIAS   = 7;
  //Teto por vídeo: download travado não pode segurar a fila para sempre
  YT_CACHE_TIMEOUT_MS = 30 * 60 * 1000;

//Raiz do cache, definida uma vez na inicialização do programa
procedure ytCacheDefineRaiz(const Dir: string);
function ytCacheRaiz: string;

//Caminho do arquivo já baixado, ou '' quando o vídeo não está no cache
function ytCacheArquivo(const VideoId: string): string;
function ytCacheTamanho: Int64;

//Ferramentas externas ('' quando não encontradas)
function ytCacheYtDlp: string;
function ytCacheFFmpeg: string;

//Conferência dos identificadores, usada também fora desta unit
function ytIdCanalValido(const CanalId: string): Boolean;
function ytIdVideoValido(const VideoId: string): Boolean;

//Lista de canais fixos a partir do parâmetro gravado na configuração
function ytCanaisFixos(const Texto: string): TArray<string>;
function ytCanalFixo(const Texto, CanalId: string): Boolean;
function ytTextoCanaisFixos(const Canais: TArray<string>): string;
function ytAlternaCanalFixo(const Texto, CanalId: string; Fixar: Boolean): string;

//Atualiza o cache dos canais informados: baixa o que falta e apaga o vencido
procedure ytCacheAtualiza(const Canais: array of string);
//Mesmo trabalho em segundo plano; chamada nova é ignorada enquanto a anterior
//não termina
procedure ytCacheAtualizaAsync(const Canais: array of string);
function ytCacheOcupado: Boolean;
//Interrompe a fila e derruba o download em andamento (usado ao fechar)
procedure ytCacheCancela;

implementation

uses
  Winapi.Windows, System.IniFiles, System.DateUtils, System.SyncObjs,
  System.RegularExpressions, uYoutubeRSS;

const
  ARQ_INDICE = 'cache.ini';
  //Extensões que o yt-dlp usa para arquivo incompleto: não contam como cache
  EXT_PARCIAL: array[0..2] of string = ('.part', '.ytdl', '.temp');
  RE_VIDEO_ID_COMPLETO = '^[A-Za-z0-9_-]{11}$';
  RE_CANAL_ID_COMPLETO = '^UC[A-Za-z0-9_-]{22}$';

var
  FRaiz: string = '';
  FThread: TThread = nil;
  FCancela: Boolean = False;
  FProcesso: THandle = 0;
  FTrava: TCriticalSection = nil;

type
  TYtCacheThread = class(TThread)
  private
    FCanais: TArray<string>;
  protected
    procedure Execute; override;
  public
    constructor Create(const Canais: array of string);
  end;

{ ---------------------------------------------------------------------------
  Caminhos
  --------------------------------------------------------------------------- }

procedure ytCacheDefineRaiz(const Dir: string);
begin
  FRaiz := IncludeTrailingPathDelimiter(Dir);
end;

function ytCacheRaiz: string;
begin
  Result := FRaiz;
end;

function ytIdVideoValido(const VideoId: string): Boolean;
begin
  Result := TRegEx.IsMatch(VideoId, RE_VIDEO_ID_COMPLETO);
end;

function ytIdCanalValido(const CanalId: string): Boolean;
begin
  Result := TRegEx.IsMatch(CanalId, RE_CANAL_ID_COMPLETO);
end;

function pastaCanal(const CanalId: string): string;
begin
  Result := FRaiz + CanalId + PathDelim;
end;

function ehParcial(const Arquivo: string): Boolean;
var
  i: Integer;
  ext: string;
begin
  Result := False;
  ext := LowerCase(ExtractFileExt(Arquivo));
  for i := Low(EXT_PARCIAL) to High(EXT_PARCIAL) do
    if ext = EXT_PARCIAL[i] then Exit(True);
end;

function ytCacheArquivo(const VideoId: string): string;
var
  busca: TSearchRec;
  buscaCanal: TSearchRec;
  pasta: string;
begin
  Result := '';
  if (FRaiz = '') or not ytIdVideoValido(VideoId) then Exit;
  if not DirectoryExists(FRaiz) then Exit;

  //Uma pasta por canal, e o nome do arquivo é sempre o id do vídeo
  if FindFirst(FRaiz + '*', faDirectory, buscaCanal) <> 0 then Exit;
  try
    repeat
      if (buscaCanal.Attr and faDirectory) = 0 then Continue;
      if (buscaCanal.Name = '.') or (buscaCanal.Name = '..') then Continue;

      pasta := FRaiz + buscaCanal.Name + PathDelim;
      if FindFirst(pasta + VideoId + '.*', faAnyFile - faDirectory, busca) = 0 then
      try
        repeat
          if ehParcial(busca.Name) then Continue;
          if busca.Size <= 0 then Continue;
          Exit(pasta + busca.Name);
        until FindNext(busca) <> 0;
      finally
        System.SysUtils.FindClose(busca);
      end;
    until FindNext(buscaCanal) <> 0;
  finally
    System.SysUtils.FindClose(buscaCanal);
  end;
end;

function ytCacheTamanho: Int64;
var
  buscaCanal, busca: TSearchRec;
  pasta: string;
begin
  Result := 0;
  if (FRaiz = '') or not DirectoryExists(FRaiz) then Exit;

  if FindFirst(FRaiz + '*', faDirectory, buscaCanal) <> 0 then Exit;
  try
    repeat
      if (buscaCanal.Attr and faDirectory) = 0 then Continue;
      if (buscaCanal.Name = '.') or (buscaCanal.Name = '..') then Continue;

      pasta := FRaiz + buscaCanal.Name + PathDelim;
      if FindFirst(pasta + '*', faAnyFile - faDirectory, busca) = 0 then
      try
        repeat
          Result := Result + busca.Size;
        until FindNext(busca) <> 0;
      finally
        System.SysUtils.FindClose(busca);
      end;
    until FindNext(buscaCanal) <> 0;
  finally
    System.SysUtils.FindClose(buscaCanal);
  end;
end;

{ ---------------------------------------------------------------------------
  Ferramentas externas
  --------------------------------------------------------------------------- }

function achaFerramenta(const Nome: string): string;
var
  dir: string;
begin
  dir := ExtractFilePath(ParamStr(0));
  //Pasta própria primeiro: assim uma cópia antiga solta no diretório do
  //programa não ganha da que veio com a instalação
  Result := dir + 'tools' + PathDelim + Nome;
  if FileExists(Result) then Exit;

  Result := dir + Nome;
  if FileExists(Result) then Exit;

  //Só então o PATH do sistema
  Result := FileSearch(Nome, GetEnvironmentVariable('PATH'));
end;

function ytCacheYtDlp: string;
begin
  Result := achaFerramenta('yt-dlp.exe');
end;

function ytCacheFFmpeg: string;
begin
  Result := achaFerramenta('ffmpeg.exe');
end;

{ ---------------------------------------------------------------------------
  Canais fixos
  --------------------------------------------------------------------------- }

function ytCanaisFixos(const Texto: string): TArray<string>;
var
  partes: TArray<string>;
  i: Integer;
  id: string;
begin
  Result := nil;
  partes := Texto.Split(['|']);
  for i := 0 to High(partes) do
  begin
    id := Trim(partes[i]);
    if ytIdCanalValido(id) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := id;
    end;
  end;
end;

function ytCanalFixo(const Texto, CanalId: string): Boolean;
var
  canais: TArray<string>;
  i: Integer;
begin
  Result := False;
  canais := ytCanaisFixos(Texto);
  for i := 0 to High(canais) do
    if SameText(canais[i], CanalId) then Exit(True);
end;

function ytTextoCanaisFixos(const Canais: TArray<string>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Canais) do
  begin
    if Result <> '' then Result := Result + '|';
    Result := Result + Canais[i];
  end;
end;

function ytAlternaCanalFixo(const Texto, CanalId: string; Fixar: Boolean): string;
var
  canais, novos: TArray<string>;
  i: Integer;
begin
  canais := ytCanaisFixos(Texto);
  novos := nil;
  for i := 0 to High(canais) do
    if not SameText(canais[i], CanalId) then
    begin
      SetLength(novos, Length(novos) + 1);
      novos[High(novos)] := canais[i];
    end;

  if Fixar and ytIdCanalValido(CanalId) then
  begin
    SetLength(novos, Length(novos) + 1);
    novos[High(novos)] := CanalId;
  end;

  Result := ytTextoCanaisFixos(novos);
end;

{ ---------------------------------------------------------------------------
  Download
  --------------------------------------------------------------------------- }

function executaOculto(const Linha: string; TimeoutMs: Cardinal): Boolean;
var
  si: TStartupInfo;
  pi: TProcessInformation;
  cmd: string;
  saida: Cardinal;
begin
  Result := False;
  //CreateProcess pode escrever no buffer recebido: cópia exclusiva
  cmd := Linha;
  UniqueString(cmd);

  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESHOWWINDOW;
  si.wShowWindow := SW_HIDE;
  FillChar(pi, SizeOf(pi), 0);

  if not CreateProcess(nil, PChar(cmd), nil, nil, False,
                       CREATE_NO_WINDOW, nil, nil, si, pi) then Exit;
  try
    FTrava.Enter;
    try
      FProcesso := pi.hProcess;
    finally
      FTrava.Leave;
    end;

    if WaitForSingleObject(pi.hProcess, TimeoutMs) <> WAIT_OBJECT_0 then
    begin
      TerminateProcess(pi.hProcess, 1);
      WaitForSingleObject(pi.hProcess, 5000);
      Exit;
    end;

    if GetExitCodeProcess(pi.hProcess, saida) then
      Result := (saida = 0);
  finally
    FTrava.Enter;
    try
      FProcesso := 0;
    finally
      FTrava.Leave;
    end;
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
  end;
end;

function baixaVideo(const VideoId, Pasta: string): Boolean;
var
  ytdlp, ffmpeg, formato, linha: string;
begin
  Result := False;
  //O id vem do feed, mas entra em linha de comando: sem a conferência um
  //valor inesperado viraria argumento do yt-dlp
  if not ytIdVideoValido(VideoId) then Exit;

  ytdlp := ytCacheYtDlp;
  if ytdlp = '' then Exit;

  ffmpeg := ytCacheFFmpeg;
  if ffmpeg <> '' then
    formato := 'bv*[vcodec^=avc1]+ba[acodec^=mp4a]/b[ext=mp4][vcodec^=avc1]/b[ext=mp4]/b'
  else
    //Sem ffmpeg não há como juntar faixas: só formato que já vem inteiro
    formato := 'b[ext=mp4][vcodec^=avc1]/b[ext=mp4]/b';

  linha := '"' + ytdlp + '"' +
           ' --ignore-config --no-playlist --no-warnings --quiet' +
           ' --retries 3 --socket-timeout 20 --no-overwrites' +
           ' -f "' + formato + '"' +
           ' --merge-output-format mp4';

  if ffmpeg <> '' then
    linha := linha + ' --ffmpeg-location "' + ExcludeTrailingPathDelimiter(ExtractFilePath(ffmpeg)) + '"';

  linha := linha + ' -o "' + Pasta + '%(id)s.%(ext)s"' +
           ' -- ' + VideoId;

  Result := executaOculto(linha, YT_CACHE_TIMEOUT_MS);
end;

{ ---------------------------------------------------------------------------
  Atualização e limpeza
  --------------------------------------------------------------------------- }

//Data gravada em ISO 8601: ReadFloat/WriteFloat seguiriam o separador
//decimal em uso, e um índice escrito numa máquina não abriria em outra
function dataParaIndice(Valor: TDateTime): string;
begin
  if Valor <= 0 then Exit('');
  Result := DateToISO8601(Valor, False);
end;

function dataDoIndice(const Valor: string): TDateTime;
begin
  Result := 0;
  if Trim(Valor) = '' then Exit;
  try
    Result := ISO8601ToDate(Valor, False);
  except
    Result := 0;
  end;
end;

function noConjunto(const Lista: TStringList; const Id: string): Boolean;
begin
  Result := Lista.IndexOf(Id) >= 0;
end;

//Apaga da pasta do canal tudo que não está na lista a manter, e tira do
//índice o que não sobrou
procedure limpaPasta(const Pasta: string; const Manter: TStringList);
var
  busca: TSearchRec;
  ini: TIniFile;
  secoes: TStringList;
  i: Integer;
  base: string;
begin
  if FindFirst(Pasta + '*', faAnyFile - faDirectory, busca) = 0 then
  try
    repeat
      if SameText(busca.Name, ARQ_INDICE) then Continue;
      base := ChangeFileExt(busca.Name, '');
      //Arquivo incompleto perde a extensão de trabalho antes da comparação
      if ehParcial(busca.Name) then base := ChangeFileExt(base, '');
      if noConjunto(Manter, base) and not ehParcial(busca.Name) then Continue;
      System.SysUtils.DeleteFile(Pasta + busca.Name);
    until FindNext(busca) <> 0;
  finally
    System.SysUtils.FindClose(busca);
  end;

  ini := TIniFile.Create(Pasta + ARQ_INDICE);
  secoes := TStringList.Create;
  try
    ini.ReadSections(secoes);
    for i := 0 to secoes.Count - 1 do
      if not noConjunto(Manter, secoes[i]) then
        ini.EraseSection(secoes[i]);
  finally
    secoes.Free;
    ini.Free;
  end;
end;

//Sem rede o feed não responde: a janela de retenção passa a ser conferida
//pelo que o índice guardou da última atualização
procedure listaDoIndice(const Pasta: string; Limite: TDateTime;
  Manter: TStringList);
var
  ini: TIniFile;
  secoes: TStringList;
  i: Integer;
  pub: TDateTime;
begin
  ini := TIniFile.Create(Pasta + ARQ_INDICE);
  secoes := TStringList.Create;
  try
    ini.ReadSections(secoes);
    for i := 0 to secoes.Count - 1 do
    begin
      if not ytIdVideoValido(secoes[i]) then Continue;
      pub := dataDoIndice(ini.ReadString(secoes[i], 'Publicado', ''));
      if (pub > 0) and (pub < Limite) then Continue;
      Manter.Add(secoes[i]);
    end;
  finally
    secoes.Free;
    ini.Free;
  end;
end;

procedure atualizaCanal(const CanalId: string);
var
  pasta, nome: string;
  videos: TYoutubeVideos;
  manter: TStringList;
  ini: TIniFile;
  limite: TDateTime;
  i: Integer;
begin
  if (FRaiz = '') or not ytIdCanalValido(CanalId) then Exit;

  pasta := pastaCanal(CanalId);
  if not ForceDirectories(pasta) then Exit;

  limite := IncDay(Now, -YT_CACHE_DIAS);
  manter := TStringList.Create;
  try
    manter.Sorted := False;
    manter.CaseSensitive := True;

    if ytBuscaVideos(CanalId, YT_CACHE_VIDEOS, videos, nome) then
    begin
      ini := TIniFile.Create(pasta + ARQ_INDICE);
      try
        for i := 0 to High(videos) do
        begin
          if manter.Count >= YT_CACHE_VIDEOS then Break;
          if not ytIdVideoValido(videos[i].VideoId) then Continue;
          //Data ausente no feed (Publicado = 0) não derruba o vídeo: nesse
          //caso vale só o teto de YT_CACHE_VIDEOS
          if (videos[i].Publicado > 0) and (videos[i].Publicado < limite) then Continue;

          manter.Add(videos[i].VideoId);
          ini.WriteString(videos[i].VideoId, 'Titulo', videos[i].Titulo);
          ini.WriteString(videos[i].VideoId, 'Publicado',
                          dataParaIndice(videos[i].Publicado));
          ini.WriteString(videos[i].VideoId, 'Canal', CanalId);
        end;
      finally
        ini.Free;
      end;
    end
    else
      listaDoIndice(pasta, limite, manter);

    //Limpeza antes do download: espaço liberado pode ser o que falta para o
    //vídeo novo caber
    limpaPasta(pasta, manter);

    for i := 0 to manter.Count - 1 do
    begin
      if FCancela then Exit;
      if ytCacheArquivo(manter[i]) <> '' then Continue;
      baixaVideo(manter[i], pasta);
    end;
  finally
    manter.Free;
  end;
end;

procedure ytCacheAtualiza(const Canais: array of string);
var
  i: Integer;
begin
  for i := Low(Canais) to High(Canais) do
  begin
    if FCancela then Exit;
    try
      atualizaCanal(Canais[i]);
    except
      //Um canal com problema não pode derrubar a fila inteira
    end;
  end;
end;

{ TYtCacheThread }

constructor TYtCacheThread.Create(const Canais: array of string);
var
  i: Integer;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  SetLength(FCanais, Length(Canais));
  for i := Low(Canais) to High(Canais) do
    FCanais[i - Low(Canais)] := Canais[i];
end;

procedure TYtCacheThread.Execute;
begin
  try
    ytCacheAtualiza(FCanais);
  finally
    FThread := nil;
  end;
end;

procedure ytCacheAtualizaAsync(const Canais: array of string);
begin
  if (FRaiz = '') or (Length(Canais) = 0) then Exit;
  if Assigned(FThread) then Exit;

  FCancela := False;
  FThread := TYtCacheThread.Create(Canais);
  FThread.Start;
end;

function ytCacheOcupado: Boolean;
begin
  Result := Assigned(FThread);
end;

//Aguarda a thread encerrar, no máximo o tempo informado
procedure esperaFim(TimeoutMs: Cardinal);
var
  fim: Cardinal;
begin
  fim := GetTickCount + TimeoutMs;
  while Assigned(FThread) and (GetTickCount < fim) do
    Sleep(50);
end;

procedure ytCacheCancela;
begin
  FCancela := True;
  FTrava.Enter;
  try
    //Derruba o yt-dlp em andamento: sem isso o processo filho sobreviveria ao
    //fechamento do programa
    if FProcesso <> 0 then TerminateProcess(FProcesso, 1);
  finally
    FTrava.Leave;
  end;
end;

initialization
  FTrava := TCriticalSection.Create;

finalization
  ytCacheCancela;
  //Espera curta: a thread só precisa sair do laço, já que o download em
  //andamento acabou de ser derrubado. A trava não é liberada de propósito:
  //presa numa consulta de rede, a thread ainda pode tocá-la depois daqui, e
  //liberar memória no encerramento do processo não muda nada

end.
