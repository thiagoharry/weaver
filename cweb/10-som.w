@* Suporte Básico ao Som.

Para fornecer o suporte ao som, iremos usar a biblioteca OpenAL. Esta
biblioteca foi criada no ano 2000 pela empresa Loki Entertainment
apara ajudá-la a portar jogos do Windows para Linux. Com o fim da
empresa no ano seguinte, a biblioteca passou a ser mantida por um
tempo por uma comunidade de programadores e ganhou suporte em placas
de som e placas-mãe da NVIDIA. Atualmente foi adotada pela Creative
Technology, uma empresa da Singapura, além de receber atualizações de
outras empresas como a Apple.

A vantagem da biblioteca é o suporte à efeitos sonoros
tridimensionais. Ela ajusta a atenuação do som de acordo com a
distância da fonte emissora e da posição da câmera em um
ambiente virtual em 3D. Além de suportar a simulação de efeitos
físicos como o efeito Doppler.

Por fim, também escreveremos aqui o suporte para sermos capazes de
desalocar estruturas de dados mais sofisticadas ao encerrarmos o loop
atual em que estamos. Isso será importante porque o gerenciador de
memória que usamos até então apenas desaloca a memória alocada em
nossa arena. Mas ela não faz coisas como fechar arquivos abertos ou
avisar alguma outra API que paramos de usar algum recurso.

Mas para começar, a primeira coisa a fazer para usar a biblioteca é
criar um cabeçalho e um arquivo de código C com funções específicas de
som. Nestes arquivos iremos inserir também o cabeçalho OpenAL.

