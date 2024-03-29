@* Música.

No capítulo 9 criamos código para poder tocar efeitos sonoros no
computador. Entretanto, o mesmo código não pode ser usado para tocar
músicas ou arquivos de áudio muito longos. Primeiro porque com o que
foi feito no capítulo 9, nós só somos capazes de tocar áudio no
formato WAVE, sem compactação. Tais arquivos ficam grandes demais para
músicas. Segundo porque o código do capítulo 9 copia todo o conteúdo do
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

Músicas e efeitos deste tipo devem rodar em threads no caso de
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
muitos problemas com patentes, mas que é universalmente suportado. Mas
para mim, o grande problema são os navegadores de Internet, os quais
nem sempre suportam o formato Ogg Vorbis. Além disso, como as patentes
do formato estão morrendo, aparentemente elas não causarão mais
problemas. Sendo assim, a biblioteca escolhida para rodar nativamente
será a mpg123.

@(project/src/weaver/conf_end.h@>+=
// Por padrão, teremos só uma faixa de áudio:
#ifndef W_MAX_MUSIC
#define W_MAX_MUSIC 1
#endif
@

Como usamos o libmpg123 e semáforos:

@<Som: Declarações@>+=
#if W_TARGET == W_ELF
#include <pthread.h>
#include <semaphore.h>
#ifndef W_DISABLE_MP3
#include <mpg123.h>
#endif
#endif
@


Vamos implementar nossa própria função |basename| para funcionar
quando o Emscripten não suportar ela:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_WEB
static char *basename(char *path){
  char *p = path, *c;
  for(c = path; *c != '\0'; c ++)
    if(*c == '/' && *(c+1) != '\0')
      p = c + 1;
  return p;
}
#endif
@

A estrutura de dados que armazenará as informações para cada faixa de
música será:

@<Som: Declarações@>+=
struct _music_data{
    char filename[W_MAX_SUBLOOP][256];
    int status[W_MAX_SUBLOOP]; // Playing, not playing, paused or closing
    float volume[W_MAX_SUBLOOP];
    bool loop[W_MAX_SUBLOOP];
#if W_TARGET == W_ELF
    unsigned char *buffer;
    size_t buffer_size;
    // Para as threads:
    pthread_t thread;
    sem_t semaphore;
#ifndef W_DISABLE_MP3
    // Para decodificar MP3:
    mpg123_handle *mpg_handle;
#endif
    // Para lidar com o OpenAL:
    ALuint sound_source, openal_buffer[2];
#endif
};
@

E declaramos o nosso array dessas estruturas:

@<Som: Declarações@>+=
extern struct _music_data _music[W_MAX_MUSIC];
#ifdef W_MULTITHREAD
  // Mutex para quando formos mudar as variáveis que mudam o
  // comportamento das threads responsáveis pela música:
extern pthread_mutex_t _music_mutex;
#endif
@
@<Som: Variáveis Estáticas@>+=
struct _music_data _music[W_MAX_MUSIC];
#ifdef W_MULTITHREAD
  // Mutex para quando formos mudar as variáveis que mudam o
  // comportamento das threads responsáveis pela música:
pthread_mutex_t _music_mutex;
#endif
@

Para preenchermos a variável |status|, vamos definir as seguintes
macros:

@<Som: Declarações@>+=
#define _NOT_LOADED 0
#define _PLAYING    1
#define _PAUSED     2
#define _CLOSED     3 // Closing the program
@

E inicializamos a estrutura:

@<Som: Inicialização@>+=
{
  int i, j;
#if W_TARGET == W_ELF
#ifndef W_DISABLE_MP3
  int ret;
  mpg123_init();
#endif
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
    _music[i].mpg_handle = mpg123_new(NULL, &ret);
    if(_music[i].mpg_handle == NULL){
      fprintf(stderr, "WARNING: MP3 handling failed.\n");
    }
    _music[i].buffer_size = mpg123_outblock(_music[i].mpg_handle);
    _music[i].buffer = (unsigned char *) Walloc(_music[i].buffer_size);
#endif
    for(j = 0; j < W_MAX_SUBLOOP; j ++){
      _music[i].volume[j] = 0.5;
      _music[i].status[j] = _NOT_LOADED;
      _music[i].filename[j][0] = '\0';
#if W_TARGET == W_ELF
      alGenSources(1, &_music[i].sound_source);
      alGenBuffers(2, _music[i].openal_buffer);
      if(alGetError() != AL_NO_ERROR){
        fprintf(stderr, "WARNING: Error generating music buffer.\n");
      }
#endif
    }
  }
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&_music_mutex, NULL) != 0){
    perror("Initializing music mutex:");
    exit(1);
  }
