unit uYoutubeRSS;

{
  Consulta dos vídeos mais recentes de um canal do YouTube.

  Usa o feed RSS público (/feeds/videos.xml) em vez da Data API v3: a API
  exigiria uma chave por instalação, e chave embutida em executável distribuído
  é segredo exposto. O preço é a limitação do feed: apenas os ~15 vídeos mais
  recentes, sem paginação e sem busca por texto.

  O feed só aceita o ID do canal (UC...). Handle (@nome), URL personalizada
  (/c/nome) e usuário legado (/user/nome) precisam ser resolvidos antes, lendo
  o HTML da página do canal - é o único caminho sem chave de API.
}

interface

uses
  System.SysUtils, System.Classes;

type
  TYoutubeVideo = record
    VideoId: string;
    Titulo: string;
    //Hora local; 0 quando o feed não trouxe data legível
    Publicado: TDateTime;
  end;

  TYoutubeVideos = TArray<TYoutubeVideo>;

const
  YT_MAX_VIDEOS = 15;

//Resolve @handle, URL de canal ou ID UC... para o ID do canal
function ytResolveCanal(const Entrada: string; out CanalId: string): Boolean;
//Lê o feed do canal. CanalNome vem do próprio feed
function ytBuscaVideos(const CanalId: string; Maximo: Integer;
  out Videos: TYoutubeVideos; out CanalNome: string): Boolean;
function ytBaixaBinario(const Url: string; Destino: TStream): Boolean;
function ytUrlVideo(const VideoId: string): string;
function ytThumbUrl(const VideoId: string): string;
function ytVideoIdDeUrl(const Url: string): string;

implementation

uses
  System.Net.HttpClient, System.NetEncoding, System.RegularExpressions,
  System.DateUtils, System.StrUtils;

const
  //O YouTube devolve página reduzida (sem o channelId) para agente desconhecido
  UA_NAVEGADOR = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
                 '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  URL_FEED  = 'https://www.youtube.com/feeds/videos.xml?channel_id=';
  URL_CANAL = 'https://www.youtube.com/';
  URL_VIDEO = 'https://www.youtube.com/watch?v=';
  //mqdefault: única miniatura 16:9 que existe para todo vídeo (320x180)
  URL_THUMB = 'https://i.ytimg.com/vi/%s/mqdefault.jpg';
  //Busca síncrona: sem limite a janela de montagem da liturgia ficaria travada.
  //Conexão com prazo menor para o caso mais comum de falha - máquina sem rede
  TIMEOUT_CONEXAO  = 8000;
  TIMEOUT_RESPOSTA = 15000;
  RE_CANAL_ID = 'UC[A-Za-z0-9_-]{22}';
  RE_VIDEO_ID = '[A-Za-z0-9_-]{11}';

function criaCliente: THTTPClient;
begin
  Result := THTTPClient.Create;
  Result.UserAgent := UA_NAVEGADOR;
  Result.ConnectionTimeout := TIMEOUT_CONEXAO;
  Result.ResponseTimeout := TIMEOUT_RESPOSTA;
  Result.HandleRedirects := True;
end;

function ytBaixaBinario(const Url: string; Destino: TStream): Boolean;
var
  cli: THTTPClient;
  resp: IHTTPResponse;
begin
  Result := False;
  if not Assigned(Destino) then Exit;

  cli := criaCliente;
  try
    try
      resp := cli.Get(Url, Destino);
    except
      //Rede fora, DNS ou TLS: quem chamou decide a mensagem ao usuário
      Exit;
    end;
    Result := Assigned(resp) and (resp.StatusCode >= 200) and (resp.StatusCode < 300);
  finally
    cli.Free;
  end;
end;

function baixaTexto(const Url: string; out Conteudo: string): Boolean;
var
  ms: TMemoryStream;
  bytes: TBytes;
begin
  Result := False;
  Conteudo := '';
  ms := TMemoryStream.Create;
  try
    if not ytBaixaBinario(Url, ms) then Exit;
    if ms.Size <= 0 then Exit;
    SetLength(bytes, ms.Size);
    ms.Position := 0;
    ms.ReadBuffer(bytes[0], ms.Size);
    Conteudo := TEncoding.UTF8.GetString(bytes);
    Result := Conteudo <> '';
  finally
    ms.Free;
  end;