@(project/src/weaver/sound.h@>=
#ifndef _sound_h_
#define _sound_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include <AL/al.h>
#include <AL/alc.h>
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Som: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/sound.c@>=
#include <string.h> // strrchr
#include <sys/stat.h> //mkdir
#include <sys/types.h> //mkdir
#include <time.h> // nanosleep
#include <pthread.h>
#ifdef W_MULTITHREAD
#include <sched.h>
#endif
#include "sound.h"
#include "weaver.h"
// Previne warnings irritantes e desnecessários no Emscripten
#if W_TARGET == W_WEB
extern ALenum alGetError(void);
#endif

@<Som: Variáveis Estáticas@>
@<Som: Funções Estáticas@>
@<Som: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "sound.h"
@

@*1 O Básico de OpenAL.

A primeira coisa que precisamos é inicializar um dispositivo no OpenAL
para poder tocar o nosso som. Pode haver mais de um dispositivo, pois
o computador pode ter mais de uma placa de som ou mais de uma opção de
como produzi-lo. Mas mesmo assim, iremos começar com um dispositivo
padrão, que depois pode ser mudado. O dispositivo que usaremos para
tocar o som será apontado por um ponteiro do tipo |ALCdevice| abaixo:

@<Som: Variáveis Estáticas@>=
static ALCdevice *default_device;
@

Este ponteiro deve ser inicializado na nossa função de
inicialização. Usamos uma chamada para |alcOpenDevice| passando |NULL|
como argumento para começarmos com o dispositivo padrão. A função
retornará |NULL| se não existir qualquer dispositivo de áudio. Assim
saberemos que se a variável |default_device| for um ponteiro para
|NULL|, então estamos em um sistema sem som:

@<Som: Declarações@>=
void _initialize_sound(void);
@

@<Som: Definições@>=
void _initialize_sound(void){
    default_device = alcOpenDevice(NULL);
    if(default_device == NULL)
        fprintf(stderr, "WARNING (0): No sound device detected.\n");
    @<Som: Inicialização@>
AFTER_SOUND_INITIALIZATION:
    return;
}
@

Mas além disso, no fim do nosso programa temos que encerrar tudo o que
foi inicializado relacionado ao som. Para isso chamaremos a função
abaixo:

@<Som: Declarações@>=
void _finalize_sound(void);
@

@<Som: Definições@>=
void _finalize_sound(void){
    @<Som: Primeira Finalização@>
    @<Som: Finalização@>
    // Fechar o dispositivo é a última coisa que deve ser feita ao
    // encerrar o som.
    alcCloseDevice(default_device);
}
@

Agora é só chamarmos estas funçãos durante a inicialização e
finalização da API Weaver:

@<API Weaver: Inicialização@>+=
{
    _initialize_sound();
}
@

@<API Weaver: Som: Encerramento@>+=
{
    _finalize_sound();
}
@

@*1 Escolhendo Dispositivos de Áudio.

O próximo passo é fornecer uma forma do programador escolher qual
dispositivo de áudio ele gostaria de usar. Para isso primeiro nós
precisamos de uma lista de dispositivos suportados. Com isso, é
possível respondermos o número de dispositivos que existem e que
poderão ser consultados na variável abaixo. Uma lista de strings com o
nome de cada dispositivo também será fornecida:

@<Variáveis Weaver@>+=
// Isso fica dentro da estrutura W:
int number_of_sound_devices;
char **sound_device_name;
@

As variáveis serão inicialmente inicializadas com um valor padrão.

@<Som: Inicialização@>=
W.number_of_sound_devices = 0;
W.sound_device_name = NULL;
@

Uma chamada para a função |alcGetString| com os parâmetros certos nos
retorna uma string com o nome de todos os dispositivos existentes se
tivermos a extensão do OpenAL que permite isso. Não testamos
previamente se esta extensão existe ou não porque o resultado
retornado não é confiável no Emscripten. Ao invés disso, apenas
tentamos usar ela. Se ela existir, a função nos dá o nome de cada
dispositivo separado por um ``$\backslash$0'' e a presença de um
``$\backslash$0$\backslash$0'' encerra a string. Inicialmente apenas
percorremos a string para sabermos quantos dispositivos existem:

@<Som: Inicialização@>=
{
    char *devices, *c;
    int end = 0;
    c = devices = (char *) alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    while(end != 2){
        if(*c == '\0'){
            end ++;
            if(c != devices && *(c - 1) != '\0')
                W.number_of_sound_devices ++;
        }
        else
            end = 0;
        c ++;
    }
    if(W.number_of_sound_devices == 0)
        goto AFTER_SOUND_INITIALIZATION;
}
@

Uma vez que o número é conhecido, vamos inicializar o nosso vetor de
string com o nome dos dispositivos e amos percorrer a string com os
nomes novamente apenas para pegar o endereço do começo de cada nome:

@<Som: Inicialização@>=
{
    char *devices, *c;
    int i = 0;
    W.sound_device_name = (char **) Walloc(W.number_of_sound_devices *
                                           sizeof(char *));
    if(W.sound_device_name == NULL){
        fprintf(stderr, "ERROR: Not enough memory. Please, increase the value"
                " of W_INTERNAL_MEMORY at conf/conf.h and try to run the "
                "program again.\n");
        exit(1);
    }
    c = devices = (char *) alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    W.sound_device_name[0] = devices;
    for(;; c ++){
        if(*c == '\0'){
            i ++;
            if(i < W.number_of_sound_devices)
                W.sound_device_name[i] = c + 1;
            else
                break;
        }
    }
}
@

Como alocamos um vetor para comportar os nomes de dispositivos
em |W.sound_device_name|, teremos então que no encerramento desalocar a
sua memória alocada:

@<Som: Finalização@>=
{
    if(W.sound_device_name != NULL)
        Wfree(W.sound_device_name);
}

@

Agora temos que fornecer uma forma de mudar qual o nosso dispositivo
de som padrão. O modo de fazer isso para nós será passar um número que
corresponde à sua posição no vetor de nomes de dispositivos:

@<Som: Declarações@>=
bool _select_sound_device(int position);
@

@<Som: Definições@>=
bool _select_sound_device(int position){
    if(position < 0 || position >= W.number_of_sound_devices)
        return false;
    // Antes de fechar dispositivo de áudio haverão outras
    // finalizações a fazer.
    @<Som: Antes de Trocar de Dispositivo@>
    alcCloseDevice(default_device);
    default_device = alcOpenDevice(W.sound_device_name[position]);
    @<Som: Após Trocar de Dispositivo@>
    return true;
}
@

Agora é só colocar esta função na estrutura |W|:

@<Funções Weaver@>+=
  bool (*select_sound_device)(int);
@
@<API Weaver: Inicialização@>+=
  W.select_sound_device = &_select_sound_device;
@

E por fim, pode haver a necessidade de saber qual dos dispositivos da
lista está marcado como o atual. Para isso, usamos a função abaixo que
retorna o número de identificação (posição no vetor) do dispositivo
atual ou que retorna o valor de -1 que representa ``desconhecido ou
inexistente'':

@<Som: Declarações@>=
int _current_sound_device(void);
@

@<Som: Definições@>=
int _current_sound_device(void){
    int i;
    char *query;
    if(W.sound_device_name == NULL)
        return -1;
    query = (char *) alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    for(i = 0; i < W.number_of_sound_devices; i ++)
        if(!strcmp(query, W.sound_device_name[i]))
            return i;
    return -1;
}
@

E por fim adicionamos isso à estrutura |W|:

@<Funções Weaver@>+=
  int (*current_sound_device)(void);
@
@<API Weaver: Inicialização@>+=
  W.current_sound_device = &_current_sound_device;
@

Após termos escolhido o nosso dispositivo, o próximo passo é criarmos
um contexto. Um conexto nada mais é do que um conjunto de
configurações que serão válidas para todos os sons que forem tocados
dentro dele. Algumas das confgurações que teoricamente podem ser
mudadas são a frequência de amostragem de sinal do áudio (tipicamente
é 44,100 Hz), o número de caixas de som para áutio monoaural, para
áudio estéreo e algumas outras. Mas na prática de acordo com as
implementações atual do OpenAL, nem todas as mudanças são suportadas e
o melhor é ficar com as configuraçõles padrão.

Criar um contexto é o que iremos fazer na inicialização por meio da
função |alcCreateContext|:

@<Som: Variáveis Estáticas@>=
  static ALCcontext *default_context = NULL;
@

@<Som: Inicialização@>=
{
    if(default_device){
        // O segundo argumento NULL escolhe configurações padrão:
        default_context =alcCreateContext(default_device, NULL);
        alcMakeContextCurrent(default_context);
    }
    alGetError(); // Limpa o registro de erros
}
@

Uma vez que um contexto foi criado, precisamos criar uma fonte de
som. Iremos considerá-la a nossa fonte padrão que deve ser tratada
como se sempre estivesse posicionada diante de nós. Então ela não irá
se mover, sofrer atenuação ou efeito Doppler. Na verdade não criaremos
somente uma, mas cinco delas para que assim possamos tocar mais de um
efeito sonoro simultâneo.

A nossa fonte padrão será armazenada nesta variável que é basicamente
um inteiro:

@<Som: Variáveis Estáticas@>=
  static ALuint default_source[5];
@

E durante a inicialização nós iremos criá-la e inicializá-la:

@<Som: Inicialização@>=
{
    ALenum error;
    if(default_device != NULL){
        alGenSources(5, default_source);
        error = alGetError();
        if(error != AL_NO_ERROR){
            fprintf(stderr, "WARNING(0)): No sound source could be created. "
                    "alGenSources failed. Sound probably won't work.\n");
        }
    }
}
@

Na finalização iremos remover a fonte de som padrão:

@<Som: Finalização@>+=
{
    alDeleteSources(5, default_source);
    if(default_context != NULL)
        alcDestroyContext(default_context);
}
@

E não apenas isso precisa ser feito. Quando trocamos de dispositivo de
áudio, precisamos também finalizar o contexto atual e todas as fontes
atuais e gerá-las novamente. Por isso fazemos:

@<Som: Antes de Trocar de Dispositivo@>=
{
    alDeleteSources(5, default_source);
    if(default_context != NULL)
        alcDestroyContext(default_context);
}
@

Uma vez que temos uma fonte padrão para a emissão de sons, podemos
usá-la para produzir qualquer som que quisermos que tenham relação com
a interface ou com sons genéricos sem relação com algum objeto
existente no jogo.

@*1 Interpretando Arquivos \.WAV.

O Formato de Arquivo de Áudio Waveform foi criado pela Microsoft e IBM
para armazenar áudio em computadores. Ele é um caso particular de um
outro formato de arquivos chamado RIFF (Resource Interchange File
Format), o qual pode ser usado para armazenar dados arbitrários, não
apenas áudio. Este será o formato de áudio inicialmente suportado por
ser o mais simples de todos. Futuramente outros capítulos poderão
lidar com formatos de áudio mais sofisticados e que gastam menos
recurso na memória.

O RIFF foi criado em 1991, sendo baseado em outro formato de container
anterior criados por outra empresa e que se chamava IFF.

Um arquivo RIFF sempre é formado por uma lista de ``pedaços''. Cada
pedaço é sempre formado por uma sequência de quatro caracteres (no
nosso caso, a string ``RIFF''), por um número de 32 bits representando
o tamanho do dado que este pedaço carrega e uma sequência de bytes com
o dado carregado pelo pedaço. Após os dados, podem haver bytes de
preenchimento que não foram contados na especificação de tamanho.

Pedaços podem ter também subpedaços. No caso do formato WAVE, os
arquivos sempre tem um único pedaço. Mas dentro dele há dois
subpedaços: um para armazenas dados sobre o áudio e outro para
armazenar os ddos em si. Também podem haver subpedaços adicionais,
como um subpedaço para armazenar informações de copyright. O problema
é que o formato WAVE pode ser um tanto complexo, suportando diferentes
tipos de subpedaços e muitas diferentes formas de se armazenar o som
internamente. Além disso, existem versões mais antigas e pouco
precisas que descrevem o formato que foram usadas para fazer softwares
mais antigos e menos robustos que serão capazes apenas de tocar um
subconjunto do formato WAVE.

Mesmo levando em conta apenas tal subconjunto, não é incomum encontrar
amostras de áudio WAVE com alguns dados internos incorretos. Por causa
de todos estes fatores, não vale à pena se ater à todos os detalhes da
especificação WAVE. Campos que podem ser facilmente deduzidos devem
ser deduzidos ao invés de confiar na especificação do arquivo. Campos
não-essenciais podem ser ignorados. E além disso, iremos suportar
apenas uma forma canônica do formato WAVE, que na prática é a mais
difundida por poder ser tocada por todos os softwares.

Inicialmente estamos interessados apenas em arquivos de áudio muito
pequenos que ficarão carregados na memória para tocar efeitos sonoros
simples (e não em tocar música ou sons sofisticados por enquanto).

Criaremos então a seguinte função que abre um arquivo WAV e retorna os
seus dados sonoros, bem como o seu tamanho e frequência, número de
canais e número de bits por maostragem, informações necessárias para
depois tocá-lo usando OpenAL. A função deve retornar um buffer para o
dados extraídos e armazenar os seus valores nos ponteiros passados
como argumento. Em caso de erro, marcamos também como falsa uma
ariável booleana cujo ponteiro recebemos.

Outra coisa que não podemos esquecer é que se estivermos executando o
código via Emscripten, ler um arquivo de áudio na Internet tem uma
latência alta demais. Por causa disso, o melhor a fazer é lermos ele
assincronamente, sem que tenhamos que terminar de carregá-lo quando a
função de leitura retorna. A estrutura de áudio deve possuir uma
variável booleana chamada |ready| que nos informa se o áudio já
terminou de ser carregado ou não. Enquanto ele ainda não terminar,
podemos pedir para que o som seja tocado sem que som algum seja
produzido. Isso poderá ocorrer em ambiente Emscripten e não é um
bug. É a melhor forma de lidar com a latência de um ambiente de
Internet. E iremos também aproveitar e fazer com que arquivos também
sejam lidos assíncronamente e paralelamente caso threads estejam
ativadas. Mesmo que o programador não as use explicitamente, ele se
beneficiará delas, pois Weaver poderá carregar automaticamente
arquivos em diferentes threads.

Mas é importante que tenhamos terminado de carregar todos os
arquivos da rede antes de sairmos do loop atual. Caso contrário,
estaremos nos colocando à mercê de falhas de segmentação. Ao encerrar o
loop atual, marcamos como disponíveis as regiões alocadas no loop. Mas
se tem um código assíncrono preenchendo tais regiões, isso causará
problemas. Por causa disso, teremos que manter uma contagem de
quantos arquivos pendentes estamos carregando.

@<Variáveis Weaver@>+=
unsigned pending_files;
#ifdef W_MULTITHREAD
pthread_mutex_t _pending_files_mutex;
#endif
@
@<API Weaver: Inicialização@>+=
W.pending_files = 0;
#ifdef W_MULTITHREAD
if(pthread_mutex_init(&(W._pending_files_mutex), NULL) != 0){
  fprintf(stderr, "ERROR (0): Can't initialize mutex for file loading.\n");
  exit(1);
}
#endif
@
@<API Weaver: Finalização@>+=
#ifdef W_MULTITHREAD
pthread_mutex_destroy(&(W._pending_files_mutex));
#endif
@

Consultar esta variável |W.pending_files| pode ser usada por loops que
funcionam como telas de carregamento. O valor será extremamente útil
para saber quantos arquivos ainda precisam terminar de ser carregados
tanto no ambiente Emscripten como caso um programa use threads para
carregar arquivos e assim tentar tornar o processo mais rápido. Isso
significa que temos também que oferecer um mutex para esta variável se
estivermos usando multithreading (mas não em ambiente Emscripten, o
Javascript realmente trata como atômicas suas expressões).

Começamos agora com a nossa função de extrair arquivos WAV
simplesmente abrindo o arquivo que recebemos, e checando se podemos
lê-lo antes de efetivamente interpretá-lo:

@<Som: Variáveis Estáticas@>+=
static ALuint extract_wave(const char *filename, unsigned long *size, int *freq,
                           int *channels, int *bitrate, bool *error){
    void *returned_data  = NULL;
    ALuint returned_buffer = 0;
    FILE *fp = fopen(filename, "r");
    *error = false;
    if(fp == NULL){
        *error = false;
        return 0;
    }
    @<Interpretando Arquivo WAV@>
    return returned_buffer;
}
@

Em seguida, checamos se estamos diante de um arquivo RIFF. Para isso,
basta checar se os primeiros 4 bytes do arquivo formam a string
``RIFF''. Se não for, realmente não estamos lidando com um WAVE.

@<Interpretando Arquivo WAV@>=
{
    char data[5];
    size_t size_t_ret;
    data[0] = '\0';
    size_t_ret = fread(data, 1, 4, fp);
    data[4] = '\0';
    if(strcmp(data, "RIFF")){
        fprintf(stderr, "WARNING: Not compatible audio format: %s\n",
                filename);
        fclose(fp);
        *error = true;
        return 0;
    }
    if(size_t_ret){};
}
@

Em seguida, lemos o tamanho do primeiro pedaço do arquivo, que será o
único lido. Tal tamanho é armazenado sempre em 4 bytes. E um arquivo
em formato WAVE sempre armazena os números no formato ``little
endian''. Então para garantir que o código funcione em qualquer tipo
de processador, tratamos manualmente a ordem dos bytes por meio de um
loop.

@<Interpretando Arquivo WAV@>+=
{
    int i;
    unsigned long multiplier = 1;
    *size = 0;
    for(i = 0; i < 4; i ++){
        unsigned long size_tmp = 0;
        if(fread(&size_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
        *size += size_tmp * multiplier;
        multiplier *= 256;
    }
}
@

Até então o que fizemos foi interpretar dados presentes em qualquer
arquivo RIFF. Agora iremos observar se o arquivo que temos realmente é
um arquivo WAV. Nos dados armazenados em nosso pedaço, se isso é
verdade, os primeiros 4 bytes formam a string ``WAVE'':

@<Interpretando Arquivo WAV@>+=
{
    char data[5];
    size_t size_t_ret;
    data[0] = '\0';
    size_t_ret = fread(data, 1, 4, fp);
    data[4] = '\0';
    if(size_t_ret){};
    if(strcmp(data, "WAVE")){
        fprintf(stderr, "WARNING: Not compatible audio format: %s\n",
                filename);
        fclose(fp);
        *error = true;
        return 0;
    }
    // Devemos também reduzir os bytes lidos do tamanho do arquivo
    // para no fim ficarmos com o tamanho exato do áudio:
    *size -= 4;
}
@

Em seguida, vamos ignorar os próximos 8 bytes do arquivo. Eles devem
possuir apenas uma marcação de que estamos no subpedaço que vai
descrever o formato do áudio e possui um número que representa o
tamanho deste subpedaço. Em amostras adquiridas na Internet, o valor
de tamanho de subpedaço continha valores errôneos em alguns casos.

@<Interpretando Arquivo WAV@>+=
{
    int c, i;
    for(i = 0; i < 8; i ++){
        c = getc(fp);
        if(c == EOF){
            fprintf(stderr, "WARNING: Damaged audio file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
    }
    *size -= 8;
}
@

A próxima coisa que deve estar presente no arquivo WAV é um número de
16 bits que representa o formato de áudio que está armazenado no
arquivo. Existem vários  diferentes e cada um possui o seu
próprio número. Mas nós iremos suportar somente um: o formato PCM da
Microsoft. Este é o formato mais usado para representar áudio sem
qualquer tipo de compressão dentro de um arquivo WAVE. O formato é
representado pelo número 1 e, portanto, se tivermos um número
diferente de 1 não conseguiremos interpretar o áudio.

@<Interpretando Arquivo WAV@>+=
{
    int i, format = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 2; i ++){
        unsigned long format_tmp = 0;
        if(fread(&format_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
        format += format_tmp * multiplier;
        multiplier *= 256;
    }
    if(format != 1){
        fprintf(stderr, "WARNING: Not compatible WAVE file format: %s.\n",
                filename);
        fclose(fp);
        *error = true;
        return 0;
    }
    // Devemos também reduzir os bytes lidos do tamanho do arquivo
    // para no fim ficarmos com o tamanho exato do áudio:
    *size -= 2;
}
@

O próximo valor a ser lido é o número de canais de áudio. Eles estão
em um número de 16 bits:

@<Interpretando Arquivo WAV@>+=
{
    int i;
    *channels = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 2; i ++){
        unsigned long channel_tmp = 0;
        if(fread(&channel_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
        *channels += channel_tmp * multiplier;
        multiplier *= 256;
    }
    // Devemos também reduzir os bytes lidos do tamanho do arquivo
    // para no fim ficarmos com o tamanho exato do áudio:
    *size -= 2;
}
@

O próximo é a frequência, mas desta vez teremos um número de 4 bytes:

@<Interpretando Arquivo WAV@>+=
{
    int i;
    *freq = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 4; i ++){
        unsigned long freq_tmp = 0;
        if(fread(&freq_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
        *freq += freq_tmp * multiplier;
        multiplier *= 256;
    }
    // Devemos também reduzir os bytes lidos do tamanho do arquivo
    // para no fim ficarmos com o tamanho exato do áudio:
    *size -= 4;
}
@

Depois disso vem mais 6 bytes que podem ser ignorados. Eles possuem
informações sobre o alinhamento de blocos e uma estimativa de quantos
bytes serão tocados por segundo:

@<Interpretando Arquivo WAV@>+=
{
    int c, i;
    for(i = 0; i < 6; i ++){
        c = getc(fp);
        if(c == EOF){
            fprintf(stderr, "WARNING: Damaged audio file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
    }
    *size -= 6;
}
@

Em seguida, vem mais 2 bytes que representam quantos bits são usados
em cada amostragem de áudio.

@<Interpretando Arquivo WAV@>+=
{
    int i;
    *bitrate = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 2; i ++){
        unsigned long bitrate_tmp = 0;
        if(fread(&bitrate_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
        *bitrate += bitrate_tmp * multiplier;
        multiplier *= 256;
    }
    // Devemos também reduzir os bytes lidos do tamanho do arquivo
    // para no fim ficarmos com o tamanho exato do áudio:
    *size -= 2;
}
@

O que vem depois são mais 8 bytes sinalizando que estamos entrando no
subpedaço com os dados do áudio em si e indicando redundantemente qual
o pedaço deste subpedaço. Podemos ignorar estas informações:

@<Interpretando Arquivo WAV@>+=
{
    int c, i;
    for(i = 0; i < 8; i ++){
        c = getc(fp);
        if(c == EOF){
            fprintf(stderr, "WARNING: Damaged audio file: %s\n",
                    filename);
            fclose(fp);
            *error = true;
            return 0;
        }
    }
    *size -= 8;
}
@

O que restou depois disso é o próprio áudio em si. Podemos enfim
alocar o buffer que armazenará ele, e copiá-lo para ele.

@<Interpretando Arquivo WAV@>+=
{
    size_t size_t_ret;
    returned_data = Walloc((size_t) *size);
    if(returned_data == NULL){
        printf("WARNING(0): Not enough memory to read file: %s.\n",
               filename);
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr, "WARNING (1): You should increase the value of "
                "W_INTERNAL_MEMORY at conf/conf.h.\n");
#endif
        fclose(fp);
        *error = true;
        return 0;
    }
    size_t_ret = fread(returned_data, *size, 1, fp);
    if(size_t_ret){};
}
@

Agora é hora de criarmos o buffer OpenAL. E enviarmos os dados sonoros
extraídos para ele. Depois de fazer isso, podemos desalocar o nosso
buffer com o som:

@<Interpretando Arquivo WAV@>+=
{
    ALenum status;
    ALuint format = 0;
    // Limpando erros anteriores
    alGetError();
    // Gerando buffer OpenAL
    alGenBuffers(1, &returned_buffer);
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
        Wfree(returned_data);
        *error = true;
        fclose(fp);
        return 0;
    }
    // Determinando informações sobre o áudio antes de enviá-lo
    format = 0xfff5;
    if(*bitrate == 8){
        if(*channels == 1)      format = AL_FORMAT_MONO8;
        else if(*channels == 2) format = AL_FORMAT_STEREO8;
    } else if(*bitrate == 16){
        if(*channels == 1)      format = AL_FORMAT_MONO16;
        else if(*channels == 2) format = AL_FORMAT_STEREO16;
    }
    if(format == 0xfff5){
      fprintf(stderr, "WARNING(0): Combination of channel and bitrate not "
              "supported (sound have %d channels and %d bitrate while "
              "we support just 1 or 2 channels and 8 or 16 as bitrate).\n",
              *channels, *bitrate);
      Wfree(returned_data);
      alDeleteBuffers(1, &returned_buffer);
      *error = true;
      fclose(fp);
      return 0;
    }
    // Enviando o buffer de dados para o OpenAL:
    alBufferData(returned_buffer, format, returned_data, (ALsizei) *size,
                 *freq);
    status = alGetError();
    if(status != AL_NO_ERROR){
      fprintf(stderr, "WARNING(0): Can't pass audio to OpenAL. "
                "alBufferData failed. Sound may not work.\n");
        Wfree(returned_data);
        alDeleteBuffers(1, &returned_buffer);
        *error = true;
        fclose(fp);
        return 0;
    }
    // Não precisamos agora manter o buffer conosco. Podemos desalocá-lo:
    Wfree(returned_data);
    fclose(fp);
}
@

@*1 Criando novos sons e tocando.

O que criamos até então é apenas uma função auxiliar que iremos chamar
caso tentemos ler um arquivo com a extensão ``.wav''. Vamos precisar
também fazer com que cada som extraído acabe indo parar em uma struct
que tenha todos os dados necessários para tocá-lo. A struct em si é
esta:

@<Som: Declarações@>+=
struct sound{
  unsigned long size;
  int channels, freq, bitrate;
  ALuint _data;
  bool loaded; /* O som terminou de ser carregado? */
};
@

É importante notar que este tipo de estrutura irá armazenar na memória
todo o som para poder ser tocado rapidamente. Ela não deverá ser usada
para armazenar coisas longas como música, ou isso irá exaurir a
memória disponível.

Podemos então definir a função que realmente será exportada e usada
pelos usuários:

@<Som: Declarações@>+=
struct sound *_new_sound(char *filename);
@

A função tenta interprear o arquivo de áudio observando sua
extensão. Ela também assume que o arquivo de áudioestá no diretório
``sound/'' adequado para que não seja necessário digitar o caminho
completo. Por enquanto somente a extensão ``.wav'' é suportada. Mas nos
capítulos futuros podemos obter suporte de mais extensões:

@<Som: Definições@>+=
struct sound *_new_sound(char *filename){
    char complete_path[256];
    struct sound *snd;
#if W_TARGET == W_ELF
    bool ret = true;
    char *ext;
#endif
#if W_TARGET == W_WEB
    char dir[] = "sound/";
#elif W_DEBUG_LEVEL >= 1
    char dir[] = "./sound/";
#elif W_TARGET == W_ELF
    char dir[] = W_INSTALL_DATA"/sound/";
#endif
    snd = (struct sound *) Walloc(sizeof(struct sound));
    if(snd == NULL){
        printf("WARNING(0): Not enough memory to read file: %s.\n",
               filename);
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr, "WARNING (1): You should increase the value of "
                "W_INTERNAL_MEMORY at conf/conf.h.\n");
#endif
        return NULL;
    }
    snd -> loaded = false;
    strncpy(complete_path, dir, 256);
    complete_path[255] = '\0';
    strncat(complete_path, filename, 256 - strlen(complete_path));
#if W_TARGET == W_WEB
    mkdir("sound/", 0777); // Emscripten
    W.pending_files ++;
    emscripten_async_wget2(complete_path, complete_path,
                           "GET", "", (void *) snd,
                           &onload_sound, &onerror_sound,
                           &onprogress_sound);
    return snd;
#else // Executando nativamente
    // Obtendo a extensão:
    ext = strrchr(filename, '.');
    if(! ext){
      fprintf(stderr, "WARNING (0): No file extension in %s.\n",
              filename);
      return NULL;
    }
    if(!strcmp(ext, ".wav") || !strcmp(ext, ".WAV")){ // Suportando .wav
        snd -> _data = extract_wave(complete_path, &(snd -> size),
                                   &(snd -> freq), &(snd -> channels),
                                   &(snd -> bitrate), &ret);
        // Depois definimos a função abaixo. Ela diz apenas que depois
        // temos que finalizar o recurso armazenado em snd -> _data,
        // que no caso é o id de um som alocado no OpenAL:
        _finalize_after(&(snd -> _data), _finalize_openal);
    }
    @<Som: Extrai outros Formatos@>
    if(ret){ // ret é verdadeiro caso um erro tenha acontecido
      // Se estamos em um loop principal, removemos o buffer OpenAL da
      // lista de elementos que precisam ser desalocados depois. A função
      // _finalize_this é vista logo mais neste capítulo
      if(_running_loop)
        _finalize_this(&(snd -> _data), true);
      Wfree(snd);
      return NULL;
    }
    snd -> loaded = true;
    return snd;
#endif
}
@

Usamos acima uma função que pede para que depois executemos a função
|_finalize_openal| quando chegar a hora de desalocarmos o som. O que a
função de finalização do OpenAL faz é desalocar os buffer que ela
alucou, algo não tratado automaticamente pelo nosso gerenciador de
memória:

@<Som: Funções Estáticas@>+=
// Uma função rápida para desalocar buffers do OpenAL e que podemos
// usar abaixo:
static void _finalize_openal(void *data){
  ALuint *p = (ALuint *) data;
  alDeleteBuffers(1, p);
}
@

Se estamos executando o programa nativamente sem threads, após a
função terminar, a estrutura de som já está pronta. Caso estejamos
rodando no Emscripten, o trabalho é feito dentro das funções que
passamos como argumento do |emscripten_wget|. Definiremos em seguida o
que farão tais funções que passamos como argumento. Já se estivermos
rodando o nosso programa nativamente usando threads, também usamos
funções que cuidarão das threads e farão elas fazerem o
trabalho. Definiremos elas na próxima seção.

A primeira função que vamos definir é a que cuidará assincronamente
dos erros. O que ela faz basicamente é imprimir um aviso e decrementar
o número de arquivos pendentes que estão sendo carregados. Ela deve
ser definida antes, pois podemos precisar invocar o erro dela dentro
das outras funções assíncronas. O código de erro tipicamente é o erro
HTTP. Mas também retornaremos 0 se não for possível identificar o
arquivo pela extensão e 1 caso o arquivo esteja corrompido.

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_WEB
static void onerror_sound(unsigned undocumented, void *snd,
                          int error_code){
  fprintf(stderr, "WARNING (0): Couldn't load a sound file. Code %d.\n",
          error_code);
#ifdef W_MULTITHREAD
    pthread_mutex_lock(&(W._pending_files_mutex));
#endif
    W.pending_files --;
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(W._pending_files_mutex));
#endif
}
#endif
@


A função a ser executada depois de carregar assincronamente o arquivo
faz praticamente a mesma coisa que a função que gera nova estrutura de
som depois de abrir o arquivo quando trabalha de modo síncrono:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_WEB
static void onload_sound(unsigned undocumented, void *snd,
                         const char *filename){
  char *ext;
  bool ret = true;
  struct sound *my_sound = (struct sound *) snd;
  // Checando extensão
  ext = strrchr(filename, '.');
  if(! ext){
    onerror_sound(0, snd, 0);
    return;
  }
  if(!strcmp(ext, ".wav") || !strcmp(ext, ".WAV")){ // Suportando .wav
    my_sound -> _data = extract_wave(filename, &(my_sound -> size),
                                     &(my_sound -> freq),
                                     &(my_sound -> channels),
                                     &(my_sound -> bitrate), &ret);
    // Depois definimos a função abaixo. Ela diz apenas que depois
    // temos que finalizar o id de um som alocado no OpenAL:
    _finalize_after(&(my_sound -> _data), _finalize_openal);
  }
  if(ret){ // ret é verdadeiro caso um erro de extração tenha ocorrido
    onerror_sound(0, snd, 1);
    return;
  }
  my_sound -> loaded = true;
#ifdef W_MULTITHREAD
    pthread_mutex_lock(&(W._pending_files_mutex));
#endif
    W.pending_files --;
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&(W._pending_files_mutex));
#endif
}
#endif
@

E uma função vazia que precisamos passar emostra o que o Emscripten
tem que fazer à medida que carrega cada porcentagem relevante do
arquivo:

@<Som: Funções Estáticas@>+=
#if W_TARGET == W_WEB
static void onprogress_sound(unsigned int undocumented, void *snd,
                             int percent){
  return;
}
#endif
@

E uma vez que tal função tenha sido definida, nós a colocamos dentro
da estrutura W:

@<Funções Weaver@>+=
  struct sound *(*new_sound)(char *);
@
@<API Weaver: Inicialização@>+=
  W.new_sound = &_new_sound;
@

E uma vez que obtemos um arquivo de áudio, caso desejemos tocar, basta
invocar a função abaixo:

@<Som: Declarações@>+=
void _play_sound(struct sound *snd);
@

@<Som: Definições@>+=
void _play_sound(struct sound *snd){
  if(! snd -> loaded) return; // Se o som ainda não carregou, deixa.
  int i = -1;
  ALenum status = AL_NO_ERROR;
  // Primeiro associamos o nosso buffer à uma fonte de som:
  do{
    i ++;
    if(i > 4) break;
    alSourcei(default_source[i], AL_BUFFER, snd -> _data);
    status = alGetError();
  } while(status != AL_NO_ERROR);
  alSourcePlay(default_source[i]);
}
@

E colocamos a função na estrutura |W|:

@<Funções Weaver@>+=
void (*play_sound)(struct sound *);
@
@<API Weaver: Inicialização@>+=
  W.play_sound = &_play_sound;
@

Remover o som criado pode ser deixado á cargo do nosso coletor de
lixo, então geralmente não precisaremos de uma função de
desalocação. Mas para o caso específico de um som ter sido lido fora
de um loop principal, ou se o usuário realmente quiser, forneceremos
uma função para isso:

@<Som: Declarações@>+=
void _destroy_sound(struct sound *snd);
@

@<Som: Definições@>+=
void _destroy_sound(struct sound *snd){
  // Desalocar um som envolce desalocar o seu dado sonoro (sua
  // variável _data) e desalocar a própria estrutura de som. Mas para
  // isso ocorrer, precisamos garantir que o som já tenha sido
  // carregado.
  while(snd -> loaded == false && W.pending_files > 0){
#ifdef W_MULTITHREAD
    sched_yield();
#elif W_TARGET == W_ELF
    {
      struct timespec tim;
      // Espera 0,001 segundo
      tim.tv_sec = 0;
      tim.tv_nsec = 1000000L;
      nanosleep(&tim, NULL);
    }
#elif W_TARGET == W_WEB
    return;
#endif
  }
  // Ok, podemos desalocar:
  alDeleteBuffers(1, &(snd -> _data));
  // Se estamos em um loop principal, removemos o buffer OpenAL da
  // lista de elementos que precisam ser desalocados depois. A função
  // _finalize_this é vista logo mais neste capítulo
  if(_running_loop)
    _finalize_this(&(snd -> _data), false);
  Wfree(snd);
}
@

@<Funções Weaver@>+=
void (*destroy_sound)(struct sound *);
@
@<API Weaver: Inicialização@>+=
  W.destroy_sound = &_destroy_sound;
@

@*1 Finalizando Recursos Complexos.

Nós temso também que desalocar o buffer alocado pelo OpenAL para cada
som que inicializamos. O nosso coletor de lixo não tem como fazer
isso, pois isso é memória que pertence ao OpenAL, não à nossa API
própria. Da mesma forma, caso tenhamos que fazer coisas como fechar
arquivos abertos antes de sair do loop atual, o coletor de lixo também
não poderá fazer isso automaticamente por nós. Teremos então que
escrever código que nos ajude a gerenciar esses recursos mais
complexos.

A ideia é que possamos criar uma lista encadeada que armazena em cada
elemento um ponteiro genérico para |void *| e uma função sem retorno
que recebe um ponteiro deste tipo e que será responsável por finalizar
o recurso no momento em que sairmos de nosso loop atual.

Cada elemento desta lista terá então a forma:

@<Cabeçalhos Weaver@>+=
#ifdef W_MULTITHREAD
pthread_mutex_t _finalizing_mutex;
#endif
struct _finalize_element{
  void *data;
  void (*finalize)(void *);
  struct _finalize_element *prev, *next;
};
struct _finalize_element *_finalize_list[W_MAX_SUBLOOP];
@

A nossa lista no começo será inicializada como tendo valores iguais a
|NULL| em todos os casos. O que representa uma lista encadeada vazia
para nós:

@<API Weaver: Inicialização@>+=
{
  int i;
  for(i = 0; i < W_MAX_SUBLOOP; i ++){
    _finalize_list[i] = NULL;
  }
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&_finalizing_mutex, NULL) != 0){
    fprintf(stderr, "ERROR (0): Can't initialize mutex.\n");
    exit(1);
  }
#endif
}
@

E no fim de nosso programa, só o que precisamos fazer é finalizar o
mutex se for o caso:

@<API Weaver: Finalização@>+=
#ifdef W_MULTITHREAD
  pthread_mutex_destroy(&_finalizing_mutex);
#endif
@

Quando pedirmos para finalizar mais tarde algum recurso, nós
chamaremos esta função que irá inserir na nossa lista encadeada um
novo elemento:

@<Cabeçalhos Weaver@>+=
void _finalize_after(void *, void (*f)(void *));
@

@<API Weaver: Definições@>+=
void _finalize_after(void *data, void (*finalizer)(void *)){
  struct _finalize_element *el;
  if(!_running_loop)
    return;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_finalizing_mutex);
#endif
  el = (struct _finalize_element *) Walloc(sizeof(struct _finalize_element));
  if(el == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory. Error in an internal "
            "operation. Please, increase the value of W_MAX_MEMORY at "
            "conf/conf.h. Currently we won't be able to finalize some "
            "resource.\n");
  }
  else if(_finalize_list[_number_of_loops] == NULL){
    el -> data = data;
    el -> finalize = finalizer;
    el -> prev = el -> next = NULL;
    _finalize_list[_number_of_loops] = el;
  }
  else{
    el -> data = data;
    el -> finalize = finalizer;
    el -> prev = NULL;
    _finalize_list[_number_of_loops] -> prev = el;
    el -> next = _finalize_list[_number_of_loops];
    _finalize_list[_number_of_loops] = el;
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_finalizing_mutex);
#endif
}
@

Sempre que encerrarmos um loop teremos então que chamar a seguinte
função:

@<Cabeçalhos Weaver@>+=
void _finalize_all(void);
@

@<API Weaver: Definições@>+=
void _finalize_all(void){
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_finalizing_mutex);
#endif
  struct _finalize_element *p = _finalize_list[_number_of_loops];
  while(p != NULL){
    p -> finalize(p -> data);
    p = p -> next;
  }
  _finalize_list[_number_of_loops] = NULL;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_finalizing_mutex);
#endif
}
@