#endif
}
@

Não esqueçamos a finalização. Finalizamos os possíveis mutex e
estruturas do mpg123:

@<Som: Primeira Finalização@>+=
#if W_TARGET == W_ELF
{
  int i;
  for(i = W_MAX_MUSIC - 1; i >= 0; i --){
#ifndef W_DISABLE_MP3
    mpg123_close(_music[i].mpg_handle);
    mpg123_delete(_music[i].mpg_handle);
#endif
    alDeleteSources(1, &_music[i].sound_source);
    alDeleteBuffers(2, _music[i].openal_buffer);
#ifndef W_DISABLE_MP3
    Wfree(_music[i].buffer);
#endif
  }
#ifndef W_DISABLE_MP3
  mpg123_exit();
#endif
}
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_destroy(&_music_mutex);
#endif
@

Como iremos usar o OpenAL para tocar o som, temos também que destruir
a fonte de som atual caso troquemos o dispositio usado para tocar:

@<Som: Antes de Trocar de Dispositivo@>+=
#if W_TARGET == W_ELF
{
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
    alGenSources(1, &_music[i].sound_source);
  }
}
#endif
@

E depois de fazermos a troca de dispositivo, geramos novamente a fonte
de som:

@<Som: Após Trocar de Dispositivo@>=
#if W_TARGET == W_ELF
{
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
    alDeleteSources(1, &_music[i].sound_source);
  }
}
#endif
@

Vamos começar a programar as funções que irão controlar a música do
jogo. Tais funções funcionarão apenas ajustando variáveis. Quem irá
efetivamente fazer o trabalho são as threads que programaremos depois
e que terão a responsabilidade de checar as variáveis. A primeira será
a função que passa a tocar uma música. Ela deve ser invocada como
|W.play_music("o_fortuna.mp3", true)|. O segundo argumento só diz se a
música dee tocar em um loop ou não. Então ela terá a assinatura:

@<Som: Declarações@>+=
bool _play_music(char *, bool);
@

A função funcionará achando uma thread disponível que não está tocando
nada e colocando a música passada como argumento para tocar:

