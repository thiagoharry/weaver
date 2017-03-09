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
#include "sound.h"
@<Som: Variáveis Estáticas@>
@<Som: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "sound.h"
@

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
dispositivos existentes. Cada dispositivo é separado por um ``\0'' e a
presença de um ``\0\0'' encerra a string. Inicialmente apenas
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
AFTER_SOUND_INITIALIZATION:
  return;
@

Como aabamos alocando um vetor para comportar os nomes de dispositivos
em |W.sound_device_name|, teremos então que no encerramento desalocar a
sua memória alocada:

@<Som: Finalização@>=
{
    if(W.sound_device_name != NULL)
        Wfree(W.sound_device_name);
}

@
% int W.number_of_sound_devices
% char *W.sound_device_name[W.number_of_sound_devices];
