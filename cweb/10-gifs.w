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
unsigned char *_extract_gif(char *filename, unsigned long *, unsigned long *,
                            unsigned *, float *, float *,
                            bool *);
@

@<GIF: Definições@>=
unsigned char *_extract_gif(char *filename, unsigned long *width,
                            unsigned long *height, unsigned *number_of_frames,
                            float *times, float *max_t,
                            bool *error){
  bool global_color_table_flag = false, local_color_table_flag = false;
  bool transparent_color_flag = false;
  unsigned local_color_table_size = 0, global_color_table_size = 0;
  int color_resolution;
  unsigned long image_size;
  unsigned img_offset_x = 0, img_offset_y = 0, img_width = 0, img_height = 0;
  unsigned number_of_loops = 0;
  unsigned char *returned_data  = NULL;
  unsigned background_color, delay_time = 0, transparency_index = 0;
  unsigned char *global_color_table = NULL;
  unsigned char *local_color_table = NULL;
  int disposal_method = 0;
  struct _image_list *img = NULL; // A lista de imagens será definida logo mais.
  struct _image_list *last_img = NULL;
  *number_of_frames = 0;
  times = NULL;
  FILE *fp = fopen(filename, "r");
  *error = false;
#if W_TARGET == W_ELF && !defined(W_MULTITHREAD)
  _iWbreakpoint();
#endif
  if(fp == NULL){
    goto error_gif;
  }
  @<Interpretando Arquivo GIF@>
  @<GIF: Gerando Imagem Final@>
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
  image_size = (*width) * (*height);
  // Lemos o próximo byte de onde extraímos informações sobre algumas
  // flags:
  fread(data, 1, 1, fp);
  // Temos uma tabela de cores global?
  global_color_table_flag = (data[0] & 128);
  // O número de bits para cada cor primária menos um:
  color_resolution = (data[0] & 127) >> 4;
  // O tamanho da tabeela de cores caso ela exista:
  global_color_table_size = data[0] % 8;
  global_color_table_size = 3 * (1 << (global_color_table_size + 1));
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
  global_color_table = (unsigned char *) _iWalloc(global_color_table_size);
  if(global_color_table == NULL){
    fprintf(stderr, "WARNING: Not enough memory to read image. Please, increase "
            "the value of W_MAX_MEMORY at conf/conf.h.\n");
    goto error_gif;
  }
  // E agora lemos a tabela global de cores:
  fread(global_color_table, 1, global_color_table_size, fp);
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
    printf("Block %d: ", block_type);
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
  bool interlace_flag = false;
  int lzw_minimum_code_size;
  // Lendo o offset horizontal da imagem:
  unsigned char buffer[257];
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
  local_color_table_size = 3 * (1 << (local_color_table_size + 1));
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
  local_color_table = (unsigned char *) _iWalloc(local_color_table_size);
  if(local_color_table == NULL){
    fprintf(stderr, "WARNING: Not enough memory to read image. Please, increase "
            "the value of W_MAX_MEMORY at conf/conf.h.\n");
    goto error_gif;
  }
  // E agora lemos a tabela local de cores:
  fread(local_color_table, 1, local_color_table_size, fp);
}
@

E por fim chegamos ao trecho principal: o bloco onde estão armazenados
os dados da imagem propriamente dita:

@<GIF: Dados de Imagem@>=
{
  int buffer_size;
  @<GIF: Variáveis Temporárias para Imagens Lidas@>
  printf("(Imagem)\n");
  fread(buffer, 1, 1, fp);
  lzw_minimum_code_size = buffer[0];
  printf("LZW Minimum Code Size: %d\n", lzw_minimum_code_size);
  @<GIF: Inicializando Nova Imagem@>
  fread(buffer, 1, 1, fp);
  while(buffer[0] != 0){
    buffer_size = buffer[0];
    buffer[buffer_size] = '\0';
    fread(buffer, 1, buffer[0], fp);
    @<GIF: Interpretando Imagem@>
    fread(buffer, 1, 1, fp);
  }
  @<GIF: Finalizando Nova Imagem@>
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
  unsigned char *rgba_image;
  float delay_time; // Para imagens animadas
  struct _image_list *next, *prev;
};
@

Desalocar a lista de imagens, dado o seu último elemento pode ser
feito com:

@<GIF: Funções Estáticas@>=
#if W_TARGET != W_ELF || defined(W_MULTITHREAD)
static void free_img_list(struct _image_list *last){
  struct _image_list *p = last, *tmp;
  while(p != NULL){
    Wfree(p -> rgba_image);
    tmp = p;
    p = p -> prev;
    Wfree(tmp);
  }
}
#endif
@