@<Som: Definições@>+=
bool _play_music(char *name, bool loop){
  int i;
  bool success = false;
  size_t path_length = 0;
  size_t name_length = strlen(name);
  // Antes de assumir que ainda não temos a música rodando, vamos ver
  // se ela já não existe e não está tocando, ainda que esteja
  // pausada:
  if(_resume_music(name))
    return true;
  // Se não retornamos, temos que passar a tocar uma nova música
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(_music[i].status[_number_of_loops] == _NOT_LOADED){
#if W_TARGET == W_WEB
      // Se rodando na web, não há threads, apenas tocamos a música.
      EM_ASM_({
          document["music" + $0] = new Audio("music/" + Pointer_stringify($1));
          document["music" + $0].volume = 0.5;
          if($2){
            document["music" + $0].loop = true;
          }
          document["music" + $0].play();
          }, i, name, loop);
#endif
      _music[i].volume[_number_of_loops] = 0.5;
      // Gerando o caminho do arquivo da música:
      _music[i].filename[_number_of_loops][0] = '\0';
#if W_DEBUG_LEVEL == 0
      path_length = strlen(W_INSTALL_DATA);
      memcpy(_music[i].filename[_number_of_loops], W_INSTALL_DATA,
	     path_length + 1);
      memcpy(&_music[i].filename[_number_of_loops][path_length], "/", 2);
      path_length ++;
#endif
      if(path_length + name_length > 249){
	fprintf(stderr, "WARNING: Path is too long: %smusic/%s",
		_music[i].filename[_number_of_loops], name);
	break;
      }
      memcpy(&_music[i].filename[_number_of_loops][path_length], "music/", 7);
      path_length += 6;
      memcpy(&_music[i].filename[_number_of_loops][path_length], name,
	     name_length);
      success = true;
      if(_music[i].status[_number_of_loops] != _PLAYING){
        _music[i].status[_number_of_loops] = _PLAYING;
        _music[i].loop[_number_of_loops] = loop;
#if W_TARGET == W_ELF
      // Liberamos o semáforo para que a thread possa tocar:
        sem_post(&(_music[i].semaphore));
#endif
      }
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
#ifdef W_DISABLE_MP3
  return success && false;
#else
  return success;
#endif
}
@

E adicionando à estrutura |W|:

@<Funções Weaver@>+=
  bool (*play_music)(char *, bool);
@
@<API Weaver: Inicialização@>+=
  W.play_music = &_play_music;
@

Uma vez que podemos tocar uma música, podemos querer também pausar
ela. Para isso, a assinatura da função para pausar será:

@<Som: Declarações@>+=
  bool _pause_music(char *);
@

Note que da mesma forma, tudo oque a função de pausar fará será
ajustar variáveis que depois serão consultadas pelas threads. As
threads terão a responsabilidade de checar quando essas variáveis são
modificadas:

@<Som: Definições@>+=
bool _pause_music(char *name){
  int i;
  bool success = false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(!strcmp(name, basename(_music[i].filename[_number_of_loops])) &&
       _music[i].status[_number_of_loops] == _PLAYING){
#if W_TARGET == W_WEB
      // Se rodando na web, não há threads, apenas pausamos a música.
      EM_ASM_({
          if(document["music" + $0] !== undefined){
            document["music" + $0].pause();
          }
        }, i);
#endif
      _music[i].status[_number_of_loops] = _PAUSED;
      success = true;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
#ifdef W_DISABLE_MP3
  return success && false;
#else
  return success;
#endif
}
@

E adicionamos à estrutura |W|:

@<Funções Weaver@>+=
  bool (*pause_music)(char *);
@
@<API Weaver: Inicialização@>+=
  W.pause_music = &_pause_music;
@

Agora que sabemos o que acontece quando pausamos, vamos definir o
|_resume_music|, que nós não exportaremos, mas usaremos internamente:

@<Som: Declarações@>+=
  bool _resume_music(char *);
@

@<Som: Definições@>+=
bool _resume_music(char *name){
  int i;
  bool success = false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(!strcmp(name, basename(_music[i].filename[_number_of_loops])) &&
       _music[i].status[_number_of_loops] == _PAUSED){
#if W_TARGET == W_WEB
      // Se rodando na web, não há threads, apenas recomeçamos a música.
      EM_ASM_({
          if(document["music" + $0] !== undefined){
            document["music" + $0].play();
          }
          }, i);
#endif
      _music[i].status[_number_of_loops] = _PLAYING;
#if W_TARGET == W_ELF
      // Liberamos o semáforo para que a thread possa voltar a tocar:
      sem_post(&(_music[i].semaphore));
#endif
      success = true;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
#ifdef W_DISABLE_MP3
  return success && false;
#else
  return success;
#endif
}
@

Também pediremos para parar de tocar a música. Isso será equivalente a
liberar a faixa de música para que ela possa tocar outras coisas:

@<Som: Declarações@>+=
  bool _stop_music(char *);
@

E a definição:

@<Som: Definições@>+=
bool _stop_music(char *name){
  int i;
  bool success = false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(!strcmp(name, basename(_music[i].filename[_number_of_loops]))){
#if W_TARGET == W_WEB
      // Se rodando na web, não há threads, apenas pausamos e
      // removemos a música.
      EM_ASM_({
          if(document["music" + $0] !== undefined){
            document["music" + $0].pause();
            document["music" + $0] = undefined;
          }
        }, i);
#endif
      _music[i].filename[_number_of_loops][0] = '\0';
      _music[i].status[_number_of_loops] = _NOT_LOADED;
#if W_TARGET == W_ELF
      // Liberamos o mutex caso a thread tenha sido pausada
      if(_music[i].status[_number_of_loops] == _PAUSED)
          sem_post(&(_music[i].semaphore));
#endif
      success = true;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
#ifdef W_DISABLE_MP3
  return success && false;
#else
  return success;
#endif
}
@

Adicionando à |W|:

@<Funções Weaver@>+=
  bool (*stop_music)(char *);
@
@<API Weaver: Inicialização@>+=
  W.stop_music = &_stop_music;
@

E por fim a função para encerrar todas as thread que tocam as músicas antes
do programa encerrar:

@<Som: Declarações@>+=
bool _close_music(void);
@

E a definição:

@<Som: Definições@>+=
bool _close_music(void){
  int i;
  bool success = false;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    _music[i].filename[_number_of_loops][0] = '\0';
    _music[i].status[_number_of_loops] = _CLOSED;
#if W_TARGET == W_ELF
      // Liberamos o mutex para a thread funcionar e poder encerrar
    sem_post(&(_music[i].semaphore));
#endif
  }
  success = true;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
#ifdef W_DISABLE_MP3
  return success && false;
#else
  return success;
#endif
}
@


Outra coisa importante será obter informações sobre o volume:

@<Som: Declarações@>+=
float _get_volume(char *);
@

Se obtivermos um valor negativo, significa que a música indicada não
existe. Já um valor entre 0 e 1 representa o volume atual daquela
música:

@<Som: Definições@>+=
float _get_volume(char *name){
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(!strcmp(name, _music[i].filename[_number_of_loops])){
      return _music[i].volume[_number_of_loops];
    }
  }
  return -1.0;
}
@

E adicionamos à estrutura |W|:

@<Funções Weaver@>+=
  float (*get_volume)(char *);
@
@<API Weaver: Inicialização@>+=
  W.get_volume = &_get_volume;
@

E forneceremos também a API para incrementar o volume a quantidade
passada como argumento (até o máximo de 1). Para decrementar, pode-se
passar um número negativo (mas o mínimo será 0):

@<Som: Declarações@>+=
float _increase_volume(char *, float);
@

A função funciona apenas mudando a variável, confiando que a thread
notará que o valor do volume foi modificado. Ou, se estivermos rodando
na web, o valor é modificado na hora. Esta função deve retornar o
volume após a mudança, ou -1.0 se a operação não foi bem-sucedida:

@<Som: Definições@>+=
float _increase_volume(char *name, float increment){
  int i;
  float success = -1.0, total;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(!strcmp(name, basename(_music[i].filename[_number_of_loops]))){
      total = _music[i].volume[_number_of_loops] + increment;
      if(total > 1.0)
        _music[i].volume[_number_of_loops] = 1.0;
      else if(total < 0.0)
        _music[i].volume[_number_of_loops] = 0.0;
      else _music[i].volume[_number_of_loops] = total;
#if W_TARGET == W_WEB
      // Se rodando na web, não há threads, apenas atualizamos o
      // volume:
      EM_ASM_({
          if(document["music" + $0] !== undefined){
            document["music" + $0].volume = $0;
          }
        }, _music[i].volume[_number_of_loops]);
#endif
      success = _music[i].volume[_number_of_loops];
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
#ifdef W_DISABLE_MP3
  return success && false;
#else
  return success;
#endif
}
@

E adicionando a estrutura |W|:

@<Funções Weaver@>+=
  float (*increase_volume)(char *, float);
@
@<API Weaver: Inicialização@>+=
  W.increase_volume = &_increase_volume;
@

Terminamos de criar nossa API de controle de música. Como já
escrevemos a sua inicialização, sabemos que nosso programa irá começar
em um estado correto e inicializado. Ao entrarmos em um novo loop,
receberemos um estado limpo na estrutura de dados de nossa música. Mas
temos que garantir que ao sair de um loop ou ao mudar o nosso loop
atual, faremos nossa parte limpando e deixando as informações de
música inicializadas como antes.

Isso é o que faremos após um subloop encerrar e retornar o controle
para o seu loop pai:

@<Código após sairmos de Subloop@>+=
{
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
#if W_TARGET == W_WEB
    // Se rodando na web, não há threads, paramos imediatamente as
    // músicas atuais:
    EM_ASM_({
        if(document["music" + $0] !== undefined){
          document["music" + $0].pause();
          document["music" + $0] = undefined;
        }
      }, i);
#else
    if(_music[i].status[_number_of_loops] == _PLAYING){
      // Reservamos o semáforo para fazer a thread parar de tocar:
      sem_wait(&(_music[i].semaphore));
    }
#endif
    _music[i].volume[_number_of_loops] = 0.5;
    _music[i].status[_number_of_loops] = _NOT_LOADED;
    _music[i].filename[_number_of_loops][0] = '\0';
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
}
@

E temos a mesma coisa a fazer não só quando retornamos de um subloop,
as também quando estamos prestes a substituir o loop atual por outro:

@<Código antes de Loop, mas não de Subloop@>+=
{
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
#if W_TARGET == W_WEB
    // Se rodando na web, não há threads, paramos imediatamente as
    // músicas atuais:
    EM_ASM_({
        if(document["music" + $0] !== undefined){
          document["music" + $0].pause();
          document["music" + $0] = undefined;
        }
      }, i);
#else
    if(_music[i].status[_number_of_loops] == _PLAYING){
      // Reservamos o semáforo para fazer a thread parar de tocar:
      sem_wait(&(_music[i].semaphore));
    }
#endif
    _music[i].volume[_number_of_loops] = 0.5;
    _music[i].status[_number_of_loops] = _NOT_LOADED;
    _music[i].filename[_number_of_loops][0] = '\0';
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
}
@

Mas também temos que nos atentar ao entrar em um novo subloop. Nesses
casos, se rodamos nativamente, as nossas threads de música devem ser
capazes de perceber a mudança e se comportar de acordo, mas ainda
temos que bloquear o semáforo para fazê-las parar. Já se estamos
executando na web, temos que parar as músicas atuais explicitamente:

@<Código antes de Subloop@>+=
{
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
#if W_TARGET == W_WEB
    EM_ASM_({
        if(document["music" + $0] !== undefined){
          document["music" + $0].pause();
          document["music" + $0] = undefined;
        }
      }, i);
#else
    if(_music[i].status[_number_of_loops - 1] == _PLAYING){
      // Reservamos o semáforo para fazer a thread parar de tocar:
      sem_wait(&(_music[i].semaphore));
    }
#endif
  }
}
@

Ainda no caso de música no caso da web, como não temos threads, ao
sair de um subloop, antes de começar a executar o mesmo loop, temos
que continuar a tocar as músicas que tocavam nele antes. E se estamos
rodando nativamente, temos que liberar os semáforos neste caso:

@<Código Imediatamente antes de Loop Principal@>+=
{
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
#if W_TARGET == W_WEB
    EM_ASM_({
        if(document["music" + $0] !== undefined){
          document["music" + $0].play();
        }
      }, i);
#else
    if(_music[i].status[_number_of_loops] == _PLAYING){
      sem_post(&(_music[i].semaphore));
    }
#endif
  }
}
@

E finalmente, nós temos que iniciar as threads na inicialização caso
estejamos rodando nativamente:

@<Som: Inicialização@>+=
#if W_TARGET == W_ELF
{
  int i;
  int ret;
  for(i = 0; i < W_MAX_MUSIC; i ++){
    // Criamos um semáforo que começa bloqueado:
    ret = sem_init(&(_music[i].semaphore), 0, 0);
    if(ret == -1){
      perror("sem_init");
    }
#ifndef W_DISABLE_MP3
    ret = pthread_create(&(_music[i].thread), NULL, &_music_thread,
                         &(_music[i]));
    if(ret != 0){
      fprintf(stderr, "WARNING (0): Can't create music threads. "
              "Music may fail to play.");
      break;
    }
#endif
  }
}
#endif
@

E durante o encerramento, enviamos um sinal para cancelar cada uma
das threads de música e destruir seus semáforos:

@<Som: Finalização@>+=
#if W_TARGET == W_ELF
  _close_music();
#endif
@

Vamos ao trabalho da thread de música. Essa thread deve passar por um
semáforo que só estará livre quando houver uma música para ser tocada
e ela não estiver pausada. Para entender o trabalho esta thread,
devemos lembrar que ela tanto deve tocar a música como ficar atenta a
qualquer mensagem que diz para ela parar, pausar ou continuar a
música. Além disso, ela deve estar atenta para mudanças e loops. O
código para ela será:

@<Som: Declarações@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
void *_music_thread(void *);
#endif
@
@<Som: Definições@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
void *_music_thread(void *arg){
  // Nossa struct de música exclusiva para a thread:
  struct _music_data *music_data = (struct _music_data *) arg;
  // O loop em que estávamos última vez que checamos
  int last_loop = _number_of_loops;
  // O volume da última vez que vimos
  float last_volume = music_data -> volume[last_loop];
  // Informações técnicas do formato da música e MP3:
  int current_format = 0xfff5;
  size_t size;
  long rate;
  int channels, encoding, bits;
sem_musica_nenhuma: // Se paramos ou nunca começamos a tocar
  while(music_data -> status[_number_of_loops] == _NOT_LOADED)
      sem_wait(&(music_data -> semaphore));
  if(music_data -> status[_number_of_loops] == _CLOSED)
    goto encerrando_thread;
  // Se saímos do loop acima, é porque temos uma nova música a tocar:
  if(!_music_thread_prepare_new_music(music_data, &rate, &channels, &encoding,
                                      &bits, &current_format, &size)){
      // Se carregar a música falhar, desistimos de tocar
      music_data -> status[_number_of_loops] = _NOT_LOADED;
      fprintf(stderr, "Error opening %s\n",
              music_data -> filename[last_loop]);
      goto sem_musica_nenhuma;
  }
tocando_musica:
  if(!_music_thread_play_music(music_data, rate, current_format, size)){
      // Se estamos aqui, a música terminou
      _music_thread_end_music(music_data);
      if(music_data -> loop[last_loop]){
          // A música eve tocar em loop, vamos recomeçar de novo
          _music_thread_prepare_new_music(music_data, &rate, &channels, &encoding,
                                          &bits, &current_format, &size);
          goto tocando_musica;
      }
      else{
          music_data -> status[_number_of_loops] = _NOT_LOADED;
          goto sem_musica_nenhuma;
      }
  }
  // Checando por mudança de loop
  if(last_loop != _number_of_loops){
      last_loop = _number_of_loops;
      if(music_data -> status[_number_of_loops] == _NOT_LOADED)
          goto sem_musica_nenhuma;
      if(music_data -> status[_number_of_loops] == _CLOSED)
	goto encerrando_thread;
  }
  // E por mudança de volume
  else if(last_volume != music_data -> volume[_number_of_loops]){
      _music_thread_update_volume(music_data);
      last_volume = music_data -> volume[_number_of_loops];
  }
  // Por ela sendo pausada:
  else if(music_data -> status[_number_of_loops] == _PAUSED){
      alSourcePause(music_data -> sound_source);
      // Fica preso no semáforo até algém soltar
      while(music_data -> status[_number_of_loops] == _PAUSED)
          sem_wait(&(music_data -> semaphore));
      // E retoma após sair:
      alSourcePlay(music_data -> sound_source);
  }
  // E pela música sendo parada
  if(music_data -> status[_number_of_loops] == _NOT_LOADED){
      // Música foi parada
      _music_thread_interrupt_music(music_data);
      goto sem_musica_nenhuma;
  }
  // E por tudo sendo encerrado
  if(music_data -> status[_number_of_loops] == _CLOSED)
    goto encerrando_thread;
  goto tocando_musica;
 encerrando_thread:
  sem_destroy(&(music_data -> semaphore));
  return NULL;
}
#endif
@

Uma thread sempre irá preparar uma nova música executando a seguinte função:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
bool _music_thread_prepare_new_music(struct _music_data *music_data,
                                     long *rate, int *channels, int *encoding,
                                     int *bits, int *current_format,
                                     size_t *size){
    *current_format = 0xfff5;
    if(mpg123_open(music_data -> mpg_handle,
                   music_data -> filename[_number_of_loops]) != MPG123_OK)
        return false;
    mpg123_getformat(music_data -> mpg_handle, rate, channels, encoding);
    *bits = mpg123_encsize(*encoding) * 8;
    if(*bits == 8){
        if(*channels == 1) *current_format = AL_FORMAT_MONO8;
        else if(*channels == 2) *current_format = AL_FORMAT_STEREO8;
    } else if(*bits == 16){
        if(*channels == 1) *current_format = AL_FORMAT_MONO16;
        else if(*channels == 2) *current_format = AL_FORMAT_STEREO16;
    }
    if(*current_format == 0xfff5)
        return false;
    // Tudo certo, preenchendo o buffer inicial:
    mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                music_data -> buffer_size, size);
    alBufferData(music_data -> openal_buffer[0],
                 *current_format, music_data -> buffer,
                 (ALsizei) *size, *rate);
    mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                music_data -> buffer_size, size);
    alBufferData(music_data -> openal_buffer[1],
                 *current_format, music_data -> buffer,
                 (ALsizei) *size, *rate);
    alSourceQueueBuffers(music_data -> sound_source, 2,
                         music_data -> openal_buffer);
    alSourcef(music_data -> sound_source, AL_GAIN,
              music_data -> volume[_number_of_loops]);
    alSourcePlay(music_data -> sound_source);
    return true;
}
#endif
@