end;

function extraiCanalId(const Texto: string): string;
var
  m: TMatch;
begin
  Result := '';
  m := TRegEx.Match(Texto, '"(?:channelId|externalId)"\s*:\s*"(' + RE_CANAL_ID + ')"');
  if not m.Success then
    m := TRegEx.Match(Texto, 'channel/(' + RE_CANAL_ID + ')');
  if m.Success then
    Result := m.Groups[1].Value;
end;

function ytResolveCanal(const Entrada: string; out CanalId: string): Boolean;
var
  txt, html: string;
  candidatos: TArray<string>;
  i: Integer;
begin
  Result := False;
  CanalId := '';
  txt := Trim(Entrada);
  if txt = '' then Exit;

  //ID já pronto: nada a resolver
  if TRegEx.IsMatch(txt, '^' + RE_CANAL_ID + '$') then
  begin
    CanalId := txt;
    Exit(True);
  end;

  //URL /channel/UC...: o ID está na própria string
  CanalId := extraiCanalId(txt);
  if CanalId <> '' then Exit(True);

  if StartsText('http', txt) then
    candidatos := TArray<string>.Create(txt)
  else if StartsStr('@', txt) then
    candidatos := TArray<string>.Create(URL_CANAL + txt)
  else
    //Sem pista do formato: handle, URL personalizada e usuário legado
    candidatos := TArray<string>.Create(URL_CANAL + '@' + txt,
                                        URL_CANAL + 'c/' + txt,
                                        URL_CANAL + 'user/' + txt);

  for i := 0 to High(candidatos) do
    if baixaTexto(candidatos[i], html) then
    begin
      CanalId := extraiCanalId(html);
      if CanalId <> '' then Exit(True);
    end;
end;

function valorTag(const Bloco, Tag: string): string;
var
  m: TMatch;
begin
  Result := '';
  m := TRegEx.Match(Bloco, '<' + Tag + '[^>]*>(.*?)</' + Tag + '>', [roSingleLine]);
  if m.Success then
    Result := TNetEncoding.HTML.Decode(Trim(m.Groups[1].Value));
end;

function ytBuscaVideos(const CanalId: string; Maximo: Integer;
  out Videos: TYoutubeVideos; out CanalNome: string): Boolean;
var
  feed, bloco, sdata: string;
  m: TMatch;
  v: TYoutubeVideo;
  p: Integer;
begin
  Videos := nil;
  CanalNome := '';
  Result := False;
  if Trim(CanalId) = '' then Exit;
  if Maximo <= 0 then Maximo := YT_MAX_VIDEOS;

  if not baixaTexto(URL_FEED + CanalId, feed) then Exit;

  //O <title> antes da primeira <entry> é o nome do canal
  p := Pos('<entry>', feed);
  if p > 0 then
    CanalNome := valorTag(Copy(feed, 1, p - 1), 'title');

  m := TRegEx.Match(feed, '<entry>(.*?)</entry>', [roSingleLine]);
  while m.Success and (Length(Videos) < Maximo) do
  begin
    bloco := m.Groups[1].Value;
    v.VideoId := valorTag(bloco, 'yt:videoId');
    v.Titulo := valorTag(bloco, 'title');
    v.Publicado := 0;
    sdata := valorTag(bloco, 'published');
    if sdata <> '' then
      try
        v.Publicado := ISO8601ToDate(sdata, False);
      except
        v.Publicado := 0;
      end;

    if v.VideoId <> '' then
    begin
      SetLength(Videos, Length(Videos) + 1);
      Videos[High(Videos)] := v;
    end;

    m := m.NextMatch;
  end;

  Result := Length(Videos) > 0;
end;

function ytUrlVideo(const VideoId: string): string;
begin
  Result := URL_VIDEO + VideoId;
end;

function ytThumbUrl(const VideoId: string): string;
begin
  Result := Format(URL_THUMB, [VideoId]);
end;

function ytVideoIdDeUrl(const Url: string): string;
var
  m: TMatch;
begin
  Result := '';
  m := TRegEx.Match(Url, '(?:v=|youtu\.be/|/embed/|/shorts/|/live/)(' + RE_VIDEO_ID + ')');
  if m.Success then
    Result := m.Groups[1].Value;
end;

end.
