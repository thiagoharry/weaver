@* Suporte a Gifs Animados.

Um GIF é um formato de arquivos e uma abreviação para Graphics
Interchange Format. É um formato bastante antigo criado em 1987 e que
ainda hoje é bastante usado por sua capacidade de representar
animações e de seu amplo suporte em navegadores de Internet.

O formato possui as suas limitações, pois o número máximo de cores que
cada imagem pode ter é restrita a 256 cores. Cada cor pode ter até 24
bits diferentes e não é possível representar graus intermediários
entre uma cor totalmente transparente e totalmente opaca.

Devido ao amplo uso de GIFs para representar animações, Weaver usará
este formato como uma das formas possíveis de se representar
animações. No passado, este foi um formato bastante polêmico devido às
suas patentes que restringiam a implementação de softwares capazes de
lidar com GIFs em certos países. Entretanto, atualmente todas as
patentes relevantes do formato já expiraram.

a especificação mais recente do formato GIF é a 89a, criada em 1989 e
que trouxe suporte à animações, embora elas originalmente não pudessem
rodar para sempre em um loop. Em 1995, o Netscape criou uma pequena
extensão que passou a permitir isso e essa extensão passou a ser
amplamente suportada.

Vamos começar criando arquivos para armazenar o nosso código
específico para o tratamento de GIFs:

@(project/src/weaver/gif.h@>=
#ifndef _gif_h_
#define _gif_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<GIF: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/gif.c@>=
#include "weaver.h"
//@<GIF: Variáveis Estáticas@>
@<GIF: Funções Estáticas@>
@<GIF: Definições@>
@
@<Cabeçalhos Weaver@>+=
#include "gif.h"
@

@*1 Interpretando um Arquivo GIF.

A função que fará todo o trabalho será:

@<GIF: Declarações@>=
  char *_extract_gif(char *filename, unsigned long *, unsigned long *, bool *);
@

@<GIF: Definições@>=
char *_extract_gif(char *filename, unsigned long *width,
                   unsigned long *height, bool *error){
    bool global_color_table_flag = false, transparent_color_flag = false;
    int color_resolution, global_color_table_size;
    unsigned img_offset_x = 0, img_offset_y = 0, img_width = 0, img_height = 0;
    unsigned number_of_loops = 0;
    void *returned_data  = NULL;
    ALuint returned_buffer = 0;
    unsigned background_color, delay_time = 0, transparency_index = 0;
    unsigned char *global_color_table = NULL;
    unsigned char *local_color_table = NULL;
    int disposal_method = 0;
    struct _image_list *img = NULL; // A lista de imagens será definida logo mais.
    struct _image_list *last_img = NULL;
    FILE *fp = fopen(filename, "r");
    *error = false;
#if W_TARGET == W_ELF && !defined(W_MULTITHREAD)
    _iWbreakpoint();
#endif
    if(fp == NULL)
      goto error_gif;
    @<Interpretando Arquivo GIF@>
    // Se chegamos aqui, tudo correu bem. Só encerrarmos e retornarmos.
    goto end_of_gif;
  error_gif:
    // Código executado apenas em caso de erro
    *error = true;
    returned_data = NULL;
  end_of_gif:
    // Código de encerramento
#if W_TARGET == W_ELF && !defined(W_MULTITHREAD)
    fclose(fp);
    _iWtrash();
#else
    @<Encerrando Arquivo GIF@>
#endif
    return returned_data;
}
@

Como nós abrimos logo acima um arquivo GIF, no encerramento teremos
que fechá-lo:

@<Encerrando Arquivo GIF@>=
if(fp != NULL) fclose(fp);
@

A primeira coisa que estará presente em um arquivo GIF será o seu
cabeçalho. Que nada mais é do que três bytes com a string ``GIF'' mais
três bytes com a versão do formato usada. A mais antiga e já quase
nunca mais usada é a versão ``87a'', que foi a especificação
original. Mas na prática o que se vê mais é a ``89a'', que é uma
extensão do formato anterior.

@<Interpretando Arquivo GIF@>=
{
  char data[4];
  printf("Cabeçalho.\n");
  fread(data, 1, 3, fp);
  data[3] = '\0';
  if(strcmp(data, "GIF")){
    fprintf(stderr, "WARNING: Not a GIF file: %s\n", filename);
    goto error_gif;
  }
  fread(data, 1, 3, fp);
  data[3] = '\0';
  if(strcmp(data, "87a") && strcmp(data, "89a")){
    fprintf(stderr, "WARNING: Not supported GIF version: %s\n", filename);
    goto error_gif;
  }
}
@

Depois do bloco de cabeçalho, vem o chamado ``descritor de tela
lógica''. Isso porque uma imagem GIF foi feita para representar uma
área de pintura na qual pode-se colocar várias imagens presentes em um
mesmo arquivo. A tela lógica é essa tela de pintura. Neste bloco
encontraremos informações sobre o tamanho da tela lógica (informação
ignorada na maioria dos visualizadores), a cor de fundo desta tela
lógica (isso também é ignorado nos softwares atuais) e a proporção
entre altura e largura dos pixels que formam a imagem (adivinhe só,
também é ignorado pelos softwares atuais). Além de algumas flags com
informações adicionais.

@<Interpretando Arquivo GIF@>+=
{
  // Primeiro lemos a largura da imagem, a informação está presente nos
  // próximos 2 bytes (largura máxima: 65535 pixels)
  unsigned char data[2];
  printf("Descritor de tela lógica\n");
  fread(data, 1, 2, fp);
  *width = ((unsigned long) data[1]) * 256 + ((unsigned long) data[0]);
  // Agora lemos a altura da imagem nos próximos 2 bytes
  fread(data, 1, 2, fp);
  *height = ((unsigned long) data[1]) * 256 + ((unsigned long) data[0]);
  // Lemos o próximo byte de onde extraímos informações sobre algumas
  // flags:
  fread(data, 1, 1, fp);
  // Temos uma tabela de cores global?
  global_color_table_flag = (data[0] & 128);
  // O número de bits para cada cor primária menos um:
  color_resolution = (data[0] & 127) >> 4;
  // O tamanho da tabeela de cores caso ela exista:
  global_color_table_size = data[0] % 8;
  // Lemos e ignoramos a cor de fundo de nosso GIF
  fread(&background_color, 1, 1, fp);
  // Lemos e ignoramos  a proporção de altura e largura de pixel
  fread(data, 1, 1, fp);
}
@

Agora o próximo passo é que se a imagem possui uma tabela de cores
global, nós devemos lê-la agora. O seu tamanho em bytes sempre será
dado por $3\times2^{global\_color\_table\_size+1}$

@<Interpretando Arquivo GIF@>+=
if(global_color_table_flag){
  printf("Lendo tabela de cores global.\n");
  unsigned long size = 3 * (1 << (global_color_table_size + 1));
  global_color_table = (unsigned char *) _iWalloc(size);
  if(global_color_table == NULL){
    fprintf(stderr, "WARNING: Not enough memory to read image. Please, increase "
            "the value of W_MAX_MEMORY at conf/conf.h.\n");
    goto error_gif;
  }
  // E agora lemos a tabela global de cores:
  fread(global_color_table, 1, size, fp);
}
@

Além de uma tabela de cores global, podemos estar também com uma
local, de qualquer forma, no fim da função teremos que desalocar
ambas:

@<Encerrando Arquivo GIF@>=
if(local_color_table != NULL) Wfree(local_color_table);
if(global_color_table != NULL) Wfree(global_color_table);
@

Agora a ideia é que sigamos lendo os próximos blocos. Os tipos de
blocos que poderemos encontrar são: descritores de imagem (o próximo
byte é 44), extensões (o próximo byte é 33) ou um marcador de fim dos
dados (o próximo byte é 59). Basicamente iremos ler agora vários
blocos até que enfim terminemos o arquivo lendo o bloco que marca o
fim dos dados:

@<Interpretando Arquivo GIF@>+=
{
  unsigned block_type;
  unsigned char data[2];
  fread(data, 1, 1, fp);
  block_type = data[0];
  while(block_type != 59){
    switch(block_type){
    case 33: // Bloco de extensão
      printf("Extensão\n");
      @<GIF: Bloco de Extensão@>
      break;
    case 44: // Bloco de descritor de imagem
      printf("Descritor de Imagem\n");
      @<GIF: Bloco Descritor de Imagem@>
      break;
    default: // Erro: Lemos um tipo desconhecido de bloco
      fprintf(stderr, "WARNING: Couldn't interpret GIF file %s. Invalid block "
              "%u.\n", filename, block_type);
      goto error_gif;
    }
    fread(data, 1, 1, fp);
    block_type = data[0];
  }
}
@

Primeiro vamos para o caso no qual estamos diante de um bloco de
extensão. Eles possuem informações para comportamentos e informações
não previstas na especificação original, mas que foram adicionadas à
partir de 1989.

Existem ao todo 4 tipos diferentes de extensão. Sabemos qual tipo
temos após ler o próximo byte do nosso GIF. Elas são: extensão de
controle de gráficos (byte 249), extensão de comentário (byte 254),
extensão de texto puro (byte 1) e extensão de aplicação (byte 255). A
última é que representa uma extensão onde há informações para GIFs
animados:

@<GIF: Bloco de Extensão@>=
{
  unsigned extension_type;
  fread(data, 1, 1, fp);
  extension_type = ((unsigned) data[1]) * 256 + ((unsigned) data[0]);
  switch(extension_type){
  case 1: // Texto puro
    printf("(Texto Puro)\n");
    @<GIF: Extensão de Texto Puro@>
    break;
  case 249: // Controle de gráficos
    printf("(Controle de Gráficos)\n");
    @<GIF: Extensão de Controle de Gráficos@>
    break;
  case 254: // Comentário
    printf("(Comentário)\n");
    @<GIF: Extensão de Comentário@>
    break;
  case 255: // Aplicação
    printf("(Aplicação)\n");
    @<GIF: Extensão de Aplicação@>
    break;
  default:
    fprintf(stderr, "WARNING: Couldn't interpret GIF file %s. Invalid extension "
            "block (%d).\n", filename, extension_type);
    goto error_gif;
  }
}
@

A Extensão de Texto Puro serve para armazenar conteúdo de texto dentro
de um GIF que deveria ser renderizado como parte da imagem usando
algum tipo de fonte a ser definida pela aplicação. Ele suporta apenas
texto expresso nos 128 caracteres ASCII originais.

Felizmente esta extensão foi considerada arcaica e descontinuada em
outubro de 1998. Desde então, a recomendação é que novos criadores de
imagem GIF não usem esta extensão e que os leitores de imagens GIF
ignorem ela. Mesmo antes de ter sido descontinuada, esta era uma
extensão extremamente rara de ser usada, a ponto de haver um
questionamento se algum software já implementou ela.

O que faremos quando encontramos esta extensão será seguir a
recomendação e ignorá-la:

@<GIF: Extensão de Texto Puro@>=
{
  // Primeiro jogamos fora os próximos 15 bytes que descrevem
  // informações gerais sobre esta extensão:
  unsigned char buffer[256];
  fread(buffer, 1, 15, fp);
  // Agora jogamos fora os sub-blocos de dados. Cada um deles começa
  // com um byte que diz a quantidade de dados que o sucede. E quando
  // encontrarmos um deles cujo byte inicial é zero, então terminamos
  // de jogar todos eles fora:
  fread(buffer, 1, 1, fp);
  while(buffer[0] != 0){
    fread(buffer, 1, buffer[0], fp);
    fread(buffer, 1, 1, fp);
  }
  @<GIF: Após Extensão de Texto Puro@>
}
@

A Extensão de Aplicação é usada para armazenar informações específicas
a determinada aplicação. Geralmente seriaa algo a ser
ignorado. Entretanto, o Netscape 2.0 acabou usando ccerta vez este
bloco para armazenar quantas vezes um GIF animado deveria repetir a
sua animação, com um valor de 0 significando que o GIF deveria repetir
para sempre a animação.

Foi isso que deu ao Netscape a capacidade de pela primeira vez usar
GIFs animados como loops infinitos de animação, que ainda hoje é como
eles são mais usados.

Sendo assim, ao encontrarmos uma extensão de aplicação, nós temos que
checar se estamos diante de uma extensão do Netscape 2.0. Em caso
afirmativo, a informação nos interessa e lemos da extensão o número de
vezes que a nossa animação deve entrar em loop. Em caso negativo, nós
apenas ignoramos os dados:

@<GIF: Extensão de Aplicação@>=
{
  bool netscape_extension = false;
  char buffer[12];
  unsigned char buffer2[256];
  // O primeiro byte é só informação sobre o tamanho do cabeçalho
  // deste bloco de extensão. Seu valor é sempre 11, então não
  // precisamos realmente usar este valor:
  fread(buffer, 1, 1, fp);
  // Em seguida, devemos ler os próximos 11 bytes para checar se
  // estamos diante de uma extensão do Netscape 2.0.
  fread(buffer, 1, 11, fp);
  buffer[11] = '\0';
  if(!strcmp(buffer, "NETSCAPE2.0"))
    netscape_extension = true;
  // Agora vamos ver os dados que estão dentro desta extensão
  fread(buffer2, 1, 1, fp);
  while(buffer2[0] != 0){
    fread(buffer2, 1, buffer2[0], fp);
    if(netscape_extension && buffer2[0] == 1){
      // Lemos agora quantas vezes temos que dar um loop na animação:
      number_of_loops = ((unsigned) buffer2[2]) * 256 + ((unsigned) buffer2[1]);
    }
    fread(buffer2, 1, 1, fp);
  }
}
@

A terceira extensão que vamos suportar agora é a extensão de
comentários. Esta extensão não altera em nada a exibição de uma imagem
GIF. É apenas uma extensão reservada para armazenar informações sobre
autoria, descrição e licenciamento de imagens. Portanto, será um campo
que iremos simplesmente ignorar:

@<GIF: Extensão de Comentário@>=
{
  unsigned char buffer[256];
    fread(buffer, 1, 1, fp);
    while(buffer[0] != 0){
      fread(buffer, 1, buffer[0], fp);
      fread(buffer, 1, 1, fp);
    }
}
@

E enfim chegamos a uma extensão mais interessante. A extensão de
controle de gráficos. Esta extensão define informações sobre
transparência e animação caso estejamos lidando com cum GIF que tenha
tais recursos:

@<GIF: Extensão de Controle de Gráficos@>=
{
  // Primeiro lemos o tamanho do cabeçalho deste bloco. Mas ele sempre
  // tem o tamanho de 4, então podemos ignorar o valor lido por já
  // sabermos qual é ele:
  unsigned char buffer[256];
  fread(buffer, 1, 1, fp);
  // No próximo byte lido, temos mais informações que geralmente são
  // ignoradas em softwares modernos. Por exemplo, há um bit que
  // especifica que o GIF não deve avançar a animação enquanto não
  // houver algum tipo de interação com o usuário pedindo por
  // isso. Alguns outros bits estão reservados para uso futuro. Mas há
  // dois valores que nos interessam e que devemos extrair:
  fread(buffer, 1, 1, fp);
  // Primeiro é o "método de disposição", que é o que deve acontecer
  // com cada pixel da imagem quando alternamos de um quadro da
  // animação para outro. Um valor de 0 é não especificado, e
  // geralmente é usado quando a imagem não é animada. O 1 pede para
  // que nada seja apagado e apenas desenhe a nova imagem por cima do
  // anterior. O 2 serve para preencher tudo com o valor da cor de
  // fundo do gif. O 3 serve para preencher com a imagem que havia
  // antes da imagem ser desenhada, e é algo que na prática não
  // costuma ser suportado:
  disposal_method = (buffer[0] >> 2) % 8;
  // E segundo, se vamos suportar transparência:
  transparent_color_flag = buffer[0] % 2;
  // Agora lemos quantos centesimos de segundo devemos esperar em cada
  // mudança do frame de uma animação:
  fread(buffer, 1, 2, fp);
  delay_time = ((unsigned) buffer[1]) * 256 + ((unsigned) buffer[0]);
  // Se a flag de transparência estiver ativa, o valor que lemos em
  // seguida é o índice da cor que devemos considerar transparente:
  fread(buffer, 1, 1, fp);
  transparency_index = buffer[0];
  // Este bloco nunca tem mais nenhum dado. Fazemos mais uma leitura
  // adicional só para ler o último byte com valor zero e que encerra
  // o bloco:
  fread(buffer, 1, 1, fp);
}
@

Em suma, a extensão de controle de gráficos permite a nós obtermos os
valores das nossas variáveis |disposal_method|,
|transparent_color_flag|, |delay_time| e |transparency_index|. Mas
tais informações são sempre locais a uma dada imagem que é lida em
seguida. E não só imagem. Se existir uma extensão de texto puro em
seguida desta extensão de controle de gráficos, esses dados valem só
para ele. Então, após lermos uma extensão de texto puro temos que
reinicializar os valores:

@<GIF: Após Extensão de Texto Puro@>=
{
  disposal_method = 0;
  transparent_color_flag = false;
  delay_time = 0;
  transparency_index = 0;
}
@

Mas a extensão de texto puro é algo raro, que é improvável que
encontremos pela frente. O que provavelmente encontraremos logo após
uma extensão de controle de gráficos (e talvez sem a presença de um
controle de gráficos) é um descritor de imagem. Um arquivo GIF pode
ter várias imagens e cada uma delas terá o seu descritor. Geralmente
em um GIF animado cada frame da animação é uma imagem. Assim começamos
a ler um descritor de imagem:

@<GIF: Bloco Descritor de Imagem@>=
{
  bool local_color_table_flag = false, interlace_flag = false;
  unsigned local_color_table_size;
  int lzw_minimum_code_size;
  // Lendo o offset horizontal da imagem:
  unsigned char buffer[256];
  fread(buffer, 1, 2, fp);
  img_offset_x = ((unsigned) buffer[1]) * 256 + ((unsigned) buffer[0]);
  printf("(%d %d) -> img_offset_x: %d\n", buffer[0], buffer[1], img_offset_x);
  // Offset vertical da imagem:
  fread(buffer, 1, 2, fp);
  img_offset_y = ((unsigned) buffer[1]) * 256 + ((unsigned) buffer[0]);
  // Largura da imagem:
  fread(buffer, 1, 2, fp);
  img_width = ((unsigned) buffer[1]) * 256 + ((unsigned) buffer[0]);
  // Altura da imagem:
  fread(buffer, 1, 2, fp);
  img_height = ((unsigned) buffer[1]) * 256 + ((unsigned) buffer[0]);
  // E agora preenchemos as informações sobre a imagem obtidas no
  // próximo byte:
  fread(buffer, 1, 1, fp);
  local_color_table_flag = buffer[0] >> 7;
  interlace_flag = (buffer[0] >> 6) % 2;
  local_color_table_size = buffer[0] % 8;
  if(local_color_table_flag){
    @<GIF: Tabela de Cor Local@>
  }
  @<GIF: Dados de Imagem@>
}
@

No caso da imagem possuir uma tabela de cores local, ela é armazenada
de forma idêntica à tabela de cores global:

@<GIF: Tabela de Cor Local@>=
{
  printf("(Tabela de cor local)\n");
  unsigned long size = 3 * (1 << (global_color_table_size + 1));
  local_color_table = (unsigned char *) _iWalloc(size);
  if(local_color_table == NULL){
    fprintf(stderr, "WARNING: Not enough memory to read image. Please, increase "
            "the value of W_MAX_MEMORY at conf/conf.h.\n");
    goto error_gif;
  }
  // E agora lemos a tabela local de cores:
  fread(local_color_table, 1, size, fp);
}
@

E por fim chegamos ao trecho principal: o bloco onde estão armazenados
os dados da imagem propriamente dita:

@<GIF: Dados de Imagem@>=
{
  printf("(Imagem)\n");
  fread(buffer, 1, 1, fp);
  lzw_minimum_code_size = buffer[0];
  printf("LZW Minimum Code Size: %d\n", lzw_minimum_code_size);
  @<GIF: Inicializando Nova Imagem@>
  fread(buffer, 1, 1, fp);
  while(buffer[0] != 0){
    //printf("Will read %d bytes.\n", buffer[0]);
    fread(buffer, 1, buffer[0], fp);
    fread(buffer, 1, 1, fp);
  }
  // Depois de lermos uma imagem, os valores ajustados pelo controle
  // de gráficos devem ser reinicializados novamente:
  disposal_method = 0;
  transparent_color_flag = false;
  delay_time = 0;
  transparency_index = 0;
}
@

E agora chegamos ao momento em que teremos que implementar o algoritmo
de descompactação Lempel–Ziv–Welch. O malfadado algoritmo que apesar
de ser interessante, no passado era patenteado e isso fez com que ele
não pudesse ser livremente usado em vários países. Atualmente suas
patentes já expiraram, então podemos usá-lo sem medo das polêmicas.

Bom, antes de mais nada vamos alocar o espaço para a nossa imagem, uma
vez que já sabemos o tamanho dela. Vamos fazer isso na inicialização
da imagem. Mas é importante lembrar que talvez não tenhamos apenas uma
imagem. Um GIF animado pode ter várias delas. Sendo assim, vamos
definir uma estrutura de dados que será basicamente uma lista
encadeada de imagens:

@<GIF: Declarações@>+=
struct _image_list{
  char *rgba_image;
  struct _image_list *next, *prev;
};
@

Desalocar a lista de imagens, dado o seu último elemento pode ser
feito com:

@<GIF: Funções Estáticas@>=
static void free_img_list(struct _image_list *last){
  struct _image_list *p = last, *tmp;
  while(p != NULL){
    Wfree(p -> rgba_image);
    tmp = p;
    p = p -> prev;
    Wfree(tmp);
  }
}
@

E toda vez que formos ler uma nova imagem no nosso arquivo GIF,
aumentamos o tamanho de nossa lista e atualizamos os ponteiros para a
última imagem da lista:

@<GIF: Inicializando Nova Imagem@>=
{
  struct _image_list *new_image;
  new_image = (struct _image_list *) _iWalloc(sizeof(struct _image_list));
  if(new_image == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_gif;
  }
  new_image -> prev = new_image -> next = NULL;
  new_image -> rgba_image = (char *) _iWalloc((*width) * (*height) * 4);
  if(new_image -> rgba_image == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_gif;
  }
  if(img == NULL){
    img = new_image;
    last_img = img;
  }
  else{
    last_img -> next = new_image;
    new_image -> prev = last_img;
    last_img = new_image;
  }
  printf("inicializada imagem %d x %d.\n", *width, *height);
  // Se a nossa imagem não ocupa todo o canvas, vamos inicializar
  // todos os valores com a cor de fundo do canvas, já que há regiões
  // nas quais nossa imagem não irá estar. Mas também só podemos fazer
  // isso se temos uma tabela de cores.
  if(img_offset_x != 0 || img_offset_y != 0  || img_width != *width ||
     img_height != *height){
    if(local_color_table_flag || global_color_table_flag){
      printf("Preenchendo fundo da imagem. (%d %d %d %d)\n",
             img_offset_x, img_offset_y, img_width, img_height);
      unsigned long i;
      unsigned long size = (*width) * (*height);
      for(i = 0; i < size; i += 4){// Se temos uma tabela local, usamos ela
        if(local_color_table_flag){
          new_image -> rgba_image[4 * i] = local_color_table[3 * background_color];
          new_image -> rgba_image[4 * i + 1] =
            local_color_table[3 * background_color + 1];
          new_image -> rgba_image[4 * i + 2] =
            local_color_table[3 * background_color + 2];
          new_image -> rgba_image[4 * i + 3] = 255;
        }
        else{// Senão, usamos a tabela de cores global
          new_image -> rgba_image[4 * i] =
            global_color_table[3 * background_color];
          new_image -> rgba_image[4 * i + 1] =
            global_color_table[3 * background_color + 1];
          new_image -> rgba_image[4 * i + 2] =
            global_color_table[3 * background_color + 2];
          new_image -> rgba_image[4 * i + 3] = 255;
        }
      }
    }
  }
}
@

Agora durante o encerramento temos que desalocar a memória ocupada
pela nossa lista de imagens:

@<Encerrando Arquivo GIF@>=
  if(img != NULL)
    free_img_list(last_img);
@