Já quando estiver tocando uma música, a thread sempre usará esta função:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
bool _music_thread_play_music(struct _music_data *music_data,
                              long rate, int current_format, size_t size){
    int buffers, ret;
    ALuint buf;
    // Se a música estiver pausada ou foi interrompida, não precisa continuar
    if(music_data -> status[_number_of_loops] != _PLAYING)
        return true;
    // Checar se há buffers prontos pra tocar mais:
    alGetSourcei(music_data -> sound_source, AL_BUFFERS_PROCESSED, &buffers);
    if(!buffers)
        return true;
    alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
    ret = mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                      music_data -> buffer_size,  &size);
    if(ret == MPG123_OK){
        alBufferData(buf, current_format, music_data -> buffer,
                     (ALsizei) size, rate);
        alSourceQueueBuffers(music_data -> sound_source, 1, &buf);
    }
    else if(ret == MPG123_DONE)
        return false;
    return true;
}
#endif
@

Esta é a função que as threads usarão para finaliar suas músicas:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
void _music_thread_end_music(struct _music_data *music_data){
    ALuint buf;
    ALint stat;
    int ret;
    // Esperar de terminar de tocar.
    do{
        alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
        ret = alGetError();
    }while(ret == AL_INVALID_VALUE);
    do{
        alGetSourcei(music_data -> sound_source, AL_SOURCE_STATE, &stat);
    }while(stat == AL_PLAYING);
    // Encerrando
    mpg123_close(music_data -> mpg_handle);
}
#endif
@

