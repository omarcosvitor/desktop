unit uYoutubeRSS;

{
  Consulta dos vídeos mais recentes de um canal do YouTube.

  Usa o feed RSS público (/feeds/videos.xml) em vez da Data API v3: a API
  exigiria uma chave por instalação, e chave embutida em executável distribuído
  é segredo exposto. O preço é a limitação do feed: apenas os ~15 vídeos mais
  recentes, sem paginação e sem busca por texto.

  O feed só aceita três chaves: channel_id, playlist_id e o user legado. Handle
  (@nome) e URL personalizada (/c/nome) não têm equivalente, então precisam ser
  resolvidos antes. A ordem tenta sempre o caminho mais estável primeiro:

    1. ID já presente na entrada (UC..., /channel/UC..., channel_id=UC...);
    2. usuário legado pelo próprio feed (?user=), que devolve <yt:channelId> -
       sem passar por HTML;
    3. HTML da página do canal, lendo primeiro o <link rel="alternate"
       type="application/rss+xml"> - o elemento de auto-descoberta de feed que
       os leitores de RSS usam, bem mais estável que o "channelId" do
       ytInitialData, que é estrutura interna do site.

  Ainda é raspagem de HTML no passo 3, e não existe alternativa sem chave de
  API: se o YouTube mudar a página, resta ao usuário colar o ID UC... direto,
  que o campo aceita.
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
//True para qualquer endereço de domínio do YouTube (inclui youtu.be)
function ytEhLinkYoutube(const Url: string): Boolean;
function ytUrlVideo(const VideoId: string): string;
function ytThumbUrl(const VideoId: string): string;
function ytVideoIdDeUrl(const Url: string): string;

implementation

uses
  System.Net.HttpClient, System.Net.URLClient, System.NetEncoding,
  System.RegularExpressions, System.DateUtils, System.StrUtils;

const
  //O YouTube devolve página reduzida (sem o channelId) para agente desconhecido
  UA_NAVEGADOR = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
                 '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  URL_FEED  = 'https://www.youtube.com/feeds/videos.xml?channel_id=';
  URL_FEED_USER = 'https://www.youtube.com/feeds/videos.xml?user=';
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
  //Host do YouTube e nada mais: '(sub.)*youtube.com', 'youtube-nocookie.com' ou
  //'youtu.be', sempre terminando o domínio - assim 'meu-youtube.com.br' não passa
  RE_HOST_YT = '^(?:https?://)?(?:[\w-]+\.)*(?:youtube\.com|youtube-nocookie\.com|youtu\.be)(?:[/:?#]|$)';

function cabecalhosPadrao: TNetHeaders;
begin
  //Sem o cookie de consentimento, parte da Europa recebe a tela do
  //consent.youtube.com no lugar da página do canal
  Result := TNetHeaders.Create(
    TNameValuePair.Create('Cookie', 'CONSENT=YES+cb; SOCS=CAI'),
    TNameValuePair.Create('Accept-Language', 'pt-BR,pt;q=0.9,en;q=0.8'));
end;

function ytBaixaBinario(const Url: string; Destino: TStream): Boolean;
var
  cli: THTTPClient;
  resp: IHTTPResponse;
begin
  Result := False;
  if not Assigned(Destino) then Exit;

  cli := THTTPClient.Create;
  try
    cli.UserAgent := UA_NAVEGADOR;
    cli.ConnectionTimeout := TIMEOUT_CONEXAO;
    cli.ResponseTimeout := TIMEOUT_RESPOSTA;
    cli.HandleRedirects := True;
    try
      resp := cli.Get(Url, Destino, cabecalhosPadrao);
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
  ss: TStringStream;
begin
  Conteudo := '';
  ss := TStringStream.Create('', TEncoding.UTF8);
  try
    Result := ytBaixaBinario(Url, ss) and (ss.DataString <> '');
    if Result then Conteudo := ss.DataString;
  finally
    ss.Free;
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

function extraiCanalId(const Texto: string): string;
const
  //Do mais estável para o menos: o link de auto-descoberta do RSS é elemento
  //padrão de <head> (é por ele que os leitores de feed acham o canal), enquanto
  //"channelId" vem do ytInitialData, estrutura interna que muda sem aviso
  PADROES: array[0..4] of string = (
    'feeds/videos\.xml\?channel_id=(' + RE_CANAL_ID + ')',
    'rel="canonical"[^>]*href="[^"]*channel/(' + RE_CANAL_ID + ')',
    'og:url"[^>]*content="[^"]*channel/(' + RE_CANAL_ID + ')',
    '"(?:channelId|externalId)"\s*:\s*"(' + RE_CANAL_ID + ')"',
    'channel/(' + RE_CANAL_ID + ')');
var
  i: Integer;
  m: TMatch;
begin
  Result := '';
  for i := Low(PADROES) to High(PADROES) do
  begin
    m := TRegEx.Match(Texto, PADROES[i]);
    if m.Success then
    begin
      Result := m.Groups[1].Value;
      Exit;
    end;
  end;
end;

//Usuário legado: o próprio feed aceita ?user= e devolve o <yt:channelId>,
//então esse caminho não depende do HTML do site
function canalIdPeloUsuario(const Usuario: string; out CanalId: string): Boolean;
var
  feed: string;
begin
  Result := False;
  CanalId := '';
  if Trim(Usuario) = '' then Exit;
  if not baixaTexto(URL_FEED_USER + TNetEncoding.URL.Encode(Usuario), feed) then Exit;
  CanalId := valorTag(feed, 'yt:channelId');
  Result := TRegEx.IsMatch(CanalId, '^' + RE_CANAL_ID + '$');
  if not Result then CanalId := '';
end;

function ytResolveCanal(const Entrada: string; out CanalId: string): Boolean;
var
  txt, html: string;
  candidatos: TArray<string>;
  m: TMatch;
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

  //Usuário legado, seja na URL colada ou como nome solto: tenta o feed antes
  //de qualquer HTML
  m := TRegEx.Match(txt, '/user/([\w.-]+)');
  if m.Success then
    if canalIdPeloUsuario(m.Groups[1].Value, CanalId) then Exit(True);

  if StartsText('http', txt) then
    candidatos := TArray<string>.Create(txt)
  else if StartsStr('@', txt) then
    candidatos := TArray<string>.Create(URL_CANAL + txt)
  else
  begin
    if canalIdPeloUsuario(txt, CanalId) then Exit(True);
    //Sem pista do formato: handle e URL personalizada
    candidatos := TArray<string>.Create(URL_CANAL + '@' + txt,
                                        URL_CANAL + 'c/' + txt);
  end;

  for i := 0 to High(candidatos) do
    if baixaTexto(candidatos[i], html) then
    begin
      CanalId := extraiCanalId(html);
      if CanalId <> '' then Exit(True);
    end;
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
      Videos := Videos + [v];

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

function ytEhLinkYoutube(const Url: string): Boolean;
begin
  Result := TRegEx.IsMatch(Trim(Url), RE_HOST_YT, [roIgnoreCase]);
end;

function ytVideoIdDeUrl(const Url: string): string;
const
  //Um formato por linha, todos terminando com (?![\w-]) para não cortar um
  //texto maior no meio e devolver 11 caracteres que não são o vídeo
  PADROES: array[0..3] of string = (
    'youtu\.be/(' + RE_VIDEO_ID + ')(?![\w-])',
    '/(?:embed|shorts|live|v|e)/(' + RE_VIDEO_ID + ')(?![\w-])',
    '[?&]v=(' + RE_VIDEO_ID + ')(?![\w-])',
    //Link de atribuição: a URL do vídeo vem codificada dentro do parâmetro u
    '%3Fv%3D(' + RE_VIDEO_ID + ')(?![\w-])');
var
  txt: string;
  i: Integer;
  m: TMatch;
begin
  Result := '';
  txt := Trim(Url);
  //Só endereço do YouTube: 'v=' e '/embed/' existem em muitos outros sites
  if not ytEhLinkYoutube(txt) then Exit;

  for i := Low(PADROES) to High(PADROES) do
  begin
    m := TRegEx.Match(txt, PADROES[i], [roIgnoreCase]);
    if m.Success then
    begin
      Result := m.Groups[1].Value;
      Exit;
    end;
  end;
end;

end.
