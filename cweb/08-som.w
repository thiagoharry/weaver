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
    if(default_device == NULL){
        fprintf(stderr, "WARNING (0): No sound device detected.\n");
        return;
    }
    @<Som: Inicialização@>
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

@<API Weaver: Finalização@>+=
{
    _finalize_sound();
}
@

@*1 Escolhendo Dispositivos de Áudio.

O próximo passo é fornecer uma forma do programador escolher qual
dispositivo de áudio ele gostaria de usar. Para isso primeiro nós
precisamos de uma lista de dispositivos suportados.

Isso é suportado por meio de uma extensão do OpenAL que pode ou não
pode estar presente. Primeiro devemos checar se esta extensão está
presente:

@<Som: Inicialização@>=
  if(alcIsExtensionPresent(NULL, "ALC_ENUMERATION_EXT") == ALC_FALSE)
      goto AFTER_ENUMERATION;
@

Uma vez que tenhamos a extensão de enumeração, podemos então usar ela
para obter strings com informações sobre nosso sistema. Aqui obtemos
uma string com uma lista de todos os dispositivos presentes:

@<Som: Inicialização@>=
{
    char *devices, *c;
    int end = 0;
    c = devices = (char *) alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    // Bizarramente, a string que obtemos é finalizada por "\0\0" e
    // usa "\0" como separador de dispositivos:
    while(end != 2){
        if(*c == '\0'){
            end ++;
            putchar('\n');
        }
        else{
            end = 0;
            putchar(*c);
        }
        c++;
    }
AFTER_ENUMERATION:
  return;
}
@