E toda vez que formos ler uma nova imagem no nosso arquivo GIF,
aumentamos o tamanho de nossa lista e atualizamos os ponteiros para a
última imagem da lista:

@<GIF: Inicializando Nova Imagem@>=
{
  struct _image_list *new_image;
  *number_of_frames = (*number_of_frames ) + 1;
  // Se nós não temos uma tabela de cores, isso é um erro. Vamos parar
  // agora mesmo.
  if(!local_color_table_flag && !global_color_table_flag){
    fprintf(stderr, "WARNING: GIF image without a color table: %s\n", filename);
    goto error_gif;
  }
  new_image = (struct _image_list *) _iWalloc(sizeof(struct _image_list));
  if(new_image == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_gif;
  }
  new_image -> prev = new_image -> next = NULL;
  new_image -> rgba_image = (unsigned char *) _iWalloc((*width) * (*height) * 4);
  if(new_image -> rgba_image == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_gif;
  }
  if(img == NULL){
    img = new_image;
    last_img = img;
    printf("img inicializado.\n");
  }
  else{
    last_img -> next = new_image;
    new_image -> prev = last_img;
    last_img = new_image;
  }
  last_img -> delay_time = ((float) delay_time) / 100.0;
  printf("inicializada imagem %lu x %lu.\n", *width, *height);
  // Se a nossa imagem não ocupa todo o canvas, vamos inicializar
  // todos os valores com a cor de fundo do canvas, já que há regiões
  // nas quais nossa imagem não irá estar. Mas também só podemos fazer
  // isso se temos uma tabela de cores.
  if(img_offset_x != 0 || img_offset_y != 0  || img_width != *width ||
     img_height != *height){
    unsigned long i;
    unsigned long size = (*width) * (*height);
    // Se temos uma tabela local, usamos ela
    for(i = 0; i < size; i += 4){
      if(local_color_table_flag && background_color < local_color_table_size){
        new_image -> rgba_image[4 * i] = local_color_table[3 * background_color];
        new_image -> rgba_image[4 * i + 1] =
          local_color_table[3 * background_color + 1];
        new_image -> rgba_image[4 * i + 2] =
          local_color_table[3 * background_color + 2];
        new_image -> rgba_image[4 * i + 3] = 255;
      }
      // Se não, usamos a tabela de cores global.
      else if(background_color < global_color_table_size){
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
@

Agora durante o encerramento temos que desalocar a memória ocupada
pela nossa lista de imagens:

@<Encerrando Arquivo GIF@>=
  if(img != NULL)
    free_img_list(last_img);
@

Uma vez que estejamos lendo os dados no GIF, nós não encontraremos
nele um valor de pixel, ou mesmo de posições na nossa tabela de
cores. O que encontraremos serão códigos que geralmente são
representados pelo seu valor numérico preficado por um ``\#''. Sendo
assim, poderemos encontrar os códigos ``\#0'', ``\#1'', ``\#2'', até o
``\#4095'' que é o maior código permitido dentro de um GIF. Cada um
destes códigos precisa ser consultado em uma tabela de códigos e nela
obteremos o valor de um ou mais índices em nossa tabela de cores. Cada
código pode representar um índice ou então uma sequência de índices.

Entretanto, nós começamos sem uma tabela de códigos e o interessante
da compressão e descompressão de dados usando o algoritmo LZW é que
não é preciso inserir tal tabela junto com os dados compactados. À
medida que vamos lendo os dados compactados, somos também capazes de
deduzir qual a tabela de código usado pelo programa que comprimiu os
dados.

Para começar a preencher a tabela de códigos, nós primeiro precisamos
saber quantas posições tem a nossa tabela de cores. A primeira posição
da tabela de códigos, representada pelo código \#0 representa a
posição 0 na tabela de cores. A segunda posição, dada pelo código \#1
é a segunda posição na tabela de cores. E assim por diante. Sabemos
que a tabela de cores pode ter 2, 4, 8, 16, 32, 64, 128 ou 256
posições diferentes. Estas posições iniciais, nós não precisamos nunca
inicializar ou ler, já que seus valores nunca mudam.

Nossa tabela de códigos é então esta:

@<GIF: Variáveis Temporárias para Imagens Lidas@>=
  char *code_table[4095];
int last_value_in_code_table;
@

Mas o número de posições iniciais da nossa tabela que já começarão
inicializadas na verdade não depende do tamanho de nossa tabela de
cores, mas sim da variável |lzw_minimum_code_size|. Essa variável é
lida no começo do bloco da imagem no arquivo GIF e pode legalmente ter
7 valores diferentes: 2, 3, 4, 5, 6, 7 ou 8. Um valor diferente disso
é inválido:

@<GIF: Inicializando Nova Imagem@>+=
{
  if(lzw_minimum_code_size < 2 || lzw_minimum_code_size > 8){
    fprintf(stderr, "WARNING (0): Invalid GIF file %s. Not allowed LZW Minimim "
            " code size.\n", filename);
    goto error_gif;
  }
}
@

O valor nesta variável nos diz quantos valores da nossa tabela de
códigos deve já começar inicializada e sempre deve se manter
inicializada:

@<GIF: Inicializando Nova Imagem@>+=
{
  int i;
  switch(lzw_minimum_code_size){
  case 2:
    last_value_in_code_table = 3;
    break;
  case 3:
    last_value_in_code_table = 7;
    break;
  case 4:
    last_value_in_code_table = 15;
    break;
  case 5:
    last_value_in_code_table = 31;
    break;
  case 6:
    last_value_in_code_table = 63;
    break;
  case 7:
    last_value_in_code_table = 127;
    break;
  case 8:
  default:
    last_value_in_code_table = 255;
    break;
  }
  for(i = 0; i <= last_value_in_code_table; i ++)
    code_table[i] = NULL;
}
@

Depois destes valores, sempre colocamos dois valores a mais na tabela
de código. Um deles é o chamado ``clear code''. É um código que
representa uma instrução de que devemos esvaziar a tabela deixando ela
com o mínimo de valores possível (somente os valores iniciais que
inicializamos acima mais os dois que estamos definindo agora). O
pŕoximo é o ``end of information code'', que representa o fato de
termos chegado ao fim da imagem (se encontramos este código ou não,
iremos armazenar em uma variável booleana).

@<GIF: Variáveis Temporárias para Imagens Lidas@>+=
  unsigned clear_code, end_of_information_code;
  bool end_of_image = false;
@

@<GIF: Inicializando Nova Imagem@>+=
{
  clear_code = last_value_in_code_table + 1;
  end_of_information_code = last_value_in_code_table + 2;
  last_value_in_code_table = end_of_information_code;
  code_table[clear_code] = NULL;
  code_table[end_of_information_code] = NULL;
}
@

Agora vamos ter que ler os códigos que estão armazenados no GIF. Para
cada código que lemos, pode ser que tenhamos que inserir mais coisas
na tabela de códigos, ou mesmo pode ser que tenhamos que
esvaziá-la. Nós também temos que ler sempre a menor quantidade de bits
capaz de armazenar o maior número que pode ser lido. No começo, nós
sempre lemos um número de bits igual a |lzw_minimum_code_size| mais
1. Assim podemos encontrar qualquer código do #0 até o código de fim
da imagem. À medida que nossa tabela ficar maior, o número de bits que
lemos vai crescer, até o limite de 12 bits. O número de bits que
devemos ler vai ser armazenado na seguinte variável:

@<GIF: Variáveis Temporárias para Imagens Lidas@>+=
int bits;
@

@<GIF: Inicializando Nova Imagem@>+=
{
  bits = lzw_minimum_code_size + 1;
}
@
    
O fato de não lermos bytes,mas uma quantidade variável de bits da
entrada faz com que tenhamos que tomar cuidado na leitura dos
dados. Nós sempre colocamos os dados a serem lidos em um buffer que é
na verdade uma string. Então, ao lermos tal buffer, temos que manter
duas variáveis. A primeira conta em qual byte devemos continuar a
nossa leitura do buffer. E a segunda de qual bit dentro deste byte nós
devemos continuar:

@<GIF: Variáveis Temporárias para Imagens Lidas@>+=
int byte_offset = 0, bit_offset = 0; 
unsigned code = 0;
// Essa variável vai nos ajudar caso uma parte dos bits de nosso
// código esteja no buffer atual e a outra parte no buffer que ainda
// está para ser lido:
bool incomplete_code = false;
// E isso nos diz qual pixel estamos lendo
unsigned long pixel = 0;
@

E a leitura do buffer então funciona assim:

@<GIF: Interpretando Imagem@>=
byte_offset = 0;
if(!incomplete_code)
  bit_offset = 0;
while(byte_offset < buffer_size && !end_of_image && pixel < image_size){
  if(incomplete_code){
    // Temos que ler 'bits' bits, mas já lemos '-bit_offset'
    code += (unsigned char) (buffer[byte_offset] << bit_offset);
    incomplete_code = false;
    bit_offset = bit_offset + bits - 8;
  }
  else{ // O caso típico
    if(bit_offset + bits <= 8){
      code = (unsigned char) (buffer[byte_offset] << (8 - bit_offset - bits));
      code = code >> (8 - bits);
    }
    else{
      if(byte_offset + 1 == buffer_size){
        code = (unsigned char) (buffer[byte_offset] >> bit_offset);
        incomplete_code = true;
      }
      else{
        code = (unsigned char) (buffer[byte_offset] >> bit_offset);
        code += (unsigned char) (buffer[byte_offset + 1] << bit_offset);
        code = (unsigned char) (code << (16 - bits - bit_offset));
        code = code >> (16 - bits - bit_offset);
      }
    }
  }
  if(!incomplete_code){
    printf("[%d %d %d] #%d\n", byte_offset, bit_offset, bits, code);
    bit_offset += bits;
    if(bit_offset >= 8){
      bit_offset = bit_offset % 8;
      byte_offset += 1;
    }
    // Aqui já extraímos o nosso código :-D !
    @<GIF: Interpreta Códigos Lidos@>
  }
  else break;
}
@

Quando formos traduzir os códigos para uma posiçãoo na tabela de
cores, é bom sabermos se devemos ler da tabela de cores local ou
global:

@<GIF: Variáveis Temporárias para Imagens Lidas@>+=
unsigned char *color_table;
@

@<GIF: Inicializando Nova Imagem@>+=
  if(local_color_table_flag)
    color_table = local_color_table;
  else
    color_table = global_color_table;
@

E colocamos abaixo o código que nos permite traduzir os códigos que
lemos para cores:

@<GIF: Interpreta Códigos Lidos@>=
{
  if(pixel == 0){
    // Se a imagem começa com um CLEAR CODE, só seguimos em frente:
    if(code == clear_code)
      continue;
    // O primeiro pixel é traduzido diretamente para uma posição na
    // tabela de cores:
    last_img -> rgba_image[0] = color_table[3 * code];
    last_img -> rgba_image[1] = color_table[3 * code + 1];
    last_img -> rgba_image[2] = color_table[3 * code + 2];
    if(transparent_color_flag && transparency_index == code)
      last_img -> rgba_image[3] = 0;
    else
      last_img -> rgba_image[3] = 255;
    printf("(%d %d %d %d)\n", last_img -> rgba_image[0], last_img -> rgba_image[1],
           last_img -> rgba_image[2], last_img -> rgba_image[3]);
    pixel ++;
  }
}
@

Depois que terminamos de extrair nossa imagem, temos que esvaziar a
nossa tabela de códigos. Nós desalocamos todos o scódigos definidos e
que não são os códigos iniciais cujo valor é |NULL| mesmo:

@<GIF: Finalizando Nova Imagem@>=
{
  unsigned i;
  for(i = last_value_in_code_table; i != end_of_information_code; i --)
    Wfree(code_table[i]);
}
@

E depois que percorremos todas as imagens presentes em nosso GIF,
temos que montar a imagem que iremos retornar. A imagem final deve ter
uma largunra igual ao tamanho da nossa tela de pintura lógica
multiplicado pelo número de frames da imagem ou animação. A altura da
imagem final deve ser a mesma altura da tela de pintura lógica. A
ideia é que iremos representar todos os frames de uma animação em uma
única imagem sequencial. Depois, Weaver fará com que eles apareçam na
tela animados por meio de seu código e shaders.

Além disso, caso a imagem tenha mais de um frame (seja uma animação),
devemos retornar um vetor que floats que representam quanto tempo em
segundo cada frame deve permanecer na animação até passar para o
próximo frame.
  
@<GIF: Gerando Imagem Final@>=
{
  unsigned i, line, col;
  unsigned long source_index, target_index;
  float total_time = INFINITY;
  struct _image_list *p;
  returned_data = (unsigned char *) Walloc(4 * (*width) * (*height) *
                                           (*number_of_frames));
  if(returned_data == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_gif;
  }
  if(*number_of_frames > 1){
    total_time = 0.0;
    times = (float *) Walloc(*number_of_frames * sizeof(float));
    if(times == NULL){
      fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
              "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              filename);
      Wfree(returned_data);
      returned_data = NULL;
      goto error_gif;
    }
  }
  p = img;
  for(i = 0; i < *number_of_frames; i ++){
    line = col = 0;
    if(*number_of_frames > 1){
      times[i] = p -> delay_time;
      total_time += times[i];
    }
    while(line < (*height)){
      while(col < (*width)){
        source_index = line * (*width) * 4 + col * 4;
        target_index = 4 * (*width) * (*number_of_frames) * line + (*width) * i * 4
          + col * 4; 
        returned_data[target_index] = p -> rgba_image[source_index];
        returned_data[target_index + 1] = p -> rgba_image[source_index + 1];
        returned_data[target_index + 2] = p -> rgba_image[source_index + 2];
        returned_data[target_index + 3] = p -> rgba_image[source_index + 3];
        col ++;
      }
      line ++;
      col = 0;
    }
    p = p -> next;
    line = col = 0;
  }
  if(number_of_loops == 0)
    *max_t = INFINITY;
  else
    *max_t = total_time * number_of_loops;
}
@

@*2 Integrando Imagens GIF às Interfaces.

Usar a nossa função que definimos para carregar GIFs de modo a criar
uma interface não é tão diferente do trabalho que tivemos para
integrar os sons WAVE na nossa engine. É basicamente isso, mas com
algumas modificações adicionais às Interfaces.

Primeiro, de agora em diante será importante que toda interface tenha
uma textura e também uma variável booleana para indicar se a textura
já foi carregada. Também, caso a imagem seja uma animação, teremos que
informar o número de frames dela e a quantos frames por segundo ela
está rodando. Ela também irá armazenar um novo atributo |t|, que
indica o tempo contado em segundos desde que ela foi criada e o
|max_t| que é o valor máximo que |t| pode ter. Tudo isso é útil para
animações. Inclusive teremos a variável |dt| que armazenará quanto
tempo em seundos deve durar cada quadro de animação:

@<Interface: Atributos Adicionais@>=
// Isso fica dentro da definição de 'struct interface':
GLuint _texture;
bool _loaded_texture;
unsigned number_of_frames;
float t, max_t, dt;
// Onde a textura será armazenada apenas temporariamente antes de
// enviar para a plaa de vídeo. Precisamos que seja em uma variável
// persistente, e não local, pois podemos precisar carregar a textura
// assincronamente:
unsigned char *_tmp_texture;
@

Estes valores precisam ser inicializados. Inicializá-los é fácil, só a
textura é que é um pouco diferente. Como estes são atributos que todas
as imagens vão ter, vamos precisar criar uma textura padrão e
transparente que será a usada nas interfaces que não possuem textura.

Nossa tetura padrão e transparente será criada na inicialização e
removida na finalização:

@<Cabeçalhos Weaver@>+=
GLuint _empty_texture;
char _empty_image[4];
@

@<API Weaver: Inicialização@>+=
{
  _empty_image[0] = _empty_image[1] = _empty_image[2] = _empty_image[3] = '\0';
  glGenTextures(1, &_empty_texture);
  glBindTexture(GL_TEXTURE_2D, _empty_texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 64, 0, GL_RGBA,
               GL_UNSIGNED_BYTE, &_empty_texture);
  glBindTexture(GL_TEXTURE_2D, 0);
}
@

@<API Weaver: Finalização@>+=
{
  glDeleteTextures(1, &_empty_texture);
}
@

E então, quando inicializamos uma interface, podemos inicializar
também estes novos valores:

@<Interface: Inicialização Adicional@>=
{
  _texture = _empty_texture;
  // Por padrão, ainda nem sabemos se a interface terá uma
  // textura. Assim que detectarmos que ela terá, mudamos isso para
  // falso, e aí para verdadeiro de novo quando ela terminar de
  // carregar a textura:
  _interfaces[_number_of_loops][i]._loaded_texture = true;
  _interfaces[_number_of_loops][i].t = 0.0;
  _interfaces[_number_of_loops][i].dt = 0.0;
  _interfaces[_number_of_loops][i].max_t = INFINITY;
  _interfaces[_number_of_loops][i].number_of_frames = 1;
}
@

Mas quando a interface vai usar uma textura diferente? As interfaces
declaradas como |W_INTERFACE_PERIMETER| e |W_INTERFACE_SQUARE| não
possuem texturas. Vamos criar então um novo tipo de interface:
|W_INTERFACE_IMAGE|, que representa interfaces criadas à partir de
arquivos de imagem.

@<Interface: Declarações@>+=
#define W_INTERFACE_IMAGE -3
@

E agora definimos o que acontece quando estamos inicializando uma nova
interface, lendo seus argumentos e sabemos que estamos diante de uma
destas intrfaces de imagens:

@<Interface: Leitura de Argumentos e Inicialização@>=
case W_INTERFACE_IMAGE:
  _interfaces[_number_of_loops][i]._loaded_texture = false;
{
#if W_TARGET == W_WEB
  char dir[] = "image/";
#elif W_DEBUG_LEVEL >= 1
  char dir[] = "./image/";
#elif W_TARGET == W_ELF
  char dir[] = W_INSTALL_DATA"/image/";
#endif
#if W_TARGET == W_ELF && !defined(W_MULTITHREAD)
  char *ext;
  bool ret = true;
#endif
  char *filename, complete_path[256];
  unsigned long texture_width, texture_height;
  va_start(valist, height);
  filename = va_arg(valist, char *);
  va_end(valist);
  // Obtendo o caminho do arquivo de áudio:
  strncpy(complete_path, dir, 256);
  complete_path[255] = '\0';
  strncat(complete_path, filename, 256 - strlen(complete_path));
#if W_TARGET == W_WEB || defined(W_MULTITHREAD)
  // Rodando assincronamente
#if W_TARGET == W_WEB
  mkdir("images/", 0777); // Emscripten
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(W._pending_files_mutex));
#endif
  W.pending_files ++;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(W._pending_files_mutex));
#endif
  // Obtendo arquivo via Emsripten
  emscripten_async_wget2(complete_path, complete_path,
                         "GET", "",
                         (void *) &(_interfaces[_number_of_loops][i]),
                         &onload_texture, &onerror_texture,
                         &onprogress_texture);
#else
  // Obtendo arquivo via threads
  _multithread_load_file(complete_path,
                         (void *) &(_interfaces[_number_of_loops][i]),
                         &process_texture,
                         &onload_texture, &onerror_texture);  
#endif
#else
  // Rodando sincronamente:
  ext = strrchr(filename, '.');
  if(! ext){
    fprintf(stderr, "WARNING (0): No file extension in %s.\n",
            filename);
    _interfaces[_number_of_loops][i].type = W_NONE;
    return NULL;
  }
  if(!strcmp(ext, ".gif") || !strcmp(ext, ".GIF")){ // Suportando .wav
    float *times = NULL;
    _interfaces[_number_of_loops][i]._tmp_texture =
      _extract_gif(complete_path, &texture_width, &texture_height,
                  &(_interfaces[_number_of_loops][i].number_of_frames),
                  times, &(_interfaces[_number_of_loops][i].max_t),
                  &ret);
    if(ret){ // Se algum erro aconteceu:
      _interfaces[_number_of_loops][i].type = W_NONE;
      return NULL;
    }
    // Depois temos que finalizar o nosso recurso quando ele for limpo
    // pelo coletor de lixo. para ele, finalizar significa apagar a
    // textura OpenGL:
    _finalize_after(&(_interfaces[_number_of_loops][i]),
                    _finalize_interface_texture);
    // Preenchemos dt e ignoramos o tempo de duração de cada frame
    // além do primeiro. Um GIF pode ter cada quadro com uma duração
    // diferente. Mas para facilitar os nossos shaders, não
    // suportaremos isso. Sempre asumiremos que cada frame tem a mesma
    // duração e usamos a duração do primeiro como métrica. Se
    // detectarmos que existem muitos GIFs com quadros de diferentes
    // durações, aí é melhor rever isso:
    if(_interfaces[_number_of_loops][i].number_of_frames > 1){
      _interfaces[_number_of_loops][i].dt = times[0];
      Wfree(times);
    }
    // Agora temos que criar a nossa textura e inicializá-la:
    glGenTextures(1, &(_interfaces[_number_of_loops][i]._texture));
    glBindTexture(GL_TEXTURE_2D, _interfaces[_number_of_loops][i]._texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texture_width, texture_height, 0,
                 GL_RGBA, GL_UNSIGNED_BYTE,
                 _interfaces[_number_of_loops][i]._tmp_texture);
    glBindTexture(GL_TEXTURE_2D, 0);
    // Não precisamos mais manter a textura localmente agora que já a
    // enviamos para a placa de vídeo:
    Wfree(_interfaces[_number_of_loops][i]._tmp_texture);
  }
#endif
}
  break;
@

E é isso que cria uma nova interface com textura. Mas nós agora
precisamos criar uma série de funções auxiliares que invocamos
acima. Elas são |onload_texture| (a ser executada em ambiente web após
fazermos o download do arquivo GIF), |onerror_texture| (a ser
executada se um erro ocorrer quando carregamos o arquivo
assincronamente), |onprogress_texture| (uma função vazia quenão faz
nada a ser invocada à medida que baixamos o arquivo),
|process_texture| (uma função a ser executada caso estejamos
carregando com threads e que irá funcionar em uma thread) e
|_finalize_interface_texture| (função que irá pedir para que a textura
seja removida da memória da placa de vídeo quando a interface for
desalocada).

Ao trabalho. Primeiro o |onload_texture| caso seja um programa web:

@<Interface: Funções Estáticas@>=
#if W_TARGET == W_WEB
static void onload_texture(unsigned undocumented, void *inter,
                           const char *filename){
  char *ext;
  bool ret = true;
  struct interface *my_interface = (struct interface *) inter;
  // Checando extensão
  ext = strrchr(filename, '.');  
  if(! ext){
    onerror_texture(0, inter, 0);
    return;
  }
  if(!strcmp(ext, ".gif") || !strcmp(ext, ".GIF")){ // Suportando .gif
    float *times = NULL;
    my_interface -> _tmp_texture =
      _extract_gif(complete_path, &texture_width,
                  &texture_height,
                  &(my_interface -> number_of_frames),
                  times, &(my_interface -> max_t), &ret);
  }
  if(ret){ // Se algum erro aconteceu:
    my_interface -> type = W_NONE;
    return NULL;
  }
  _finalize_after(my_interface, _finalize_interface_texture);
  if(my_interface -> number_of_frames > 1){
    my_interface -> dt = times[0];
    Wfree(times);
  }
  // Inicializando a tetura lida
  glGenTextures(1, &(my_interface -> _texture));
  glBindTexture(GL_TEXTURE_2D, my_interface -> _texture);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texture_width, texture_height, 0,
               GL_RGBA, GL_UNSIGNED_BYTE,
               my_interface -> _tmp_texture);
  glBindTexture(GL_TEXTURE_2D, 0);
  // A mudança final de flag:
  my_interface -> _loaded_texture = true;
  // Não precisamos mais manter a textura localmente agora que já a
  // enviamos para a placa de vídeo:
  Wfree(my_interface -> _tmp_texture);
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

E caso não estejamos executando em ambiente web, as assincronamente
usando threads:

@<Interface: Funções Estáticas@>=
#if W_TARGET == W_ELF && defined(W_MULTITHREAD)
// Recebe uma interface como argumento e preenchemos sua textura:
static void *onload_texture(void *p){
  struct _thread_file_info *file_info = (struct _thread_file_info *) p;
  struct interface * my_interface = (struct interface *) (file_info -> target);
  my_interface -> loaded = true;
  // Não precisamos mais manter a textura localmente agora que já a
  // enviamos para a placa de vídeo:
    Wfree(my_interface -> _tmp_texture);
  return NULL;
}

#endif
@

Em caso de erro, tudo o que fazemos é imprimir uma mensagem na tela
para avisar no caso de execução via web:

@<Interface: Funções Estáticas@>+=
#if W_TARGET == W_WEB
static void onerror_texture(unsigned undocumented, void *interface,
                          int error_code){
  fprintf(stderr, "WARNING (0): Couldn't load a texture file. Code %d.\n",
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

E no caso de execução via threads:

@<Interface: Funções Estáticas@>+=
#if W_TARGET == W_ELF && defined(W_MULTITHREAD)
static void *onerror_texture(void *p){
  struct _thread_file_info *file_info = (struct _thread_file_info *) p;
  fprintf(stderr, "Warning (0): Failed to load texture file: %s\n",
          file_info -> filename);
  return NULL;
}
#endif
@

A função que não faz nada e que será inocada à medida que baixamos o
arquivo via web:

@<Interface: Funções Estáticas@>+=
#if W_TARGET == W_WEB
static void onprogress_texture(unsigned int undocumented, void *snd,
                               int percent){
  return;
}
#endif
@

A função que irá fazer todo o trabalho de carregar a textura para a
interface em ambiente om threads nativas:

@<Interface: Funções Estáticas@>+=
#if defined(W_MULTITHREAD) && W_TARGET == W_ELF
static void *process_texture(void *p){
  char *ext;
  bool ret = true;
  struct _thread_file_info *file_info = (struct _thread_file_info *) p;
  struct sound *my_interface = (struct interface *) (file_info -> target);
  ext = strrchr(file_info -> filename, '.');  
  if(! ext){
    file_info -> onerror(p);
  }
  else if(!strcmp(ext, ".gif") || !strcmp(ext, ".GIF")){ // Suportando .gif
    float *times = NULL;
    my_interface -> _tmp_texture =
      _extract_gif(complete_path, &texture_width,
                  &texture_height,
                  &(my_interface -> number_of_frames),
                  times, &(my_interface -> max_t), &ret);
  }
  if(ret){ // Se algum erro aconteceu:
    my_interface -> type = W_NONE;
    return NULL;
  }
  _finalize_after(my_interface, _finalize_interface_texture);
  if(my_interface -> number_of_frames > 1){
    my_interface -> dt = times[0];
    Wfree(times);
  }
  // Inicializando a tetura lida
  glGenTextures(1, &(my_interface -> _texture));
  glBindTexture(GL_TEXTURE_2D, my_interface -> _texture);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texture_width, texture_height, 0,
               GL_RGBA, GL_UNSIGNED_BYTE,
               my_interface -> _tmp_texture);
  glBindTexture(GL_TEXTURE_2D, 0);
  if(ret){ // ret é verdadeiro caso um erro de extração tenha ocorrido
    file_info -> onerror(p);
  }
  else{
    file_info -> onload(p);
  }
  // Finalização:
#if W_THREAD_POOL == 0
  Wfree(p); // Sem pool de threads, nosso argumento foi alocado
            // dinamicamente e precisa ser destruído.
#endif
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&(W._pending_files_mutex));
#endif
  W.pending_files --;
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&(W._pending_files_mutex));
#endif
  return NULL;
}
#endif
@

E por fim a função para desalocar texturas na placa de vídeo:

@<Interface: Funções Estáticas@>+=
// Uma função rápida para desalocar buffers do OpenAL e que podemos
// usar abaixo:
static void _finalize_interface_texture(void *data){
  struct interface *p = (struct interface *) data;
  glDeleteTextures(1, &(p -> _texture));
}

@*1 Shader e Renderização.

Vamos agora criar o shader responsável por renderizar as imagens com
textura na tela. O que ele terá de diferente é que terá uma textura
que poderá acessar para preencher os seus pixels:

@<Shader: Atributos@>+=
uniform sampler2D texture1;
@

E usando esta textura, iremos poder renderizar a imagem extraída de
arquivo. No shader de vértice o que isso terá de diferente de outras
interfaces é só as coordenadas de textura que iremos passar:

@(project/src/weaver/vertex_image_interface.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 100
// Declarando a precisão para ser compatível com GLSL 2.0 se possível
#if GL_FRAGMENT_PRECISION_HIGH == 1
precision highp float;
precision highp int;
#else
precision mediump float;
precision mediump int;
#endif
precision lowp sampler2D;
precision lowp samplerCube;
// Todos os atributos individuais de cada vértice
@<Shader: Atributos@>
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
@<Shader: Uniformes@>

varying mediump vec2 coordinate;

void main(){
  gl_Position = model_view_matrix * vec4(vertex_position, 1.0);
  // Coordenada da textura:
  coordinate = vec2(((vertex_position[0] + 0.5)),
                    ((vertex_position[1] + 0.5)));
}
@

E no shader de fragmento usaremos enfim esta textura e coordenadas:

@(project/src/weaver/fragment_image_interface.glsl@>=
// Usamos GLSLES 1.0 que é suportado por Emscripten
#version 100
// Declarando a precisão para ser compatível com GLSL 2.0 se possível
#if GL_FRAGMENT_PRECISION_HIGH == 1
  precision highp float;
  precision highp int;
#else
  precision mediump float;
  precision mediump int;
#endif
  precision lowp sampler2D;
  precision lowp samplerCube;
// Atributos do objeto a ser renderizado (basicamente as coisas dentro
// do struct que representam o objeto)
@<Shader: Uniformes@>

varying mediump vec2 coordinate;

void main(){
    gl_FragData[0] = texture2D(texture1, coordinate);
}
@

Este shader precisa ser inserido e usado na nossa engine:

@<Shaders: Declarações@>=
extern char _vertex_image_interface[];
extern char _fragment_imageinterface[];
struct _shader _image_interface_shader;
@
@<Shaders: Definições@>=
char _vertex_interface[] = {
#include "vertex_image_interface.data"
        , 0x00};
char _fragment_interface[] = {
#include "fragment_image_interface.data"
    , 0x00};
@

Compilamos ele na inicialização:

@<API Weaver: Inicialização@>+=
{
  GLuint vertex, fragment;
  vertex = _compile_vertex_shader(_vertex_image_interface_texture);
  fragment = _compile_fragment_shader(_fragment_image_interface_texture);
  // Preenchendo variáeis uniformes e atributos:
  _image_interface_shader.program_shader =
    _link_and_clean_shaders(vertex, fragment);
  _image_interface_shader._uniform_texture1 =
    glGetUniformLocation(_framebuffer_shader.program_shader,
                         "texture1");
  _image_interface_shader._uniform_object_color =
    glGetUniformLocation(_framebuffer_shader.program_shader,
                         "object_color");
  _image_interface_shader._uniform_model_view =
    glGetUniformLocation(_framebuffer_shader.program_shader,
                         "model_view_matrix");
  _image_interface_shader._uniform_object_size =
    glGetUniformLocation(_framebuffer_shader.program_shader,
                         "object_size");
  _image_interface_shader._uniform_time =
    glGetUniformLocation(_framebuffer_shader.program_shader,
                         "time");
  _image_interface_shader._uniform_integer =
    glGetUniformLocation(_framebuffer_shader.program_shader,
                           "integer");
  _image_interface_shader._attribute_vertex_position =
    glGetAttribLocation(_framebuffer_shader.program_shader,
                        "vertex_position");
}
@