E as threads usarão isso para interromper uma música:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
void _music_thread_interrupt_music(struct _music_data *music_data){
    ALuint buf;
    ALint stat;
    int ret;
    mpg123_close(music_data -> mpg_handle);
    alSourceStop(music_data -> sound_source);
    do{
        alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
        ret = alGetError();
    }while(ret == AL_INVALID_VALUE);
    do{
        alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
        ret = alGetError();
    }while(ret == AL_INVALID_VALUE);
    do {
        alGetSourcei(music_data -> sound_source, AL_SOURCE_STATE, &stat);
    } while(stat == AL_PLAYING);
}
#endif
@

E finalmente, a função para as threads atualizarem o volume:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_ELF && !defined(W_DISABLE_MP3)
void _music_thread_update_volume(struct _music_data *music_data){
    alSourcef(music_data -> sound_source, AL_GAIN,
              music_data -> volume[_number_of_loops]);
}
#endif
@

@*1 Integrando o MP3 à Efeitos Sonoros.

No capítulo sobre o som e efeitos sonoros, nós estivemos extraindo som
no formato WAVE para rodar nossos efeitos sonoros. Mas agora que
adicionamos o suporte à MP3 para músicas, podemos também decodificar
efeitos sonoros no formato MP3. Isso permitirá que nossos efeitos
sonoros possam também se beneficiar da compressão do formato MP3 (que
não é lá essas coisas, mas é muito melhor que nada como no caso WAVE).

