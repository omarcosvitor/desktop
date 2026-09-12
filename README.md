# LouvorJA

Software de projeção de letras de músicas com centenas de músicas do Hinário Adventista, CDs jovens e coletâneas diversas.

[Site oficial](https://louvorja.com.br/)

Alguns dos recursos são:

- Projeção de versículos da bíblia
- Músicas cantadas, playbacks (sem vocal) ou projeção silenciosa (sem áudio)
- Tela de retorno (stage display) com prévia do slide seguinte
- Organizador de liturgia, agendamentos de cultos e cronômetros
- Saída em HTML para transmissão ao vivo (para inclusão no OBS ou Vmix, por exemplo)
- Editor de slides
- Utilitários gerais (sorteador, relógio, painel de recados)

## Requisitos

Você vai precisar de:

- Delphi RAD Studio 13 (Florence) - a Community Edition atende ([baixe aqui](https://www.embarcadero.com/products/delphi/starter/free-download))
- Uma versão instalada (e preferencialmente sincronizada) do LouvorJA ([baixe aqui](https://louvorja.com.br/download/)) em uma pasta de desenvolvimento.
- Um computador com Windows

## Instalação dos componentes

Você vai precisar instalar alguns componentes. Para isso, siga as instruções abaixo, ou [clique aqui](https://delphidabbler.com/install-to-ide) para acessar uma documentação mais detalhada sobre a instalação de componentes no Delphi.

### CnWizards

Instação opcional. Serve para deixar o código com uma aparência mais organizada. Navegue até a pasta `/components/CnWizards`, e execute o arquivo ".exe" dentro dela.

### BusinessSkinForm

#### Instalação

1. Abra o RAD Studio e no menu "File", selecione "Open".
2. Navegue até a pasta `/components/bsfd102tokyo` deste repositório e selecione o arquivo `bsfd102Tokyo.dpk`. A IDE vai pedir para converter o pacote; aceite.
3. O pacote será exibido em seu Project Manager (normalmente a porção direita da tela) sob o nome `bsfd102Tokyo.bpl`. Clique com o botão direito nesse projeto e clique em "Install".
4. Após instalado, pode fechar o projeto.

#### Adicionando o Caminho

1. Vá para o menu "Tools" na parte superior da janela da IDE.
2. Selecione "Options" no menu suspenso.
3. Na janela de opções, no painel esquerdo, expanda a seção "Environment Options".
4. Clique em "Delphi Options" para expandir ainda mais as opções.
5. Selecione a opção "Library".
6. No lado direito da janela, você verá a seção "Library path". Clique no botão "..." à direita da caixa de edição.
7. Na janela de edição de diretório, clique no ícone da pastinha, navegue até o diretório do componente `/components/bsfd102tokyo`, e clique em "Selecionar Pasta".
8. Clique em "Add", e em seguida, em "Ok".

### PNGComponents

1. Abra o RAD Studio e no menu "File", selecione "Open".
2. Navegue até a pasta `/components/PngComponents/PackagesAthens` deste repositório e selecione o arquivo `PngComponentsDesign.dpk`.
3. O pacote será exibido em seu Project Manager (normalmente a porção direita da tela) sob o nome `PngComponentsDesign290.bpl`. Clique com o botão direito nesse projeto e clique em "Install".
4. Após instalado, pode fechar o projeto.

## Vídeo do YouTube na liturgia

O player do programa é um iframe: sem internet ele não abre. Para ter o vídeo
disponível no culto, baixe o arquivo por fora e aponte o item para ele.

1. No card do item da liturgia, clique no botão com a seta e escolha o arquivo
   de vídeo no computador. A seta fica verde quando o arquivo está definido;
   ao lado dele, o botão do YouTube abre a página do vídeo.
2. Sem internet, ao executar o item, o arquivo escolhido é reproduzido no mesmo
   monitor e em tela cheia, igual ao vídeo online.

O player interno usa MCI, que depende dos codecs instalados no Windows e
normalmente não abre VP9 nem AV1: prefira MP4 com H.264 e áudio AAC.

Baixar vídeos do YouTube contraria os Termos de Serviço da plataforma, salvo
conteúdo próprio ou de licença livre. A escolha é de quem usa o programa.

## Execução do Programa

### Altere a pasta de build do projeto

1. No RAD Studio, selecione o menu File > Open e abra o arquivo "LouvorJA.dproj" deste repositório.
2. No menu superior Project, selecione "Options..."
3. Na aba "Delphi Compiler", selecione a opção "Output directory" (não é necessário expandir a opção) e selecione a pasta onde está o executável do programa, copiado para o diretório de desenvolvimento, conforme seção "Requisitos".
4. Confira que a configuração escolhida na barra do Project Manager é a mesma em que você alterou o "Output directory" - Debug e Release têm opções separadas.

### Substitua o borlndmm.dll

O programa usa `ShareMem`, e o `borlndmm.dll` que acompanha a instalação oficial é o da versão do Delphi em que ela foi compilada. Copie o `borlndmm.dll` da pasta `bin` do seu RAD Studio (por exemplo `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin`) por cima do que está no diretório de desenvolvimento.

---

Após seguir esses passos, você provavelmente já conseguirá executar o LouvorJA no modo de desenvolvedor, a partir do código, em sua máquina, e trabalhar em melhorias. Esses passos foram desenvolvidos para se executar na versão 13 (Florence) do Delphi, e podem não funcionar em outras versões. Na Community Edition a compilação só acontece pela IDE - `dcc32` e `msbuild` na linha de comando são bloqueados pela licença.
