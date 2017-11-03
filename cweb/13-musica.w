@* Música.

No capítulo 9 criamos código para poder tocar efeitos sonoros no
computador. Entretanto, o mesmo código não pode ser usado para tocar
músicas ou arquivos de áudio muito longos. Primeiro porque com o que
foi feito no capítulo 9, nós só somos capazes de tocar áudio no
formato WAVE, sem compactação. Tais arquivos ficam grandes demais para
músicas. Segundo porque o código do capítulo 9 copia todo o onteúdo do
áudio para a memória. Para efeitos sonoros simples, isso é ideal. Mas
é algo imprático para áudios longos que gastariam uma quantidade
grande demais de memória.

Se estamos executando nosso jogo em um navegador de internet, é tudo
bem simples. Iremos usar os recursos do próprio navegador para tocar o
nosso áudio. Caso contrário, precisamos de um mecanismo mais
sofisticado.

Queremos tratar a execução de música de uma forma semelhante ao que
criamos para as nossas interfaces. Então deve existir uma macro que
nos diz o número máximo de faixas de áudio que pode existir em um
loop. Essa macro será |W_MAX_MUSIC|.

Para entender a utilidade de tocar mais de uma música ao mesmo tempo,
basta lembrar que não são apenas músicas que podem ser tocadas desta
forma. A dublagem de um jogo e efeitos sonoros também podem. E pode-se
combinar diferentes efeitos sonoros, cada um com suas próprias
informações de volume para obter efeitos como o de sites como o
\monoespaco{https://mynoise.net}.

Músicas e efeitos deste ipo devem rodar em threads no caso de
programas nativos. Mesmo que nas configurações o projeto Weaver esteja
configurado para não usar threads. Tais threads não precisam de mutex,
pois cada uma delas irá interagir apenas lendo e escrevendo em
estruturas de dados próprias e únicas para cada uma delas.

O número de threads necessário é igual a |W_MAX_MUSIC|. Cada uma delas
precisa saber qual o arquivo de áudio que deve tocar, precisa ter um
buffer onde o arquivo é parcialmente carregado para ser enviado para o
OpenAL (se estamos rodando nativamente) e precisa também de um inteiro
que armazena números representando o estado da música (ela pode estar
tocando, pode estar pausada ou não carregada) e outro para o
volume. Tais informações de estado e volume, bem como de nome do
arquivo deve ser local para cada loop principal.

Outra coisa relevante é que formatos de música iremos suportar. Por
mais que eu, autor deste software, queira usar o Ogg Vorbis, irei
começar com o MP3. É um formato ligeiramente inferior que causou
muitops problemas com patentes, mas que é universalmente
suportado. O grande problema são os navegadores de Internet, os quais
nem sempre suportam o formato. Além disso, como as patentes do formato
estão morrendo, aparentemente elas não causarão mais problemas. Sendo
assim, a biblioteca escolhida para rodar nativamente será a mpg123.

Quando vamos ler um arquivo MP3, precisaremos de um buffer para
colocar o que lemos e outro para colocar o áudio extraído dele. O
tamanho do buffer também deverá ser obtido de uma macro, caso
contrário valores razoáveis serão usados por padrão. As macros serão
|W_AUDIO_INPUT_BUFFER| e |W_AUDIO_OUTPUT_BUFFER|. Como já mencionamos
as 3 macros que serão relevantes para nós, vamos preencher seus
valores padrão caso elas não sejam definidas:

@(project/src/weaver/conf_end.h@>+=
// Por padrão, teremos só uma faixa de áudio:
#ifndef W_MAX_MUSIC
#define W_MAX_MUSIC 1
#endif
// Os buffers de áudio tem o mesmo tamanho do usado no programa de
// exemplo na documentação do mpg123:
#ifndef W_AUDIO_INPUT_BUFFER
#define W_AUDIO_INPUT_BUFFER 16384
#endif
#ifndef W_AUDIO_OUTPUT_BUFFER
#define W_AUDIO_OUTPUT_BUFFER 32768
#endif
@

A estrutura de dados que armazenará as informações para cada faixa de
música será:

@<Som: Declarações@>+=
struct _music_data{
  char filename[W_MAX_SUBLOOP][256];
  int status[W_MAX_SUBLOOP];
  float volume[W_MAX_SUBLOOP];
#if W_TARGET = W_ELF
  unsigned char input_buffer[W_AUDIO_INPUT_BUFFER];
  unsigned char output_buffer[W_AUDIO_OUTPUT_BUFFER];
#endif
}
@

E declaramos o nosso array dessas estruturas:

@<Som: Variáveis Estáticas@>+=
static struct _music_data _music[W_MAX_MUSIC];
@

Para preenchermos a variável |status|, vamos definir as seguintes
macros:

@<Som: Variáveis Estáticas@>+=
#define NOT_LOADED 0
#define STOPPED    1
#define PLAYING    2
#define PAUSED     3  
@

E inicializamos a estrutura:
  
@<Som: Inicialização@>+=
{
  int i, j;
  for(i = 0; i < W_MAX_MUSIC i ++){
    for(j = 0 j < W_MAX_SUBLOOP; j ++){
      _music[i].volume[j] = 0.5;
      _music[i].status[j] = NOT_LOADED;
      _music[i].filename[j][0] = '\0';
    }
  }
#if W_TARGET = W_ELF
  mpg123_init();
#endif
}
@

Vamos começar a programar as funções que irão controlar a música do
jogo. Tais funções funcionarão apenas ajustando variáveis. Quem irá
efetivamente fazer o trabalho são as threads que programaremos depois
e que terão a responsabilidade de checar as variáveis. A primeira será
a função que passa a tocar uma música. Ela deve ser invocada como
|W.play_music("o_fortuna.mp3")|. Então ela terá a assinatura:

@<Som: Declarações@>+=
  bool _play_music(char *);
@
