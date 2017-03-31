@* Suporte Básico a Som.

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
distância da fonte emissora do som e da posição da câmera em um
ambiente virtual em 3D. Além de suportar a simulação de efeitos
físicos como o efeito Doppler.

A primeira coisa a fazer para usar a biblioteca é criar um cabeçalho e
um arquio de código C com funções específicas de som. Nestes arquivos
iremos inserir também o cabeçalho OpenAL.

@(project/src/weaver/sound.h@>=
#ifndef _sound_h_
#define _sound_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
#include <AL/al.h>
#include <AL/alc.h>
@<Inclui Cabeçalho de Configuração@>
@<Som: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/sound.c@>=
#include <string.h> // strrchr
#include "sound.h"
@<Som: Variáveis Estáticas@>
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

@<API Weaver: Encerramento@>+=
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

O preenchimento de tais informações é suportado por meio de uma
extensão do OpenAL que pode ou não pode estar presente. Primeiro
devemos checar se esta extensão está presente.

@<Som: Inicialização@>=
  if(alcIsExtensionPresent(NULL, "ALC_ENUMERATION_EXT") == ALC_FALSE)
      goto AFTER_SOUND_INITIALIZATION;
@

Uma vez que tenhamos a extensão de enumeração, podemos então usar ela
para obter strings com informações sobre nosso sistema. Se a extensão
está presente, uma chamada para a função |alcGetString| com os
parâmetros certos nos retorna uma string com o nome de todos os
dispositivos existentes. Cada dispositivo é separado por um
``$\backslash$0'' e a presença de um ``$\backslash$0$\backslash$0''
encerra a string. Inicialmente apenas percorremos a string para
sabermos quantos dispositivos existem:

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

Como acabamos alocando um vetor para comportar os nomes de dispositivos
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
  static ALCcontext *default_context;
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

Uma vez que um contexto foi criado, precisamos criar uma fone de
som. Iremos considerá-la a nossa fonte padrão que deve ser tratada
como se sempre estivesse posicionada diante de nós. Então ela não irá
se mover, sofrer atenuação ou efeito Doppler.

A nossa fonte padrão será armazenada nesta variável que é basicamente
um inteiro:

@<Som: Variáveis Estáticas@>=
  static ALuint default_source;
@

E durante a inicialização nós iremos criá-la e inicializá-la:

@<Som: Inicialização@>=
{
    ALenum error;
    if(default_device != NULL){
        alGenSources(1, &default_source);
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
    alDeleteSources(1, &default_source);
    if(default_context != NULL)
        alcDestroyContext(default_context);
}
@

E não apenas isso precisa ser feito. Quando trocamos de dispositivo de
áudio, precisamos também finalizar o contexto atual e todas as fontes
atuais e gerá-las novamente. Por isso fazemos:

@<Som: Antes de Trocar de Dispositivo@>=
{
    alDeleteSources(1, &default_source);
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
ser deduzidos, e não confiar nos valores internos presentes no
arquivo. Campos não-essenciais podem ser ignorados. E além disos,
iremos suportar apenas uma forma canônica do formato WAVE, que na
prática é a mais difundida por poder ser tocada por todos os
softwares.

Inicialmente estamos interessados apenas em arquivos de áudio muito
pequenos que ficarão carregados na memória para tocar efeitos sonoros
simples (e não em tocar música ou sons sofisticados por enquanto).

Criaremos então a seguinte função que abre um arquivo WAV e retorna os
seus dados sonoros, bem como o seu tamanho e frequência, número de
canais e número de bits por maostragem, informações necessárias para
depois tocá-lo usando OpenAL. A função deve retornar os dados
extraídos e armazenar os seus valores nos ponteiros passados como
argumento. Em caso de erro, apenas retornamos NULL e valores inválidos
de tamanho e frequência podem ou não ser escritos.

Começamos com a nossa função de extrair arquivos WAV simplesmente
abrindo o arquivo que recebemos, e checando se podemos lê-lo antes de
efetivamente interpretá-lo:


@<Som: Variáveis Estáticas@>+=
static void *extract_wave(char *filename, unsigned long *size, int *freq,
                           int *channels, int *bitrate){
    void *returned_data;
    FILE *fp = fopen(filename, "r");
    if(fp == NULL) return NULL;
    @<Interpretando Arquivo WAV@>
    return returned_data;
}
@

Em seguida, checamos se estamos diante de um arquivo RIFF. Para isso,
basta checar se os primeiros 4 bytes do arquivo formam a string
``RIFF''. Se não for, realmente não estamos lidando com um WAVE.

@<Interpretando Arquivo WAV@>=
{
    char data[5];
    data[0] = '\0';
    fread(data, 1, 4, fp);
    data[4] = '\0';
    if(!strcmp(data, "RIFF")){
        fprintf(stderr, "WARNING: Not compatible audio format: %s\n",
                filename);
        fclose(fp);
        return NULL;
    }
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
            return NULL;
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
    data[0] = '\0';
    fread(data, 1, 4, fp);
    data[4] = '\0';
    if(!strcmp(data, "WAVE")){
        fprintf(stderr, "WARNING: Not compatible audio format: %s\n",
                filename);
        fclose(fp);
        return NULL;
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
        c = getc(p);
        if(c == EOF){
            fprintf(stderr, "WARNING: Damaged audio file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
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
    int format = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 2; i ++){
        unsigned long format_tmp = 0;
        if(fread(&format_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
        }
        format += format_tmp * multiplier;
        multiplier *= 256;
    }
    if(format != 1){
        fprintf(sdtderr, "WARNING: Not compatible WAVE file format: %s.\n",
                filename);
        fclose(fp);
        return NULL;
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
    *channels = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 2; i ++){
        unsigned long channel_tmp = 0;
        if(fread(&channel_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
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
    *freq = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 4; i ++){
        unsigned long freq_tmp = 0;
        if(fread(&freq_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
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
        c = getc(p);
        if(c == EOF){
            fprintf(stderr, "WARNING: Damaged audio file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
        }
    }
    *size -= 6;
}
@

Em seguida, vem mais 2 bytes que representam quantos bits são usados
em cada amostragem de áudio.

@<Interpretando Arquivo WAV@>+=
{
    *bitrate = 0;
    unsigned long multiplier = 1;
    for(i = 0; i < 2; i ++){
        unsigned long bitrate_tmp = 0;
        if(fread(&bitrate_tmp, 1, 1, fp) != 1){
            fprintf(stderr, "WARNING: Damaged file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
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
        c = getc(p);
        if(c == EOF){
            fprintf(stderr, "WARNING: Damaged audio file: %s\n",
                    filename);
            fclose(fp);
            return NULL;
        }
    }
    *size -= 8;
}
@

O que restou depois disso é o próprio áudio em si. Podemos enfim
alocar o buffer que armazenará ele, copiar os dados e depois disso
nossa função irá retornar este buffer:

@<Interpretando Arquivo WAV@>+=
{
    returned_data = Walloc((size_t) *size);
    if(returned_data == NULL){
        printf("WARNING(0): Not enough memory to read file: %s.\n",
               filename);
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr, "WARNING (1): You should increase the value of "
                "W_INTERNAL_MEMORY at conf/conf.h.\n");
#endif
        fclose(fp);
        return NULL;
    }
    fread(returned_data, *size, 1, fp);
    fclose(fp);
}
@

E assim enfim terminamos nossa função auxiliar que lê arquios
WAVE. Mas esta é apenas uma função auxiliar que iremos chamar caso
tentemos ler um arquivo com a extensão ``.wav''. Vamos precisar também
fazer com que cada som extraído acabe indo parar em uma struct que
tenha todos os dados necessários para tocá-lo. A struct em si é esta:

@<Som: Declarações@>+=
struct sound{
    unsigned long size;
    int channels, freq, bitrate;
    void *data;
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

@<Som: Declarações@>+=
struct sound *_new_sound(char *filename){
    char *ext, *complete_path;
    struct sound *snd;
#if W_DEBUG_LEVEL >= 1
    char dir[] = "./sound/";
#else
    char dir[] = "/usr/share/games/"W_PROG"/sound/"
#endif
    // Obtendo a extensão:
    ext = strrchr(filename, '.');
    if(! ext){
        fprintf(stderr, "WARNING (0): No file extension in %s.\n",
                filename);
        return NULL;
    }
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
    complete_path = (char *) Walloc(strlen(filename) + strlen(dir) + 1);
    if(complete_path == NULL){
        Wfree(snd);
        printf("WARNING(0): Not enough memory to read file: %s.\n",
               filename);
#if W_DEBUG_LEVEL >= 1
        fprintf(stderr, "WARNING (1): You should increase the value of "
                "W_INTERNAL_MEMORY at conf/conf.h.\n");
#endif
        return NULL;
    }
    strcpy(complete_path, dir);
    strcat(complete_path, filename);
    if(!strcmp(ext, ".wav") || !strcmp(ext, ".WAV")){
        snd -> data = extract_wave(complete_path, &(snd -> size),
                                   &(snd -> freq), &(snd -> channels),
                                   &(snd -> bitrate));
    }
    else{
        Wfree(complete_path);
        Wfree(snd);
        return NULL;
    }
    Wfree(complete_path);
    return snd;
}
@

% int W.number_of_sound_devices
% char *W.sound_device_name[W.number_of_sound_devices];
% bool W.select_sound_device(int);
% int W.current_sound_device(void);
