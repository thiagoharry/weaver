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
muitops problemas com patentes, mas que é universalmente
suportado. O grande problema são os navegadores de Internet, os quais
nem sempre suportam o formato. Além disso, como as patentes do formato
estão morrendo, aparentemente elas não causarão mais problemas. Sendo
assim, a biblioteca escolhida para rodar nativamente será a mpg123.

@(project/src/weaver/conf_end.h@>+=
// Por padrão, teremos só uma faixa de áudio:
#ifndef W_MAX_MUSIC
#define W_MAX_MUSIC 1
#endif
@

Como usamos o libmpg123 e semáforos:

@<Som: Declarações@>+=
#if W_TARGET == W_ELF
#include <mpg123.h>
#include <semaphore.h>
#endif
@

  
A estrutura de dados que armazenará as informações para cada faixa de
música será:

@<Som: Declarações@>+=
struct _music_data{
  char filename[W_MAX_SUBLOOP][256];
  int status[W_MAX_SUBLOOP];
  float volume[W_MAX_SUBLOOP];
  bool loop[W_MAX_SUBLOOP];
#if W_TARGET == W_ELF
  unsigned char *buffer;
  size_t buffer_size;
  // Para as threads:
  pthread_t thread;
  sem_t semaphore;
  // Para decodificar MP3:
  mpg123_handle *mpg_handle;
  // Para lidar com o OpenAL:
  ALuint sound_source, openal_buffer[2];
#endif
};
@

E declaramos o nosso array dessas estruturas:

@<Som: Declarações@>+=
extern struct _music_data _music[W_MAX_MUSIC];
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
@

E inicializamos a estrutura:
  
@<Som: Inicialização@>+=
{
  int i, j;
#if W_TARGET == W_ELF
  int ret;
  mpg123_init();
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
#if W_TARGET == W_ELF
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
    mpg123_close(_music[i].mpg_handle);
    mpg123_delete(_music[i].mpg_handle);
    alDeleteSources(1, &_music[i].sound_source);
    alDeleteBuffers(2, _music[i].openal_buffer);
    Wfree(_music[i].buffer);
  }
  mpg123_exit();
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
  // Antes de assumir que ainda não temos a música rodando, vamos ver
  // se ela já não existe e não está tocando, ainda que esteja
  // pausada:
  if(_resume_music(name))
    return true;
  // Se não retornamos, temos que passar a tocar uma noa música
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(_music[i].status[_number_of_loops] == _NOT_LOADED){
#if W_TARGET == W_WEB
      // Se rodando na web, não há threads, apenas tocamos a música.
      EM_ASM_({
          document["music" + $0] = new Audio(Pointer_stringify($1));
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
      strncpy(_music[i].filename[_number_of_loops], W_INSTALL_DATA, 256);
      strcat(_music[i].filename[_number_of_loops], "/");
#endif
      strncat(_music[i].filename[_number_of_loops], "music/",
              256 - strlen(_music[i].filename[_number_of_loops]));
      strncat(_music[i].filename[_number_of_loops], name,
              256 - strlen(_music[i].filename[_number_of_loops]));
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
  return success;
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
#if W_TARGET == W_ELF
      if(_music[i].status[_number_of_loops] == _PLAYING){
        // Reservamos o semáforo para fazer a thread parar de tocar:
        sem_wait(&(_music[i].semaphore));
      }
#endif
      _music[i].status[_number_of_loops] = _PAUSED;
      success = true;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
  return success;
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
#if W_TARGET == W_ELF
      // Liberamos o semáforo para que a thread possa tocar:
        sem_post(&(_music[i].semaphore));
#endif
      _music[i].status[_number_of_loops] = _PLAYING;
      success = true;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
  return success;
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
      if(_music[i].status[_number_of_loops] == _PLAYING){
        // Reservamos o semáforo para fazer a thread parar de tocar:
        sem_wait(&(_music[i].semaphore));
      }
#endif
      success = true;
      break;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_music_mutex);
#endif
  return success;
}
@

Adicionando à |W|:

@<Funções Weaver@>+=
  bool (*stop_music)(char *);
@
@<API Weaver: Inicialização@>+=
  W.stop_music = &_stop_music;
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
  float success = -1.0;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_music_mutex);
#endif
  for(i = 0; i < W_MAX_MUSIC; i ++){
    if(!strcmp(name, _music[i].filename[_number_of_loops])){
      _music[i].volume[_number_of_loops] += increment;
      if(_music[i].volume[_number_of_loops] > 1.0)
        _music[i].volume[_number_of_loops] = 1.0;
      else if(_music[i].volume[_number_of_loops] < 0.0)
        _music[i].volume[_number_of_loops] = 0.0;
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
  return success;
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
    ret = pthread_create(&(_music[i].thread), NULL, &_music_thread,
                         &(_music[i]));
    if(ret != 0){
      fprintf(stderr, "WARNING (0): Can't create music threads. "
              "Music may fail to play.");
      break;
    }
  }
}
#endif
@

E durante o encerramento, enviamos um sinal para cancelar cada uma
das threads de música e destruir seus semáforos:

@<Som: Finalização@>+=
#if W_TARGET == W_ELF
{
  int i;
  for(i = 0; i < W_MAX_MUSIC; i ++){
    sem_destroy(&(_music[i].semaphore));
    pthread_cancel(_music[i].thread);
  }
}
#endif
@

Vamos ao trabalho da thread de música. Essa thread deve passar por um
semáforo que só estará livre quando houver uma música para ser tocada
e ela não estiver pausada. O código para ele será:

@<Som: Declarações@>+=
#if W_TARGET == W_ELF
void *_music_thread(void *);
#endif
@
@<Som: Definições@>+=
#if W_TARGET == W_ELF
void *_music_thread(void *arg){
  struct _music_data *music_data = (struct _music_data *) arg;
  int last_status = music_data -> status[_number_of_loops];
  int last_loop = _number_of_loops;
  int ret;
  int current_format = 0xfff5;
  size_t size;
  long rate;
  int channels, encoding, bits;
  for(;;){
    // Ficamos aqui até ter alguma música para tocar:
    while(music_data -> status[_number_of_loops] != _PLAYING)
      sem_wait(&(music_data -> semaphore));
    if(last_loop != _number_of_loops){
      // Se o loop em que estamos mudou, atualizaremos o status e só
      // faremos algo na próxima iteração. Podemos ter que fechar um
      // arquivo aberto:
      last_loop = _number_of_loops;
      last_status = music_data -> status[last_loop];
    }
    else{
      // Se não mudamos o loop em que estamos, primeiro checamos se há
      // mudança no status:
      if(last_status != music_data -> status[_number_of_loops]){
        // Se o novo status é tocar uma nova música, vamos abrir o
        // arquivo:
        if(music_data -> status[_number_of_loops] == _PLAYING &&
           last_status == _NOT_LOADED){
          last_status = music_data -> status[_number_of_loops];
          ret = mpg123_open(music_data -> mpg_handle,
                      music_data -> filename[last_loop]);
          if(ret != MPG123_OK){
            fprintf(stderr, "Error opening %s\n",
                    music_data -> filename[last_loop]);
            music_data -> status[last_loop] = _NOT_LOADED;
          }
          else{
            mpg123_getformat(music_data -> mpg_handle,
                             &rate, &channels, &encoding);
            bits = mpg123_encsize(encoding) * 8;
            current_format = 0xfff5;
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
                      "supported (sound have %d channels and %d bitrate while "
                      "we support just 1 or 2 channels and 8 or 16 as "
                      "bitrate).\n",
                      channels, bits);
            }
            // Preenchemos nossos buffer inicialmente
            //alcMakeContextCurrent(default_context);
            mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                        music_data -> buffer_size, &size);
            alBufferData(music_data -> openal_buffer[0],
                         current_format, music_data -> buffer,
                         (ALsizei) size, rate);
            mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                            music_data -> buffer_size, &size);
            alBufferData(music_data -> openal_buffer[1],
                         current_format, music_data -> buffer,
                         (ALsizei) size, rate);
            alSourceQueueBuffers(music_data -> sound_source, 2,
                                 music_data -> openal_buffer);
            alSourcePlay(music_data -> sound_source);
          }
        }
        else if(music_data -> status[_number_of_loops] == _PLAYING &&
                last_status == _PAUSED){
          // Voltando a tocar:
          alSourcePlay(music_data -> sound_source);
          last_status = music_data -> status[_number_of_loops];
        }
        else{
          // Atualizando status
          last_status = music_data -> status[_number_of_loops];
        }
      }
      else if(music_data -> status[last_loop] == _PLAYING){
        int buffers;
        // Checar se há buffers prontos pra tocar mais:
        alGetSourcei(music_data -> sound_source, AL_BUFFERS_PROCESSED, &buffers);
        if(buffers){
          ALuint buf;
          alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
          ret = mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                            music_data -> buffer_size, &size);
          if(ret == MPG123_OK){
            alBufferData(buf,
                         current_format, music_data -> buffer,
                         (ALsizei) size, rate);
            alSourceQueueBuffers(music_data -> sound_source, 1, &buf);
          }
          else if(ret == MPG123_DONE){
            // Terminou de extrair o áudio. Esperar de terminar de tocar.
            do{
              alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
              ret = alGetError();
            }while(ret == AL_INVALID_VALUE);
            {
              ALint val;
              do {
                alGetSourcei(music_data -> sound_source, AL_SOURCE_STATE, &val);
              } while(val == AL_PLAYING);
            }
            mpg123_close(music_data -> mpg_handle);
            music_data -> status[last_loop] = _NOT_LOADED;
            // Depois de terminar de esperar, reinicia a música se
            // tiermos que fazer um loop
            if(music_data -> loop[last_loop]){
              ret = mpg123_open(music_data -> mpg_handle,
                                music_data -> filename[last_loop]);
              if(ret != MPG123_OK){
                fprintf(stderr, "Error opening %s\n",
                        music_data -> filename[last_loop]);
              }
              else{
                mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                            music_data -> buffer_size, &size);
                alBufferData(music_data -> openal_buffer[0],
                             current_format, music_data -> buffer,
                             (ALsizei) size, rate);
                mpg123_read(music_data -> mpg_handle, music_data -> buffer,
                            music_data -> buffer_size, &size);
                alBufferData(music_data -> openal_buffer[1],
                             current_format, music_data -> buffer,
                             (ALsizei) size, rate);
                alSourceQueueBuffers(music_data -> sound_source, 2,
                                     music_data -> openal_buffer);
                alSourcePlay(music_data -> sound_source);
                music_data -> status[last_loop] = _PLAYING;
              }
            }
          }
        }
      }
    }
    // Se recebemos comando para pausar, pausamos na hora:
    if(music_data -> status[_number_of_loops] == _PAUSED){
      alSourcePause(music_data -> sound_source);
      last_status = _PAUSED;
    }
    // Recebemos um comando para parar:
    else if(music_data -> status[_number_of_loops] == _NOT_LOADED){
      ALuint buf;
      mpg123_close(music_data -> mpg_handle);
      alSourceStop(music_data -> sound_source);
      last_status = _NOT_LOADED;
      do{
        alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
        ret = alGetError();
      }while(ret == AL_INVALID_VALUE);
      do{
        alSourceUnqueueBuffers(music_data -> sound_source, 1, &buf);
        ret = alGetError();
      }while(ret == AL_INVALID_VALUE);
      {
        ALint val;
        do {
          alGetSourcei(music_data -> sound_source, AL_SOURCE_STATE, &val);
        } while(val == AL_PLAYING);
      }
    }
    // No final liberamos o semáforo para que ele tenha a chance de
    // ser bloqueado pelo programa principal e assim podermos sair:
    sem_post(&(music_data -> semaphore));
  }
}
#endif
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

\macrovalor|bool W.play_music(char *filename)|: Começa a tocar a
música no arquivo cujo nome é passado como argumento. Retorna se a
operação foi bem-sucedida.

\macrovalor|bool W.stop_music(char *filename)|: Para de tocar a música
que está tocando e sendo lida do arquivo identificado pelo nome
passado como argumento. Retorna se a operação foi bem-sucedida.