Ela será chamada antes de entrarmos em um novo loop, mas não em
subloop. E antes de sairmos de um subloop:

@<Código antes de Loop, mas não de Subloop@>+=
_finalize_all();
@

@<Código após sairmos de Subloop@>+=
_finalize_all();
@

E por último forneceremos uma funçção que remove um elemento da lista
de elementos a serem finalizados. Isso será útil quando, por exemplo,
nós chamamos manualmente uma função para desalocar um som. Netse caso,
podemos remover o seu buffer OpenAL da lista de coisas que precisam
ser desalocadas depois:

@<Cabeçalhos Weaver@>+=
  void _finalize_this(void *, bool);
@

@<API Weaver: Definições@>+=
  void _finalize_this(void *data, bool remove){
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_finalizing_mutex);
#endif
  {
    struct _finalize_element *p = _finalize_list[_number_of_loops];
    while(p != NULL){
      if(p -> data == data){
        if(p -> prev != NULL)
          p -> prev -> next = p -> next;
        else
          _finalize_list[_number_of_loops] = p -> next;
        if(p -> next != NULL)
          p -> next -> prev = p -> prev;
        if(remove)
          Wfree(p);
        return;
      }
      p = p -> next;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_finalizing_mutex);
#endif
}
@

@*1 Sumário das variáveis e Funções de Som.

