@* Suporte a Gifs Animados.

Um GIF é um formato de arquivos e uma abreviação para Graphics
Interchange Format. É um formato bastante antigo criado em 1987 e que
ainda hoje é bastante usado por sua capacidade de representar
animações e de seu amplo suporte em navegadores de Internet.

O formato possui as suas limitações, pois o número máximo de cores que
cada imagem pode ter é restrita a 256 cores (dependendo da imagem isso
pode ser superando por meio de tabelas de cores locais). Cada cor pode
ter até 24 bits diferentes e não é possível representar graus
intermediários entre uma cor totalmente transparente e totalmente
opaca.

Devido ao amplo uso de GIFs para representar animações, Weaver usará
este formato como uma das formas possíveis de se representar
animações. No passado, este foi um formato bastante polêmico devido às
suas patentes que restringiam a implementação de softwares capazes de
lidar com GIFs em certos países. Entretanto, atualmente todas as
patentes relevantes do formato já expiraram.

A especificação mais recente do formato GIF é a 89a, criada em 1989 e
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
GLuint *_extract_gif(char *, unsigned *, unsigned  **, int *, bool *);
@

Esta função irá retornar um array com identificadores de texturas
OpenGL. Cada textura representa um frame da animação. Os argumentos
que iremos passar para a função são: o nome do arquivo que contém a
imagem GIF, e um monte de ponteiros para locais onde a função deverá
escrever informações sobre a imagem lida. Estas informações serão a
o número de frames da animação, um array com a
duração de cada frame em microssegundos, o número máximo de vezes que
a animação deve ser repetida (-1 se ela deve se repetir infinitamente)
e se ocorreu algum erro que impossibilitou carregar a imagem:

@<GIF: Definições@>=
GLuint *_extract_gif(char *filename, unsigned *number_of_frames,
                            unsigned  **frame_duration,
                            int *max_repetition, bool *error){
    // Inicializando variáveis da função de extração
    bool global_color_table_flag = false, local_color_table_flag = false;
    bool interlace_flag = false;
    bool transparent_color_flag = false;
    unsigned local_color_table_size = 0, global_color_table_size = 0;
    unsigned long image_size;
    unsigned img_offset_x = 0, img_offset_y = 0, img_width = 0, img_height = 0;
    unsigned number_of_loops = 0;
    GLuint *returned_data  = NULL;
    unsigned background_color, delay_time = 0;
    unsigned char transparency_index = 0;
    unsigned char *global_color_table = NULL;
    unsigned char *local_color_table = NULL;
    unsigned long width, height;
    int disposal_method = 0;
    struct _image_list *img = NULL;
    struct _image_list *last_img = NULL;
#ifdef W_MULTITHREAD
    GLXContext thread_context;
#endif
    *number_of_frames = 0;
    // Abrindo o arquivo da imagem
    FILE *fp = fopen(filename, "r");
    *error = false;
#if W_TARGET == W_ELF && !defined(W_MULTITHREAD)
  _iWbreakpoint();
#endif
  // Como trataremos erros:
  if(fp == NULL){
    fprintf(stderr, "ERROR: Can't open file %s.\n", filename);
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
três bytes com a versão do formato usada. Existem duas versões
existentes. A mais antiga ``87a'', que foi a especificação
original que não suportava animações e transparência e a ``89a'' que
passou a suportar estas coisas.

@<Interpretando Arquivo GIF@>=
{
  char data[4];
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
encontraremos informações sobre o tamanho da tela lógica (basicamente
o tamanho final da nossa imagem), a cor de fundo desta tela lógica
(que cor usar em regiões não-desenhadas) e a proporção entre altura e
largura dos pixels que formam a imagem (ignorado pelos softwares
atuais). Por fim, também há algumas flags com informações adicionais.

@<Interpretando Arquivo GIF@>+=
{
  // Primeiro lemos a largura da imagem, a informação está presente nos
  // próximos 2 bytes (largura máxima: 65535 pixels)
  unsigned char data[2];
  fread(data, 1, 2, fp);
  width = ((unsigned long) data[1]) * 256 + ((unsigned long) data[0]);
  // Agora lemos a altura da imagem nos próximos 2 bytes (tamanho
  // máximo: 65535 pixels)
  fread(data, 1, 2, fp);
  height = ((unsigned long) data[1]) * 256 + ((unsigned long) data[0]);
  image_size = (width) * (height);
  // Lemos o próximo byte de onde extraímos informações sobre algumas
  // flags:
  fread(data, 1, 1, fp);
  // Temos uma tabela de cores global?
  global_color_table_flag = (data[0] & 128);
  // O tamanho da tabela de cores caso ela exista é definido por este
  // procedimento:
  global_color_table_size = data[0] % 8;
  global_color_table_size = 3 * (1 << (global_color_table_size + 1));
  // Lemos a cor de fundo de nosso GIF
  fread(&background_color, 1, 1, fp);
  // Lemos e ignoramos  a proporção de altura e largura de pixel
  fread(data, 1, 1, fp);
}
@

Agora o próximo passo é que se a imagem possui uma tabela de cores
global, nós devemos lê-la agora.

@<Interpretando Arquivo GIF@>+=
if(global_color_table_flag){
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
local. De qualquer forma, no fim da função teremos que desalocar
ambas:

@<Encerrando Arquivo GIF@>=
if(local_color_table != NULL) Wfree(local_color_table);
if(global_color_table != NULL) Wfree(global_color_table);
@

Agora a ideia é que sigamos lendo os próximos blocos. Os tipos de
blocos que poderemos encontrar são: descritores de imagem (o próximo
byte é 44), extensões (o próximo byte é 33) ou um marcador de fim dos
dados (o próximo byte é 59). Vamos agora ler vários blocos em
sequência, até que cheguemos no bloco que marca ofim de dados:

@<Interpretando Arquivo GIF@>+=
{
  unsigned block_type;
  unsigned char data[2];
  fread(data, 1, 1, fp);
  block_type = data[0];
  while(block_type != 59){
    switch(block_type){
    case 33: // Bloco de extensão
      @<GIF: Bloco de Extensão@>
      break;
    case 44: // Bloco de descritor de imagem
      @<GIF: Bloco Descritor de Imagem@>
      break;
    default: // Erro: Lemos um tipo desconhecido de bloco
      fprintf(stderr, "WARNING: Couldn't interpret GIF file %s. Invalid block "
              "%u.\n", filename, block_type);
      goto error_gif;
    }
    // Terminamos este bloco, lendo o próximo:
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
controle de gráficos (byte 249, informação sobre transparência e
animação), extensão de comentário (byte 254, serve para inserir na
imagem comentários que podem conter coisas que ignoraremos como a
autoria da imagem, copyright, etc), extensão de texto puro (byte 1,
hoje em dia é obsoleta) e extensão de aplicação (byte 255, GIFs
animados usam isso para definir quantas iterações terá a animação):

@<GIF: Bloco de Extensão@>=
{
  unsigned extension_type;
  fread(data, 1, 1, fp);
  extension_type = (unsigned) data[0];
  switch(extension_type){
  case 1: // Texto puro
    @<GIF: Extensão de Texto Puro@>
    break;
  case 249: // Controle de gráficos
    @<GIF: Extensão de Controle de Gráficos@>
    break;
  case 254: // Comentário
    @<GIF: Extensão de Comentário@>
    break;
  case 255: // Aplicação
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
a determinada aplicação. Geralmente seria algo a ser
ignorado. Entretanto, o Netscape 2.0 acabou usando certa vez este
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
que iremos simplesmente ignorar da mesma forma que ignoramos a
extensão de texto puro:

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
  // nas animações quando um frame mostra um pixel que seria
  // transparente ou deixa de preencher uma região. O valor de 0 e não
  // especificado e geralmente é encontrado em gifs não-animados. O
  // valor de 1 diz que deve-se repetir nestas regiões o que havia no
  // frame anterior. Um valor de 2 significa que deve-se preencher o
  // pixel com a cor de fundo do GIF. E um 3 deixa o pixel
  // verdadeiramente transparente.
  disposal_method = (buffer[0] >> 2) % 8;
  // Agora descobrimos se iremos suportar transparência
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
a ler um descritor de imagem (que talvez devesse ser chamada de
descritor de um frame da imagem):

@<GIF: Bloco Descritor de Imagem@>=
{
  int lzw_minimum_code_size;
  // Lendo o offset horizontal da imagem:
  unsigned char buffer[257];
  fread(buffer, 1, 2, fp);
  img_offset_x = ((unsigned) buffer[1]) * 256 + ((unsigned) buffer[0]);
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
  // Se as linhas estão armazenadas 'entrelaçadas' (para serem
  // exibidas mais rapidamente ao serem transmitidas por conexões
  // lentas):
  interlace_flag = (buffer[0] >> 6) % 2;
  // O tamanho da tabela de cores local (se existir):
  local_color_table_size = buffer[0] % 8;
  local_color_table_size = 3 * (1 << (local_color_table_size + 1));
  // Se temos uma tabela de cores local ou devemos usar a global:
  local_color_table_flag = buffer[0] >> 7;
  // Se temos tabela de cores local, lemos ela:
  if(local_color_table_flag){
    @<GIF: Tabela de Cor Local@>
  }
  @<GIF: Dados de Imagem@>
}
@

No caso da imagem possuir uma tabela de cores local, ela é armazenada
de forma idêntica à tabela de cores global. Como já sabemos o amanho
dela, basta lermos ela diretamente:

@<GIF: Tabela de Cor Local@>=
{
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
os dados da imagem propriamente dita (ou do frame de uma animação):

@<GIF: Dados de Imagem@>=
{
  int buffer_size;
  @<GIF: Variáveis Temporárias para Imagens Lidas@>
  // Lemos quantos bits cada código do algoritmo LZW tem. Cada código
  // representa uma sequência de 1 a 4091 cores e eles são como as
  // informações de cada pixel está armazenado no arquivo GIF. O
  // tamanho mínimo varia entre 2 bits e 8 bits. Se nossa tabela de
  // cores for muito pequena, dá para representar com menos bits suas
  // entradas, então o valor de bits será menor. Já se ela tiver 256
  // cores, aí precisaremos de 8 bits:
  fread(buffer, 1, 1, fp);
  lzw_minimum_code_size = buffer[0];
  @<GIF: Inicializando Nova Imagem@>
  // Leitura típica de dados em um GIF. Lemos uma série de dados onde
  // o primeiro byte representa a sequência de dados e um 0 significa
  // o fim dos dados:
  fread(buffer, 1, 1, fp);
  while(buffer[0] != 0){
    buffer_size = buffer[0];
    buffer[buffer_size] = '\0';
    fread(buffer, 1, buffer[0], fp);
    // E aqui lemos os códigos segundo o algoritmo LZW:
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
de descompactação Lempel–Ziv–Welch (LZW). O malfadado algoritmo que apesar
de ser interessante, no passado era patenteado e isso fez com que ele
não pudesse ser livremente usado em vários países. Atualmente suas
patentes já expiraram, então podemos usá-lo sem medo das polêmicas.

Bom, antes de mais nada vamos alocar o espaço para a nossa imagem, uma
vez que já sabemos o tamanho dela. Vamos fazer isso na inicialização
da imagem. Mas é importante lembrar que talvez não tenhamos apenas uma
imagem. Um GIF animado pode ter várias delas. Sendo assim, vamos
definir uma estrutura de dados que será basicamente uma lista
  encadeada de imagens. Nos GIFs animados, haverá uma para cada frame:

@<GIF: Declarações@>+=
struct _image_list{
  unsigned char *rgba_image; // Os pixels
  unsigned delay_time; // Em imagens animadas a duração do frame
  unsigned x_offset, y_offset, width, height; // Tamanho e offset
  int disposal_method; // Como devemos tratar pixels transparentes no
                       // próximo frame
  struct _image_list *next, *prev; // Lista duplamente encadeada
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
  // Cada nova imagem será tratada como um novo frame:
  *number_of_frames = (*number_of_frames ) + 1;
  // Se nós não temos uma tabela de cores, isso é um erro. Vamos parar
  // agora mesmo.
  if(!local_color_table_flag && !global_color_table_flag){
    fprintf(stderr, "WARNING: GIF image without a color table: %s\n", filename);
    goto error_gif;
  }
  // Alocamos e inicializamos a imagem na nossa lista de imagem:
  new_image = (struct _image_list *) _iWalloc(sizeof(struct _image_list));
  if(new_image == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_gif;
  }
  new_image -> prev = new_image -> next = NULL;
  new_image -> x_offset = img_offset_x;
  new_image -> y_offset = img_offset_y;
  new_image -> width = img_width;
  new_image -> height = img_height;
  new_image -> disposal_method = disposal_method;
  new_image -> rgba_image = (unsigned char *) _iWalloc(img_width *
                                                       img_height * 4);
  if(new_image -> rgba_image == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_INTERNAL_MEMORY at conf/conf.h.\n",
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
  last_img -> delay_time = delay_time * 10000;
  // Se a nossa imagem não ocupa todo o canvas, vamos inicializar
  // todos os valores com a cor de fundo do canvas, já que há regiões
  // nas quais nossa imagem não irá estar.
  if(img_offset_x != 0 || img_offset_y != 0  || img_width != width ||
     img_height != height){
    unsigned long i;
    unsigned long size = width * height;
    // Se temos uma tabela local, usamos ela, mas tomamos o cuidado
    // para não ler fora da tabela de cores mesmo que a imagem tenha
    // um valor inválido de cor de fundo
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
#if W_DEBUG_LEVEL >= 1
      // Em modo de depuração, nós avisamos quando a imagem tem um
      // valor inválido. Pode ser bom avisar, pois softwares menos
      // robustos podem ser vítimas de um buffer overflow ou falha de
      // segmentação com a imagem:
      else{
        fprintf(stderr, "WARNING: Image has invalid background color: %s.\n",
                filename);
      }
#endif
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

Vamos agora ler os códigos LZW da imagem. Iremos representá-los neste
texto pelo seu valor numérico prefixado por um ``\#''. Sendo assim,
poderemos encontrar os códigos ``\#0'', ``\#1'', ``\#2'', até o
``\#4095'' que é o maior código permitido dentro de um GIF. Cada um
destes códigos precisa ser consultado em uma tabela de códigos e nela
obteremos o valor de um ou mais índices em nossa tabela de cores. Cada
código pode representar um índice ou então uma sequência de índices.

Então para interpretarmos uma imagem, fazemos a seguinte
transformação:

\alinhaverbatim\
Código LZW -> Sequência de Índices na Tabela de Cores -> Sequência de Cores
\alinhanormal

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
unsigned char *code_table[4096];
int code_table_size[4096]; // O tamanho de cada valor armazenado em cada código
unsigned last_value_in_code_table;
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
  unsigned i;
  last_value_in_code_table = (1 << lzw_minimum_code_size) - 1;
  for(i = 0;  i <= last_value_in_code_table; i ++){
    code_table[i] = NULL;
    code_table_size[i] = 1;
  }
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
  code_table_size[clear_code] = 0;
  code_table[end_of_information_code] = NULL;
  code_table_size[end_of_information_code] = 0;
}
@

Agora vamos ter que ler os códigos que estão armazenados no GIF. Para
cada código que lemos, pode ser que tenhamos que inserir mais coisas
na tabela de códigos, ou mesmo pode ser que tenhamos que
esvaziá-la. Nós também temos que ler sempre a menor quantidade de bits
capaz de armazenar o maior número que pode ser lido. No começo, nós
sempre lemos um número de bits igual a |lzw_minimum_code_size| mais
1. Assim podemos encontrar qualquer código do \#0 até o código de fim
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
unsigned code = 0, previous_code;
// Essa variável vai nos ajudar caso uma parte dos bits de nosso
// código esteja no buffer atual e a outra parte no buffer que ainda
// está para ser lido:
bool incomplete_code = false;
// E isso nos quantos pixels já foram lidos:
unsigned long pixel = 0;
// Se estamos no primeiro pixel de um bufer:
bool first_pixel = true;
@

E a leitura do buffer para obter a cada iteração um código LZW
funciona assim:

@<GIF: Interpretando Imagem@>=
byte_offset = 0;
// Ao começar a ler um novo buffer, o offset de bits do primeiro pixel
// será zero. A menos que temos um valor que foi lido no buffer
// anterior, mas não foiterminado porque o seu fim está neste
// buffer. Para sinalizar isso, ajustamos o offseet para um valor
// negativo e por isso não devemos apagar esta informação
// reinicializando o offset de bits para zero:
if(!incomplete_code){
  bit_offset = 0;
}
// O loop que lê o buffer atual extraindo dele os códigos LZW:
while(byte_offset < buffer_size && !end_of_image && pixel < image_size){
  // Primeiro cuidamos do caso problemático de quando começamos agora
  // a ler um buffer, mas não terminamos de ler o valor do buffer
  // anterior:
  if(incomplete_code){
    incomplete_code = false;
    // Quantos bits ainda precisam ser lidos para terminar a leitura:
    int still_need_to_read = bits + bit_offset;
    unsigned tmp;
    // Sabemos que já lemos -(bit_offset) bits quando
    // temos que ler 'bits'.
    if(still_need_to_read <= 8){
      // Temos só mais um byte pra ler e terminar a leitura. Primeiro
      // jogamos fora os bits que fazem parte do próximo código, não
      // do atual:
      tmp = ((unsigned char) (buffer[0] << (8 - still_need_to_read)));
      // A juntamos o que restou com o que já foi lido:
      if(still_need_to_read - bit_offset <= 8)
        code += (tmp >> (8 - still_need_to_read + bit_offset));
      else
        code += (tmp << (still_need_to_read - bit_offset - 8));
      byte_offset += (bits + bit_offset) / 8;
      bit_offset = (bits + bit_offset) % 8;
    }
    else{
      // Temos que ler mais de um byte. Começamos lendo o primeiro
      // byte inteiro:
      code += buffer[byte_offset] << (-bit_offset);
      // E agora no próximo começamos removendo as partes que não
      // precisamos ainda:
      tmp = ((unsigned char) (buffer[byte_offset + 1] <<
                              (16 - still_need_to_read)));
      tmp = tmp >> (16 - still_need_to_read);
      // E adicionamos ao código:
      code += tmp << (8 - bit_offset);
      byte_offset += (bits + bit_offset) / 8;
      bit_offset = (bits + bit_offset) % 8;
    }
  }
  // A condição abaixo é para que sejamos capazes de fazer a leitura
  // completa neste buffer. Se ela não estiver presente, então temos
  // que fazer uma leitura cujo começo está neste buffer e o restante
  // no próximo:
  else if(bit_offset + bits <= 8 * (buffer_size - byte_offset)){
    // O que temos que ler está tudo no mesmo byte. O caso mais fácil.
    if(bit_offset + bits <= 8){
      // Jogamos fora o que já foi lido:
      code = (buffer[byte_offset] >> bit_offset);
      // Jogamos fora o que não precisamos ler ainda:
      code = (unsigned) ((unsigned char) (code << (8 - bits)));
      // E corrigimos a posição dos bits:
      code = code >> (8 - bits);
    }
    // Agora a condição no que o que temos para ler está nos próximos
    // 2 bytes:
    else if(bit_offset + bits <= 16){
      unsigned tmp;
      // Aproveitamos tudo do primeiro byte, menos o que já foi lido
      code = (buffer[byte_offset] >> bit_offset);
      // Aproveitamos tudo do segundo, menos o que não precisamos ler
      // ainda:
      tmp = (unsigned char)
        (buffer[byte_offset + 1] << (16 - bit_offset - bits));
      // Correção da posição dos bits
      tmp = (tmp >> (16 - bit_offset - bits));
      // Terminar de montar o código colocando os bits do segundo byte
      // após os bits do primeiro byte:
      code += (tmp << (8 - bit_offset));
    }
    // E por fim a condição na qual os valores que precisamos ler
    // estão espalhados em 3 bytes:
    else{
      unsigned tmp;
      // Aproveitamos tudo do primeiro byte, menos o que já foi lido
      code = (buffer[byte_offset] >> bit_offset);
      // Aproveitamos tudo do segundo byte:
      code += buffer[byte_offset + 1] << (8 - bit_offset);
      // Jogamos fora do terceiro byte o que só vamos ler no futuro:
      tmp = (unsigned char) (buffer[byte_offset + 2] <<
                             (24 - bit_offset - bits));
      // Correção da posição dos bits
      tmp = tmp >> (24 - bit_offset - bits);
      // Terminar de montar o código colocando os bits do terceiro
      // byte por último:
      code += (tmp << (16 - bit_offset));
    }
    bit_offset += bits;
    if(bit_offset >= 8){
      byte_offset += bit_offset / 8;
      bit_offset = bit_offset % 8;
    }
  }
  else{
    // Se estamos aqui, uma parte do nosso código está aqui e a
    // próxima está no próximo buffer a ser lido. Pode ser que
    // tenhamos 1 ou 2 bytes a ler agora.
    if(byte_offset == buffer_size - 1){
      // Se estamos aqui, temos 1 byte a ler no buffer atual
      code = (buffer[byte_offset] >> bit_offset);
      // O resto temos que ler no próximo buffer. Vamos indicar o
      // quanto temos que ler ajustando o 'bit_offset' para um valor
      // negativo:
      bit_offset = - (8 - bit_offset);
      byte_offset ++;
    }
    else{
      // Se estamos aqui, temos 2 bytes a ler no buffer atual. Lemos o
      // primeiro:
      code = (buffer[byte_offset] >> bit_offset);
      // Lemos o segundo byte inteiro
      code += buffer[byte_offset + 1] << (8 - bit_offset);
      // Indicamos no valor de bit_offset o quanto já lemos e
      // esperamos o próximo buffer:
      bit_offset = - (16 - bit_offset);
      byte_offset += 2;
    }
    incomplete_code = true;
    continue;
  }
  // O teste abaixo previne buffer overflow em imagens corrompidas:
  if(code > last_value_in_code_table + 1){
    code = end_of_information_code;
  }
  @<GIF: Interpreta Códigos Lidos@>
}
@

Quando formos traduzir os códigos para uma posição na tabela de
cores, é bom sabermos se devemos ler da tabela de cores local ou
global. Para que no nosso código não tenha que testarqual a tabela de
cores certa, armazenao essa inforação neste ponteiro:

@<GIF: Variáveis Temporárias para Imagens Lidas@>+=
unsigned char *color_table;
@

@<GIF: Inicializando Nova Imagem@>+=
  if(local_color_table_flag)
    color_table = local_color_table;
  else
    color_table = global_color_table;
@

Com o código que foi escrito até agora já estamos extraindo códigos
LZW. Agora vamos ao código que transforma cada código em ua sequência
de cores:

@<GIF: Interpreta Códigos Lidos@>=
{
  // Se chegamos ao fim, vaos apenas voltar ao teste da nossa iteração
  // e de lá nós sairemos do loop
  if(code == end_of_information_code){
    end_of_image = true;
    continue;
  }
  // Se recebemos um <CLEAR CODE>, devemos limpara a tabela de códigos:
  if(code == clear_code){
    @<GIF: Limpa a Tabela de Códigos@>
    continue;
  }
  // Se estamos lendo o primeiro pixel, não precisamos inserir nada na
  // tabela de códigos
  else if(first_pixel){
    first_pixel = false;
    previous_code = code;
    // A função que preenche um pixel na imagem passada como primeiro
    // argumento dada a nossa tabela de códigos, o código lido, a
    // tabela de cores, o número de cores associada ao código lido, a
    // informação de usarmos ou não transparência e qual o valor que
    // representa transparência:
    preenche_pixel(&(last_img -> rgba_image[4 * pixel]),
                   code_table, code, color_table, 1,
                   transparent_color_flag, transparency_index);
    // O primeiro código representa apenas 1 pixel, pois é apenas 1
    // índie na tabela de cores. Ainda não povoamos a tabela de
    // códigos para que haja mais de um pixel por código:
    pixel ++;
  }
  // Se lemos um código que não está na tabela, devemos deduzi-lo:
  else if(code > last_value_in_code_table){
    if(previous_code < end_of_information_code){
      if(last_value_in_code_table < 4095){
        code_table[last_value_in_code_table + 1] =
          produz_codigo((unsigned char *) &previous_code, 1, previous_code);
        code_table_size[last_value_in_code_table + 1] = 2;
        last_value_in_code_table ++;
      }
    }
    else{
      if(last_value_in_code_table < 4095){
        code_table[last_value_in_code_table + 1] =
          produz_codigo(code_table[previous_code],
                        code_table_size[previous_code],
                        code_table[previous_code][0]);
        code_table_size[last_value_in_code_table + 1] =
          code_table_size[previous_code] + 1;
        last_value_in_code_table ++;
      }
    }
    preenche_pixel(&(last_img -> rgba_image[4 * pixel]),
                   code_table, code, color_table, code_table_size[code],
                   transparent_color_flag, transparency_index);
    pixel += code_table_size[code];
    previous_code = code;
  }
  // O caso mais comum: lemos um código novo que já conhecemos e
  // podemos consultar na tabela de codigos:
  else{
    // O código está na nossa tabela de códigos
    if(code < end_of_information_code){ // É um dos códigos primitivos
      if(previous_code < end_of_information_code){
        if(last_value_in_code_table < 4095){
          code_table[last_value_in_code_table + 1] =
            produz_codigo((unsigned char *) &previous_code, 1, code);
          code_table_size[last_value_in_code_table + 1] = 2;
          last_value_in_code_table ++;
        }
      }
      else{
        if(last_value_in_code_table < 4095){
          code_table[last_value_in_code_table + 1] =
            produz_codigo(code_table[previous_code],
                          code_table_size[previous_code], code);
          code_table_size[last_value_in_code_table + 1] =
            code_table_size[previous_code] + 1;
          last_value_in_code_table ++;
        }
      }
      preenche_pixel(&(last_img -> rgba_image[4 * pixel]),
                     code_table, code, color_table, 1,
                     transparent_color_flag, transparency_index);
      pixel ++;
      previous_code = code;
    }
    else{
      if(previous_code < end_of_information_code){
        if(last_value_in_code_table < 4095){
          code_table[last_value_in_code_table + 1] =
            produz_codigo((unsigned char *) &previous_code, 1,
                          code_table[code][0]);
          code_table_size[last_value_in_code_table + 1] = 2;
          last_value_in_code_table ++;
        }
      }
      else{
        if(last_value_in_code_table < 4095){
          code_table[last_value_in_code_table + 1] =
            produz_codigo(code_table[previous_code],
                          code_table_size[previous_code],
                          code_table[code][0]);
          code_table_size[last_value_in_code_table + 1] =
            code_table_size[previous_code] + 1;
          last_value_in_code_table ++;
        }
      }
      preenche_pixel(&(last_img -> rgba_image[4 * pixel]),
                     code_table, code, color_table, code_table_size[code],
                     transparent_color_flag, transparency_index);
      pixel += code_table_size[code];
      previous_code = code;
    }
  }
  if(last_value_in_code_table >= (unsigned) ((1 << bits) - 1) && bits < 12)
    bits ++;
}
@

Vamos definir agora o que signifia limpar a tabela de códigos, que é
algo que temos que fazer toda vez que lermos o código CLEAR CODE:

@<GIF: Limpa a Tabela de Códigos@>=
{
  for(; last_value_in_code_table > end_of_information_code;
      last_value_in_code_table --){
    Wfree(code_table[last_value_in_code_table]);
  }
  last_value_in_code_table = end_of_information_code;
  bits = lzw_minimum_code_size + 1;
  first_pixel = true;
}
@

No código acima usamos funções que ainda não estão definidas. A
primeira delas é para preencher um pixel na nossa imagem dada a tabela
de códigos, um código e a tabela de cores. O código é usado para
consultarmos a tabela de códigos e assim obtemos uma lista de
cores. Com a lista de cores, consultamos a tabela de cores e
conseguimos obter o valor correto pára cada pixel:

@<GIF: Funções Estáticas@>+=
void preenche_pixel(unsigned char *img, unsigned char **code_table,
                    unsigned code,
                    unsigned char *color_table, int size,
                    bool transparent_color_flag, unsigned transparency_index){
  int i = 0;
  for(i = 0; i < size; i ++){
    // Se estamos diante de um código inicial que representa
    // diretamente 1 só cor da tabela de cores:
    if(code_table[code] == NULL){
      img[4 * i] = color_table[3 * code];
      img[4 * i + 1] = color_table[3 * code + 1];
      img[4 * i + 2] = color_table[3 * code + 2];
      if(transparent_color_flag && transparency_index == code){
        img[4 * i + 3] = 0;
      }
      else{
        img[4 * i + 3] = 255;
      }
    }
    // Se estamos diante de um código criado depois que representa
    // mais de uma cor:
    else{
      img[4 * i] = color_table[3 * code_table[code][i]];
      img[4 * i + 1] = color_table[3 * code_table[code][i] + 1];
      img[4 * i + 2] = color_table[3 * code_table[code][i] + 2];
      if(transparent_color_flag && transparency_index == code_table[code][i]){
        img[4 * i + 3] = 0;
      }
      else{
        img[4 * i + 3] = 255;
      }
    }
  }
}
@

Já a função para produzir um novo código nada mais é do que uma função
que aloca espaço para ele e o gera contatenando um caractere no fim de
uma string. Nessa string, cada caractere é um índice na tabela de
cores, e portanto vale de 0 a 255. O valor de 0 não representa o fim
da string, mas a primeira cor da tabela de cores:

@<GIF: Funções Estáticas@>+=
unsigned char *produz_codigo(unsigned char *codigo, int size, char adicao){
  int i;
  unsigned char *ret = (unsigned char *) Walloc(size + 1);
  if(ret == NULL){
    fprintf(stderr, "WARNING (0): No memory to parse image. Please, increase "
            "the value of W_MAX_MEMORY at conf/conf.h.\n");
    return NULL;
  }
  for(i = 0; i < size; i ++)
    ret[i] = codigo[i];
  ret[size] = adicao;
  return ret;
}
@

Depois que terminamos de extrair nossa imagem, temos que esvaziar a
nossa tabela de códigos. Nós desalocamos todos os códigos definidos e
que não são os códigos iniciais cujo valor é |NULL| mesmo:

@<GIF: Finalizando Nova Imagem@>=
{
  unsigned i;
  for(i = last_value_in_code_table; i != end_of_information_code; i --)
    Wfree(code_table[i]);
}
@

E depois que percorremos todas as imagens presentes em nosso GIF,
temos que montar a(s) imagem(s) que iremos retornar. Pode haver mais
de uma no caso de animações. Cada uma delas terá o tamanho da ``área
de pintura lógica'' lida no cabeçalho do arquivo GIF. Caso um frame
lido seja menor ou tenha cores transparentes, devemos levar em conta o
valor da variável |disposal_method| para ver como preencher aquele
pixel.

Ao fim, devemos produzir um array com 1 ou mais valores |GLuint| que
representam texturas enviadas para a placa de vídeo, cada uma delas
correspondente a um frame da animação.

Mas aí temos uma complicação adicional: se estivermos rodando nosso
programa em threads fora da web, então estaremos gerando texturas em
uma thread. Precisamos de um contexto OpenGL nessa thread para isso, e
esse contexto deve poder compartilhar recursos com a thread
principal. Para gerar um novo contexto, fazemos:

@<GIF: Gerando Imagem Final@>=
#ifdef W_MULTITHREAD
{
  GLXFBConfig *fbConfigs;
  int context_attribs[] =
    { //  Iremos usar e exigir OpenGL 3.3
      GLX_CONTEXT_MAJOR_VERSION_ARB, 3,
      GLX_CONTEXT_MINOR_VERSION_ARB, 3,
      None
    };
  glXCreateContextAttribsARBProc glXCreateContextAttribsARB = 0;
  int return_value;
  int doubleBufferAttributes[] = {
    GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT, // Desenharemos na tela, não em 'pixmap'
    GLX_RENDER_TYPE,   GLX_RGBA_BIT, // Definimos as cores via RGBA, não paleta
    GLX_DOUBLEBUFFER,  True, // Usamos buffers duplos para evitar 'flickering'
    GLX_RED_SIZE,      1, // Devemos ter ao menso 1 bit de vermelho
    GLX_GREEN_SIZE,    1, // Ao menos 1 bit de verde
    GLX_BLUE_SIZE,     1, // Ao menos 1 bit de azul
    GLX_ALPHA_SIZE,    1, // Ao menos 1 bit para o canal alfa
    GLX_DEPTH_SIZE,    1, // E ao menos 1 bit de profundidade
    None
  };
  fbConfigs = glXChooseFBConfig(_dpy, _screen, doubleBufferAttributes,
                                &return_value);
  glXCreateContextAttribsARB = (glXCreateContextAttribsARBProc)
    glXGetProcAddressARB( (const GLubyte *) "glXCreateContextAttribsARB" );
  // TODO: _screen e _context precisa ser global, não mais estático
  thread_context = glXCreateContextAttribsARB(_dpy, *fbConfigs, _context,
                                              GL_TRUE, context_attribs);
  glXMakeCurrent(_dpy, _window, thread_context);
}
#endif
@

E sabendo que podemos gerar texturas OpenGL, enfim geramos nossas
imagens finais:
  
@<GIF: Gerando Imagem Final@>+=
{
  unsigned i, line_source, line_destiny, col;
  unsigned long source_index, target_index;
  struct _image_list *p;
  int line_increment;
  int current_disposal_method = 0;
  unsigned char *current_image = NULL, *previous_image = NULL;
  // Se a imagem não está entrelaçada, suas linhas são armazenadas
  // sequencialmente (0, 1, 2, 3, ...). Se ela está entrelaçada, suas
  // linhas são armazenadas na sequência (0, 8, 16, 24, ..., 4, 12,
  // 20, 28, ..., 2, 6, 10, 14, ..., 1, 3, 5, 7, ...).
  if(interlace_flag){
    line_increment = 8;
  }
  else
    line_increment = 1;
  // Alocamos onde iremos armazenar os pixels da imagem antes de
  // enviar para a placa de vídeo:
  current_image = (unsigned char *) _iWalloc(4 * width * height);
  if(current_image == NULL){
      fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
              "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              filename);
      returned_data = NULL;
      goto error_gif;
  }
  // Se há mais de um frame, temos que armazenar a duração de cada um
  // e temos que armazenar os pixels do frame anterior, já que podemos
  // precisar.
  if(*number_of_frames > 1){
    *frame_duration = (unsigned *) Walloc(*number_of_frames *
                                          sizeof(unsigned));
    if(*frame_duration == NULL){
      fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
              "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              filename);
      Wfree(current_image);
      returned_data = NULL;
      goto error_gif;
    }
    previous_image = (unsigned char *) _iWalloc(4 * width * height);
    if(previous_image == NULL){
      fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
              "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              filename);
      Wfree(current_image);
      Wfree(frame_duration);
      returned_data = NULL;
      goto error_gif;
    }
  }
  // A identificação das texturas que vão para a placa de vídeo:
  returned_data = (GLuint *) Walloc((*number_of_frames) * sizeof(GLuint));
  if(returned_data == NULL){
    fprintf(stderr, "WARNING (0): Not enough memory to read GIF file %s. "
            "Please, increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    Wfree(current_image);
    Wfree(frame_duration);
    Wfree(previous_image);
    goto error_gif;
  }
  // E já pedimos identificadores OpenGL para cada textura:
  glGenTextures(*number_of_frames, returned_data);
  p = img;
  for(i = 0; i < *number_of_frames; i ++){
    line_source = col = line_destiny = 0;
    if(*number_of_frames > 1){
      (*frame_duration)[i] = p -> delay_time;
    }
    while(line_destiny < height){
      while(col < width){
        target_index = 4 * width * (height - line_destiny - 1) +
          col * 4;
        source_index = (line_source - p -> y_offset) * (p -> width) * 4 +
          (col - p -> x_offset) * 4;
        if(col < p -> x_offset || line_destiny < p -> y_offset ||
           col >= p -> x_offset + p -> width ||
           line_destiny >= p -> y_offset + p -> height ||
           p -> rgba_image[source_index + 3] == 0){
          if(i == 0 || current_disposal_method == 3){
            // Deixa transparente
            current_image[target_index] = p -> rgba_image[source_index];
            current_image[target_index + 1] = p -> rgba_image[source_index + 1];
            current_image[target_index + 2] = p -> rgba_image[source_index + 2];
            current_image[target_index + 3] = p -> rgba_image[source_index + 3];
          }
          else if(current_disposal_method == 1){
            // Repete imagem anterior
            current_image[target_index] = previous_image[target_index];
            current_image[target_index + 1] = previous_image[target_index + 1];
            current_image[target_index + 2] = previous_image[target_index + 2];
            current_image[target_index + 3] = previous_image[target_index + 3];
          }
          else{
            // Preenche com cor de fundo
            current_image[target_index] =
              global_color_table[background_color * 3];
            current_image[target_index + 1] =
              global_color_table[background_color * 3 + 1];
            current_image[target_index + 2] =
              global_color_table[background_color * 3 + 2];
            current_image[target_index + 3] = 255;
          }
        }
        else{
          // Preenche pixels de imagem nova
          current_image[target_index] = p -> rgba_image[source_index];
          current_image[target_index + 1] = p -> rgba_image[source_index + 1];
          current_image[target_index + 2] = p -> rgba_image[source_index + 2];
          current_image[target_index + 3] = p -> rgba_image[source_index + 3];
        }
        col ++;
      }
      line_destiny = line_destiny + line_increment;
      line_source ++;
      if(line_destiny >= height && interlace_flag){
        if(line_source < height / 4){
          line_destiny = line_increment / 2;
        }
        else{
          line_increment /= 2;
          line_destiny = line_increment / 2;
        }
      }
      col = 0;
    }
    current_disposal_method = p -> disposal_method;
    p = p -> next;
    line_source = col = line_destiny = 0;
    // Enviando a textura para a placa de vídeo:
    glBindTexture(GL_TEXTURE_2D, returned_data[i]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, current_image);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    { // Trocando os valores da imagem atual e da anterior:
      unsigned char *tmp = previous_image;
      previous_image = current_image;
      current_image = tmp;
    }
  }
// Se usamos threads, não precisamos mais de contexto OpenGL:
#ifdef W_MULTITHREAD
  glXDestroyContext(_dpy, thread_context);
    glXMakeCurrent(_dpy, _window, _context);
#endif
  // Ajustando os valores do número de repetições caso seja uma
  // animação:
  if(number_of_loops == 0)
    *max_repetition = -1;
  else
    *max_repetition = number_of_loops;
  // Desalocando as imagens na ordem certa:
  if(*number_of_frames % 2){
    if(current_image != NULL) Wfree(current_image);
    Wfree(previous_image);
  }
  else{
    if(previous_image != NULL) Wfree(previous_image);
    Wfree(current_image);
  }
}
@

@*2 Integrando Imagens GIF às Interfaces.

Usar a nossa função que definimos para carregar GIFs de modo a criar
uma interface não é tão diferente do trabalho que tivemos para
integrar os sons WAVE na nossa engine.

Primeiro, de agora em diante será importante que toda interface tenha
uma textura e também uma variável booleana para indicar se a textura
já foi carregada. Também, caso a imagem seja uma animação, teremos que
informar o número de frames dela e qual o tempo de duração de cada
um. Ela também irá armazenar um novo atributo |_t|, que indica quando
ela passou a ter o número de frame atual em microssegundos e
|max_iterations|, que é o número de vezes que devemos repetir a
animação.

@<Interface: Atributos Adicionais@>=
// Isso fica dentro da definição de 'struct interface':
GLuint *_texture; 
bool _loaded_texture; // A(s) textura(s) acima foi(ram) carregada(s)?
bool animate; // A interface é animada?
unsigned number_of_frames; // Quantos frames a imagem tem?
unsigned current_frame;
unsigned *frame_duration; // Vetor com a duração de cada frame
unsigned long _t; // Em que tempo W.t mudamos o frame da última vez?
int max_repetition;
@

Estes valores precisam ser inicializados. Inicializá-los é fácil, só a
textura é que é um pouco diferente. Como estes são atributos que todas
as imagens vão ter, vamos precisar criar uma textura padrão e
transparente que será a usada nas interfaces que não possuem textura.

Nossa textura padrão e transparente será criada na inicialização e
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
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA,
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
  _interfaces[_number_of_loops][i]._texture = &_empty_texture;
  // Por padrão, ainda nem sabemos se a interface terá uma
  // textura. Assim que detectarmos que ela terá, mudamos
  // '_loaded_texture' para falso, e aí para verdadeiro de novo quando
  // ela terminar de carregar a textura:
  _interfaces[_number_of_loops][i]._loaded_texture = true;
  _interfaces[_number_of_loops][i].animate = false;
  _interfaces[_number_of_loops][i].number_of_frames = 1;
  _interfaces[_number_of_loops][i].current_frame = 0;
  _interfaces[_number_of_loops][i].frame_duration = NULL;
  _interfaces[_number_of_loops][i]._t = W.t;
  _interfaces[_number_of_loops][i].max_repetition = -1;
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
destas interfaces de imagens:

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
#if W_TARGET == W_ELF
  char *ext;
  bool ret = true;
#endif
  char *filename, complete_path[256]; 
  va_start(valist, height);
  filename = va_arg(valist, char *);
  va_end(valist);
  // Obtendo o caminho do arquivo:
  strncpy(complete_path, dir, 256);
  complete_path[255] = '\0';
  strncat(complete_path, filename, 256 - strlen(complete_path));
#if W_TARGET == W_WEB
  // Rodando assincronamente
  if(mkdir("image/", 0777) == -1) // Emscripten
    perror(NULL);
  W.pending_files ++;
  // Obtendo arquivo via Emsripten
  emscripten_async_wget2(complete_path, complete_path,
                         "GET", "",
                         (void *) &(_interfaces[_number_of_loops][i]),
                         &onload_texture, &onerror_texture,
                         &onprogress_texture);
#else
  // Rodando sincronamente:
  ext = strrchr(filename, '.');
  if(! ext){
    fprintf(stderr, "WARNING (0): No file extension in %s.\n",
            filename);
    _interfaces[_number_of_loops][i].type = W_NONE;
    return NULL;
  }
  if(!strcmp(ext, ".gif") || !strcmp(ext, ".GIF")){ // Suportando .gif
    _interfaces[_number_of_loops][i]._texture =
      _extract_gif(complete_path,
                   &(_interfaces[_number_of_loops][i].number_of_frames),
                   &(_interfaces[_number_of_loops][i].frame_duration),
                   &(_interfaces[_number_of_loops][i].max_repetition),
                   &ret);
    if(ret){ // Se algum erro aconteceu:
      _interfaces[_number_of_loops][i].type = W_NONE;
      return NULL;
    }
    // Ativa animação se for o caso
    if(_interfaces[_number_of_loops][i].number_of_frames > 1)
      _interfaces[_number_of_loops][i].animate = true;
    _interfaces[_number_of_loops][i]._loaded_texture = true;
    // Depois temos que finalizar o nosso recurso quando ele for limpo
    // pelo coletor de lixo. Neste caso finalizar significa apagar a
    // textura OpenGL:
    _finalize_after(&(_interfaces[_number_of_loops][i]),
                    _finalize_interface_texture);
  }
  @<Interface: Extraindo Arquivos de Imagens Adicionais@>
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
nada a ser invocada à medida que baixamos o arquivo) e
|_finalize_interface_texture| (função que irá pedir para que a textura
seja removida da memória da placa de vídeo quando a interface for
desalocada).

Ao trabalho. Primeiro o |onerror_texture| caso seja um programa web. Em
caso de erro, tudo o que fazemos é imprimir uma mensagem na tela
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

Tendo essa função de erros podemos definir o que fazer quando
carregamos a textura em ambiente web e algo dá errado.

@<Interface: Cabeçalhos@>+=
#if W_TARGET == W_WEB
#include <SDL/SDL_image.h>
#endif
@

@<Interface: Funções Estáticas@>=
#if W_TARGET == W_WEB
static void onload_texture(unsigned undocumented,
                           void *inter, const char *filename){
  char *ext;
  bool ret = true;
  struct interface *my_interface = (struct interface *) inter;
  printf("DEBUG FILENAME: %s.\n", filename);
  // Checando extensão
  ext = strrchr(filename, '.');  
  if(! ext){
    onerror_texture(0, inter, 0);
    return;
  }
  if(!strcmp(ext, ".gif") || !strcmp(ext, ".GIF")){ // Suportando .gif
    my_interface -> _texture =
      _extract_gif((char *) filename,
                   &(my_interface -> number_of_frames),
                   &(my_interface -> frame_duration),
                   &(my_interface -> max_repetition), &ret);
  }
  else{
    // A imagem não é um GIF. Extrairemos usando o SDL aqui:
    SDL_Surface *tmp_surface = IMG_Load(filename);
    unsigned char *pixels = (unsigned char *)
      Walloc(sizeof(unsigned char) * 4 * tmp_surface -> w * tmp_surface -> h);
    my_interface -> _texture = (GLuint *) Walloc(sizeof(GLuint));
    if(my_interface -> _texture == NULL || pixels == NULL){
      fprintf(stderr, "ERROR: Not enough memory to read %s. Please, increase "
              "the value of W_MAX_MEMORY at conf/conf.h.\n", filename);
    }
    else{
      // Corrigindo a orientação da imagem para o nosso padrão
      int i, j, width = tmp_surface -> w, height = tmp_surface -> h;
      for(i = 0; i < width; i ++)
        for(j = 0; j < height; j ++){
          pixels[4 * (j * width + i)] = ((unsigned char *) tmp_surface -> pixels)
            [4*((height-1-j) * width + i)];
          pixels[4 * (j * width + i)+1] =
            ((unsigned char *) tmp_surface -> pixels)
            [4*((height-1-j) * tmp_surface -> w + i)+1];
          pixels[4 * (j * tmp_surface -> w + i)+2] =
            ((unsigned char *) tmp_surface -> pixels)
            [4*((height-1-j) * tmp_surface -> w + i)+2];
          pixels[4 * (j * tmp_surface -> w + i)+3] =
            ((unsigned char *) tmp_surface -> pixels)
            [4*((height-1-j) * tmp_surface -> w + i)+3];
        }
      glGenTextures(1, my_interface -> _texture);
      glBindTexture(GL_TEXTURE_2D, *(my_interface -> _texture));
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      // XXX: Checar se é mesmo RGBA:
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tmp_surface -> w,
                   tmp_surface -> h, 0, GL_RGBA,
                   GL_UNSIGNED_BYTE, pixels);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glBindTexture(GL_TEXTURE_2D, 0);
      my_interface -> number_of_frames = 1;
      my_interface -> frame_duration = NULL;
      my_interface -> max_repetition = 0;
      ret = false;
    }
    SDL_FreeSurface(tmp_surface);
  }
  if(ret){ // Se algum erro aconteceu:
    my_interface -> type = W_NONE;
    return;
  }
  // Ativa animação se for o caso:
  if(my_interface -> number_of_frames > 1)
    my_interface -> animate = true;
  _finalize_after(my_interface, _finalize_interface_texture);
  // A mudança final de flag:
  my_interface -> _loaded_texture = true;
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


E por fim a função para desalocar texturas na placa de vídeo:

@<Interface: Declarações@>+=
  void _finalize_interface_texture(void *);
@

@<Interface: Definições@>+=
// Uma função rápida para desalocar texturas OpenGL e que podemos
// usar abaixo:
void _finalize_interface_texture(void *data){
  struct interface *p = (struct interface *) data;
  glDeleteTextures(p -> number_of_frames, p -> _texture);
}
@

Funções como |_finalize_after| são úteis para garantirmos que os
recursos alocados pelas interfaces com textura sejam liberados da
memória ao sairmos do loop atual. Mas caso nós queiramos destruir uma
interface por meio de |W.destroy_interface|, precisamos fazer tal
limpeza manualmente:

@<Código ao Remover Interface@>+=
{
  _finalize_this(&_interfaces[_number_of_loops][i], true);
  if(_interfaces[_number_of_loops][i]._texture != &_empty_texture)
    Wfree(_interfaces[_number_of_loops][i]._texture);
  _finalize_interface_texture((void *) &_interfaces[_number_of_loops][i]);
}
@

@*1 Shader e Renderização.

Vamos agora criar o shader responsável por renderizar as imagens com
textura na tela. O que ele terá de diferente é que ele usará a sua
textura para definir os pixels que serão colocados no shader de
fragmento.

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
  coordinate = vec2(vertex_position[0] + 0.5, vertex_position[1] + 0.5);
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
extern char _fragment_image_interface[];
struct _shader _image_interface_shader;
@
@<Shaders: Definições@>+=
char _vertex_image_interface[] = {
#include "vertex_image_interface.data"
        , 0x00};
char _fragment_image_interface[] = {
#include "fragment_image_interface.data"
    , 0x00};
@

Compilamos ele na inicialização:

@<API Weaver: Inicialização@>+=
{
  GLuint vertex, fragment;
  vertex = _compile_vertex_shader(_vertex_image_interface);
  fragment = _compile_fragment_shader(_fragment_image_interface);
  // Preenchendo variáeis uniformes e atributos:
  _image_interface_shader.program_shader =
    _link_and_clean_shaders(vertex, fragment);
  _image_interface_shader._uniform_texture1 =
    glGetUniformLocation(_image_interface_shader.program_shader,
                         "texture1");
  _image_interface_shader._uniform_object_color =
    glGetUniformLocation(_image_interface_shader.program_shader,
                         "object_color");
  _image_interface_shader._uniform_model_view =
    glGetUniformLocation(_image_interface_shader.program_shader,
                         "model_view_matrix");
  _image_interface_shader._uniform_object_size =
    glGetUniformLocation(_image_interface_shader.program_shader,
                         "object_size");
  _image_interface_shader._uniform_time =
    glGetUniformLocation(_image_interface_shader.program_shader,
                         "time");
  _image_interface_shader._uniform_integer =
    glGetUniformLocation(_image_interface_shader.program_shader,
                           "integer");
  _image_interface_shader._attribute_vertex_position =
    glGetAttribLocation(_image_interface_shader.program_shader,
                        "vertex_position");
}
@

E na hora da renderização, apenas usamos o shader que definimos e
compilamos:

@<Interface: Renderizar com Shaders Alternativos@>=
else if(_interface_queue[_number_of_loops][i] -> type == W_INTERFACE_IMAGE){
  current_shader = &_image_interface_shader;
}
@

E temos que fazer o shader de interface receber alguns uniformes
adicionais:

@<Passando Uniformes Adicionais para Shader de Interface@>=
// Primeiro vemos se temos que mudar a textura devido à animação:
if(_interface_queue[_number_of_loops][i] -> animate &&
   _interface_queue[_number_of_loops][i] -> number_of_frames > 1 &&
   _interface_queue[_number_of_loops][i] -> max_repetition != 0){
  if(W.t + _lag - _interface_queue[_number_of_loops][i] -> _t >
     _interface_queue[_number_of_loops][i] ->
     frame_duration[_interface_queue[_number_of_loops][i] -> current_frame]){
    if(_interface_queue[_number_of_loops][i] -> current_frame + 1 ==
       _interface_queue[_number_of_loops][i] -> number_of_frames){
      // Termina um ciclo de repetição da animação
      if(_interface_queue[_number_of_loops][i] -> max_repetition > 0){
        _interface_queue[_number_of_loops][i] -> max_repetition --;
      }
      if(_interface_queue[_number_of_loops][i] -> max_repetition != 0){
        _interface_queue[_number_of_loops][i] -> current_frame = 0;
        _interface_queue[_number_of_loops][i] -> _t = W.t + _lag;
      }
    }
    else{
      // Passa para o próximo frame de animação
      _interface_queue[_number_of_loops][i] -> current_frame ++;
      _interface_queue[_number_of_loops][i] -> _t = W.t + _lag;
    }
  }
}
// Em seguida, usamos a textura adequada
glBindTexture(GL_TEXTURE_2D,
              _interface_queue[_number_of_loops][i] ->
              _texture[_interface_queue[_number_of_loops][i] -> current_frame]);
@

Agora nós podemos criar uma nova interface que é um GIF animado por
meio do |W.new_interface(W_INTERFACE_IMAGE, ...)|. Mas seria bom
podermos usar GIFs animados em interfaces cujo shader é definido pelo
usuário. Para isso, teremos que ler um argumento adicional quando
geramos uma nova interface personalizada. Esse argumento pode ser
|NULL| ou uma string vazia para indicar que não queremos usar uma
imagem como textura. Ou pode ser o nome do arquivo de imagem onde está
a nossa textura. Para isso lemos um argumento a mais ao lermos
interfaces personalizadas:

@<Interface: Lê Argumentos de Interfaces Personalizadas@>=
{
#if W_TARGET == W_WEB
  char dir[] = "image/";
#elif W_DEBUG_LEVEL >= 1
  char dir[] = "./image/";
#elif W_TARGET == W_ELF
  char dir[] = W_INSTALL_DATA"/image/";
#endif
#if W_TARGET == W_ELF
  char *ext;
  bool ret = true;
#endif
  char *filename, complete_path[256];
  va_start(valist, height);
  filename = va_arg(valist, char *);
  if(filename != NULL && filename[0] != '\0'){
    _interfaces[_number_of_loops][i]._loaded_texture = false;
    // Gerando nome do arquivo
    strncpy(complete_path, dir, 256);
    complete_path[255] = '\0';
    strncat(complete_path, filename, 256 - strlen(complete_path));
  // Rodando assincronamente
#if W_TARGET == W_WEB
    mkdir("images/", 0777); // Emscripten
    W.pending_files ++;
    // Obtendo arquivo via Emsripten
    emscripten_async_wget2(complete_path, complete_path,
                           "GET", "",
                           (void *) &(_interfaces[_number_of_loops][i]),
                           &onload_texture, &onerror_texture,
                           &onprogress_texture);
#else
    // Rodando sincronamente:
    ext = strrchr(filename, '.');
    if(! ext){
      fprintf(stderr, "WARNING (0): No file extension in %s.\n",
              filename);
      _interfaces[_number_of_loops][i].type = W_NONE;
      return NULL;
    }
    if(!strcmp(ext, ".gif") || !strcmp(ext, ".GIF")){ // Suportando .gif
      _interfaces[_number_of_loops][i]._texture =
        _extract_gif(complete_path,
                     &(_interfaces[_number_of_loops][i].number_of_frames),
                     &(_interfaces[_number_of_loops][i].frame_duration),
                     &(_interfaces[_number_of_loops][i].max_repetition),
                     &ret);
      if(ret){ // Se algum erro aconteceu:
        _interfaces[_number_of_loops][i].type = W_NONE;
        return NULL;
      }
      // Ativa animação se for o caso
      if(_interfaces[_number_of_loops][i].number_of_frames > 1)
        _interfaces[_number_of_loops][i].animate = true;
      _interfaces[_number_of_loops][i]._loaded_texture = true;
      // Depois temos que finalizar o nosso recurso quando ele for limpo
      // pelo coletor de lixo. Neste caso finalizar significa apagar a
      // textura OpenGL:
      _finalize_after(&(_interfaces[_number_of_loops][i]),
                      _finalize_interface_texture);
    }
    @<Interface: Extraindo Arquivos de Imagens Adicionais@>
#endif
  }
  va_end(valist);
}
@

@*1 Sumário das Modificações do Capítulo.

Este capítulo não adicionou nenhuma nova função, mas modificou
estruturas de dados e funções já existentes. A seguinte estrutura de
dados foi atualizada:

\noindent|struct interface {
  // (...)
  bool animate;
  unsigned number_of_frames;
  unsigned current_frame;
  unsigned frame_duration[];
  int max_repetition;    
}|

\macrovalor|animate|: Nos diz se esta interface é animada ou não. Ou
  seja, se ela foi criada à partir de uma imagem GIF. Esta variável
  pode ter seu valor modificado para assim pausar e continuar uma
  animação.

\macrovalor|number_of_frames|: Variável somente leitura. Nos diz o
  número de frames da imagem da nossa interface. Só terá um valor
  diferente de 1 caso estejamos diante de uma interface animada.

\macrovalor|current_frame|: Variável cujo valor pode variar entre 0 e
  o valor do número de frames menos 1. Diz qual o frame da imagem está
  sendo mostrado na animação neste momento. O valor pode ser
  modificado.

\macrovalor|frame_duration[]|: Um vetor que só pode ser consultado em
  interfaces animadas. Nelas, haverá uma posição para cada frame da
  imagem e nelas você encontra quantos microssegundos deve durar cada
  frame de animação. Este valor pode ser modificado em interfaces
  animadas.

\macrovalor|max_repetition|: Quantas vezes devemos repetir a
  animação. Um valor de -1 representa que a animação irá se repetir
  infinitamente. Um valor de 0 mantém a animação parada em seu último
  frame. Em valores maiores que 0, a animação fica rodando, mas cada
  vez que passamos pelo último frame, o valor é decrementado. Você
  pode modificar este valor.

Além disso, a seguinte função teve o seu comportamento modificado:

\macrovalor|struct interface *W.new_interface(int type, int x, int y, ...)|:
Agora você pode passar a macro |W_INTERFACE_IMAGE| para mostrar a
interface como uma imagem (ou animação de um GIF animado) de algum dos
formatos de arquivo suportados. No momento só o formato GIF é
suportado, mas isso pode mudar nos próximos capítulos. Um exemplo de
uso:

\alinhacodigo
interface = W.new_interface(W_INTERFACE_IMAGE, W.width/2, W.height/2,
                            10, 10, "minha_imagem.gif");
\alinhanormal

Essecódigo gera uma nova interface no loop principal atual e retorna
seu ponteiro. Essa interface deve estar centralizada na tela e medir 10
pixels por 10 pixels. A aparência dela deve ser lida do arquivo
indicado pelo último argumento. O arquivo pode conter um GIF animado.

Além disso, o uso desta função em shaders personalizados mudou e agora
precisamos usar um argumento adicional:

\alinhacodigo
interface = W.new_interface(1, W.width/2, W.height/2, 10, 10, NULL);
\alinhanormal

O último argumento pode ser NULL, uma string vazia ou o nome de um
arquivo que contém uma imagem. Se for o nome de um arquivo com imagem,
a imagem é passada como textura para o shader, que pode lê-la por meio
da variável |texture1|.
