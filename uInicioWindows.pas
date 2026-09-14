unit uInicioWindows;

{
  Início automático do LouvorJA junto com o Windows.

  Grava em HKEY_CURRENT_USER\...\Run: a chave por usuário não pede elevação,
  ao contrário de HKEY_LOCAL_MACHINE, e o programa sobe com o perfil de quem
  configurou. O valor leva o parâmetro /tray, que faz a cópia iniciada pelo
  Windows aparecer só como ícone na área de notificação.

  O caminho é regravado a cada vez que a opção é ligada: programa movido de
  pasta deixaria para trás um comando apontando para o lugar errado.
}

interface

function IniciaComWindows: Boolean;
//Devolve False quando o registro recusou a escrita (política de grupo, por
//exemplo); quem chamou desfaz o estado do controle na tela
function DefineIniciaComWindows(Ativar: Boolean): Boolean;
function IniciouMinimizado: Boolean;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Win.Registry;

const
  CHAVE_RUN  = 'Software\Microsoft\Windows\CurrentVersion\Run';
  NOME_VALOR = 'LouvorJA';

  //Aceito na linha de comando para subir direto na bandeja
  PARAM_TRAY = '/tray';

function comandoInicio: string;
begin
  Result := '"' + ParamStr(0) + '" ' + PARAM_TRAY;
end;

function IniciaComWindows: Boolean;
var
  reg: TRegistry;
begin
  Result := False;
  reg := TRegistry.Create(KEY_READ);
  try
    try
      reg.RootKey := HKEY_CURRENT_USER;
      if reg.OpenKeyReadOnly(CHAVE_RUN) then
      try
        Result := reg.ValueExists(NOME_VALOR);
      finally
        reg.CloseKey;
      end;
    except
      //Registro inacessível: para o programa isso é o mesmo que desligado
      Result := False;
    end;
  finally
    reg.Free;
  end;
end;

function DefineIniciaComWindows(Ativar: Boolean): Boolean;
var
  reg: TRegistry;
begin
  Result := False;
  reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    try
      reg.RootKey := HKEY_CURRENT_USER;
      if not reg.OpenKey(CHAVE_RUN, True) then Exit;
      try
        if Ativar then
          reg.WriteString(NOME_VALOR, comandoInicio)
        else if reg.ValueExists(NOME_VALOR) then
          reg.DeleteValue(NOME_VALOR);
        Result := True;
      finally
        reg.CloseKey;
      end;
    except
      Result := False;
    end;
  finally
    reg.Free;
  end;
end;

function IniciouMinimizado: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if SameText(Trim(ParamStr(i)), PARAM_TRAY) then Exit(True);
end;

end.