Para podermos fazer isso, primeiro temos que checar se o efeito sonoro
que recebemos tem uma extensão MP3:

@<Som: Extrai outros Formatos@>=
#ifndef W_DISABLE_MP3
else if(!strcmp(ext, ".mp3") || !strcmp(ext, ".MP3")){ // Suportando .mp3
  @<Som: Extraindo MP3@>
}
#endif
@

Extrair o MP3 para um buffer requer que primeiro saibamos qual o
tamanho do buffer que precisamos para manter todo o efeito sonoro na
memória. Usando a função |mpg123_outblock|, obtemos o tamanho máximo
de um ``frame'' do áudio. Para tocar a música, usamos isso para
determinar o tamanho de nosos buffer. Aqui, usaremos o valor para
gerar o buffer inicial e tentamos ler o áudio. Se lemos tudo,
paramos. Caso contrário, descartamos a leitura, reiniciamos a
interpretação do arquivo, mas após termos dobrado o tamanho do
buffer. Continuamos até conseguirmos:

@<Som: Extraindo MP3@>=
int current_format = 0xfff5;
size_t buffer_size;
unsigned char *buffer = NULL;
ALuint openal_buffer = 0;
ret = false;
{
  int test;
  size_t decoded_bytes;
  mpg123_handle *mpg_handle = mpg123_new(NULL, &test);
  buffer_size = mpg123_outblock(mpg_handle);
  for(;;){
    // Abrimos arquivo
    test = mpg123_open(mpg_handle, complete_path);
    if(test != MPG123_OK){
      fprintf(stderr, "Warning: Error opening %s\n", complete_path);
      buffer_size = 0;
      ret = true;
      break;
    }
    // Lendo o formato
    if(current_format  == 0xfff5){
      int channels, encoding, bits;
      long rate;
      mpg123_getformat(mpg_handle, &rate, &channels, &encoding);
      bits = mpg123_encsize(encoding) * 8;
      snd -> freq = rate;
      snd -> channels = channels;
      snd -> bitrate = bits;
      if(bits == 8){
        if(channels == 1) current_format = AL_FORMAT_MONO8;
        else if(channels == 2) current_format = AL_FORMAT_STEREO8;
      } else if(bits == 16){
        if(channels == 1) current_format = AL_FORMAT_MONO16;
        else if(channels == 2) current_format = AL_FORMAT_STEREO16;
      }
      if(current_format == 0xfff5){
        fprintf(stderr,
                "WARNING(0): Combination of channel and bitrate not "
                "supported in file %s (sound have %d channels and %d bitrate"
                " while "
                "we support just 1 or 2 channels and 8 or 16 as "
                "bitrate).\n",
                complete_path, channels, bits);
      }
    }
    // Criando e preenchendo o buffer:
    buffer = (unsigned char *) Walloc(buffer_size);
    if(buffer == NULL){
      fprintf(stderr, "ERROR: Not enough memory to load %s. Please, "
              "increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              complete_path);
      buffer_size = 0;
      ret = true;
      break;
    }
    test = mpg123_read(mpg_handle, buffer, buffer_size, &decoded_bytes);
    mpg123_close(mpg_handle);
    // Se não conseguimos copiar tudo, prepare próxima iteração:
    if(decoded_bytes > buffer_size){
      Wfree(buffer);
      buffer = NULL;
      buffer_size *= 2;
    }
    else break; // Se copiamos tudo, saimos daqui
  }
  // Se tudo deu certo:
  snd -> size = buffer_size;
}
@

Tudo o que fizemos foi extrair o conteúdo do MP3 em um buffer. Mas
temos agora que criar um novo buffer openAL, enviar os dados que
extraímos para ele e então atribuir o buffer gerado para a estrutura
do efeito sonoro:

@<Som: Extraindo MP3@>+=
if(buffer != NULL){
  int status;
  alGenBuffers(1, &openal_buffer);
  status = alGetError();
  if(status != AL_NO_ERROR){
    fprintf(stderr, "WARNING(0)): No sound buffer could be created. "
            "alGenBuffers failed. ");
    if(status == AL_INVALID_VALUE){
      fprintf(stderr, "Internal error: buffer array isn't large enough.\n");
    }
    else if(status == AL_OUT_OF_MEMORY){
      fprintf(stderr, "Internal error: out of memory.\n");
    }
    else{
      fprintf(stderr, "Unknown error (%d).\n", status);
    }
    ret = true;
  }
  else{
    alBufferData(openal_buffer, current_format, buffer, snd -> size,
                 snd -> freq);
    status = alGetError();
    if(status != AL_NO_ERROR){
      fprintf(stderr, "WARNING(0): Can't pass audio to OpenAL. "
              "alBufferData failed. Sound may not work.\n");
      ret = true;
    }
    Wfree(buffer);
    snd -> _data = openal_buffer;
    _finalize_after(&(snd -> _data), _finalize_openal);
  }
}
@

@*1 Sumário das variáveis e Funções de Música.

\macronome As seguintes 5 novas funções foram definidas:

\macrovalor|float W.get_volume(char *filename)|: Se a música no
arquivo passado como argumento está tocando, retorna o seu volume como
um número em ponto flutuante entre 0 e 1. Se não estiver, retorna -1.0;

\macrovalor|float W.increase_volume(char *filename, float increment)|:
Se a música no arquivo passado como argumento está tocando, soma o seu
volume atual com o número passado como argumento (que pode ser negativo
para diminuir o volume). Se o resultado for maior que 1, será tratado
como 1 e se for menor que 0, será tratado como 0. O número retornado é
o novo volume após a mudança.

\macrovalor|bool W.pause_music(char *filename)|: Pausa a música que
está tocando e que está sendo lida do arquivo cujo nome foi passado
como argumento. Retorna se a operação foi bem-sucedida.

\macrovalor|bool W.play_music(char *filename, bool loop)|: Começa a tocar a
música no arquivo cujo nome é passado como argumento. Retorna se a
operação foi bem-sucedida. O segundo argumento indica se a música
deve tocar em loop ou não.

\macrovalor|bool W.stop_music(char *filename)|: Para de tocar a música
que está tocando e sendo lida do arquivo identificado pelo nome
passado como argumento. Retorna se a operação foi bem-sucedida.