\macronome A seguinte nova estrutura foi definida:

\noindent|struct sound {
    unsigned long size;
    int channels, freq, bitrate;
    bool loaded;
}|

\macrovalor|size|: Representa o tamanho do áudio em bytes.

\macrovalor|channels|: Quantos canais de áudio existem neste som.

\macrovalor|freq|: A frequência do áudio lido.

\macrovalor|bitrate|: Quantos bits são usados para representar ele.

\macrovalor|loaded|: Esta estrutura já possui um áudio completamernte
    carregado da memória?

\macronome As seguintes 2 novas variáveis foram definidas:

\macrovalor|int W.number_of_sound_devices|: O número de dispositivos de som
que temos à nossa disposição.

\macrovalor|unsigned int W.pending_files|: O número de arquivos que
estão sendo lidos, mas ainda não terminaram de ser processados. O
valor será diferente de zero em um ambiente no qual os arquivos são
lidos assincronamente, como no Emscripten.

\macrovalor|char *W.sound_device_name[W.number_of_sound_devices]|: O
nome de cada um dos dispositivos de som que temos à nossa disposição.

\macronome As seguintes 4 novas funções foram definidas:

\macrovalor|bool W.select_sound_device(int sound_device)|:
Escolhe um dos dispositivos de som disponíveis para usar. Para isso,
passamos o índice de sua posição no veor visto acima
|W.sound_device_name|. Em seguida, retornamos um valor booleano que
diz se a mudança foi feita com sucesso.

\macrovalor|int W.current_sound_device(void)|:
Retorna o índice do dispositivo de som usado atualmente. Ou -1 se
nenhum está sendo usado.

\macrovalor|struct sound *W.new_sound(char *filename)|:
Cria uma nova estrutura de som representando um efeito sonoro no
diretório \monoespaco{sound/}. Ou |NULL| se não foi possível ler
corretamente um áudio.

\macrovalor|bool W.play_sound(struct sound *snd)|:
Toca um som representado por uma estrutura de som. Em seguida retorna
se foi possível tocar o som com sucesso.

\macrovalor|void W.destroy_sound(struct sound *snd)|:
Desaloca a memória e os recursos alocados com  a função |W.new_sound|.
