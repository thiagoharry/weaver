@* Outros Formatos de Imagem.

Já implementamos o suporte à imagens no formato GIF no Weaver. Mas há
outros formatos que será importante para nós suportarmos. Felizmente,
não será necessário implementar cada um deles do zero, tal como
fizemos com o GIF. No caso do GIF, tivemos que fazer isso porque era a
forma de termos o suporte à GIFs animados tanto compilando com Web
Assembly como compilando programas Linux. Masno caso de outros
formatos sem animação, podemos nos beneficiar da bibliotecas e APIs já
existentes.

@*1 O Formato PNG.

Nos anos 90, havia o formato GIF que era usado para transferir
imagens. O mesmo formato que já implementamos. Mas o mesmo algoritmo
de compactação que implemenamos com tanta tranquilidade, na época não
podia ser implementado com a mesma tranquilidade. Ele estava coberto
por uma patente e havia no ar uma ameaça de que quem o usasse poderia
precisar pagar royalties para uma empresa.

Além disso, a limitação de que uma imagem GIF só podia mostrar até 256
cores estava começando a incomodar naquela época. Isso levou um grupo
de entusiastas a desenvolver um novo formato se coordenando pela
Internet e coletando sugestões. Isso levaou ao nascimento do PNG (cujo
nome vem de ``PNG is Not GIF''). O formato tornou-se cada vez mais
popular e veio a ser implementado nos principais navegadores de
Internet. Por fim, no mesmo ano em que as patentes do GIF expiraram, o
formato PNG foi reconhecido como um padrão ISO.

Se quisermos extrair um PNG para uma interface, precisaremos do
cabeçalho:

@<Interface: Cabeçalhos@>=
#ifndef W_DISABLE_PNG
#include <png.h>
#endif
@

Nossa função de extrair PNGs deve ter a mesma assinatura da nossa
função de extrair GIFs:

@<Interface: Declarações@>+=
#ifndef W_DISABLE_PNG
GLuint *_extract_png(char *, unsigned *, unsigned  **, int *, bool *);
#endif
@

A relembrar, o primeiro argumento é o nome do arquivo, o segundo é um
ponteiro de onde colocar o número de frames (um PNG não tem animaão,
então ele sempre vai armazenar apenas 1), um ponteiro de onde colocar
um array com a duração de cada frame (o PNG vai sempre ajustar como
|NULL|), um ponteiro de onde colocar o número máximo de repetições
(ajustaremos como -1) e um poneiro para informar se houve um erro ou
não:

@<Interface: Definições@>+=
#ifndef W_DISABLE_PNG
GLuint *_extract_png(char * filename, unsigned *number_of_frames,
                     unsigned  **frame_duration, int *max_repetition,
                     bool *error){
  int width, height;
  unsigned char *pixel_array = NULL;
  png_structp png_ptr;
  png_infop info_ptr;
  png_bytep *row_pointers = NULL;
  png_byte color_type, bit_depth;
  GLuint *returned_data  = NULL;  
  *number_of_frames = 1;
  *frame_duration = NULL;
  *max_repetition = 0;
  FILE *fp = fopen(filename, "r");
  *error = false;
  // Como trataremos erros:
  if(fp == NULL){
    fprintf(stderr, "ERROR: Can't open file %s.\n", filename);
    goto error_png;
  }
  @<PNG: Extrair Arquivo@>
  goto end_of_png;
  error_png:
  // Código executado apenas em caso de erro
  *error = true;
  returned_data = NULL;
end_of_png:
  // Código de encerramento
#if W_TARGET == W_ELF && !defined(W_MULTITHREAD)
  fclose(fp);
#else
  @<PNG: Encerrando Arquivo@>
#endif
  return returned_data;
}
#endif
@

Felizmente, como usaremos a biblioteca libpng, será muito mais fácil
criar esta função comparado à criá-la para os GIFs. A primeira coisa
que temos que fazer é ler o cabeçalho do arquivo para nos
certificarmos de que ele é um arquivo PNG:

@<PNG: Extrair Arquivo@>=
{
  unsigned char header[8]; // Armazena o cabeçalho do arquivo
  // O cabeçalho deve ser: 0x89 0x50 0x4E 0x47 0x0D 0x0a 0x1A 0x0A. O
  // primeiro byte é só para ser incomum e minimizar a chance de um
  // texto ser interpretado coo PNG. Depois vem as letras P, N e G. E
  // alguns caracteres só para reonhecer os valores de quebra de linha
  // e fim de arquivo em vários sistemas. Assim em muitos casos o
  // comando cat não imprime bobagens quando recebe um PNG.
  fread(header, 1, 8, fp);
  if(png_sig_cmp(header, 0, 8)){
    fprintf(stderr, "ERROR: %s don't have a PNG header.\n", filename);
    goto error_png;
  }
}
@

O libpng irá armazenar as informações de leitura e informação do
arquivo em |struct|s que devemos inicializar:

@<PNG: Extrair Arquivo@>+=
{
  // Não é necessário passar mais argumentos além do primeiro, pois
  // não estaremos usando tratamento de erro ou alocação de memória
  // não-convencional junto com o libpng. Até poderíamos usar o Walloc
  // e Wfree com o libpng, mas não há benefícios claros de fazer
  // isso. Essas funções funcionam melhor sendo usadas internamente
  // somente por Weaver.
  png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if(!png_ptr){
    fprintf(stderr, "ERROR: Can't create structure to read PNG.\n");
    goto error_png;
  }
  info_ptr = png_create_info_struct(png_ptr);
  if(!info_ptr){
    fprintf(stderr, "ERROR: Can't create structure to read PNG.\n");
    goto error_png;
  }
}
@

O libpng, caso encontre um erro, ele sempre tenta usar o |longjmp|
para retornar ao programa. Sendo assim, é importante criarmos um ponto
para o qual ele poderá retornar. Neste caso, este serṕa o ponto de
retorno quando houver um erro de inicialização. Depois que terminarmos
a inicialização, criaremos outro ponto no qual imprimiremos outra
mensagem para o caso de erro:

@<PNG: Extrair Arquivo@>+=
{
  if(setjmp(png_jmpbuf(png_ptr))){
    fprintf(stderr, "ERROR: %s initialization failed.\n", filename);
    goto error_png;
  }
}
@

A primeira coisa a fazer na inicialização é inicializar as informações
sobre quais funções usaremos para ler o arquivo PNG. Não temos nenhum
motivo para não usarmos as funções da biblioteca padrão, então usamos:

@<PNG: Extrair Arquivo@>+=
{
  png_init_io(png_ptr, fp);
}
@

Em seguida, avisamos que nós já lemos 8 bytes da assinatura do arquivo
PNG, e até já checamos se o arquivo é mesmo PNG. Então, depois de
inicializarmos as funções de leitura, apenas avisamos que elas podem
pular 8 bytes:

@<PNG: Extrair Arquivo@>+=
{
  png_set_sig_bytes(png_ptr, 8);
}
@

E agora nós estamos na região do cabeçalho do PNG, onde ebncontramos
informações que são muito úteis como a largura e altura da imagem,
como as cores são armazenadas e quantos bits são usados para
representá-las. Hora de elr essas informações:

@<PNG: Extrair Arquivo@>+=
{
  png_read_info(png_ptr, info_ptr);
  width = png_get_image_width(png_ptr, info_ptr);
  height = png_get_image_height(png_ptr, info_ptr);
  color_type = png_get_color_type(png_ptr, info_ptr);
  bit_depth = png_get_bit_depth(png_ptr, info_ptr);
}
@

Podemos precisar fazer transformações na imagem PNG para sermos
capazes de lidar com ela:

@<PNG: Extrair Arquivo@>+=
{
  // Se a imagem for baseada em uma paleta de cores indexadas,
  // convertemos para RGB:
  if (color_type == PNG_COLOR_TYPE_PALETTE)
    png_set_palette_to_rgb(png_ptr);
  // Se uma imagem em preto-e-branco usa menos de 8 bits para
  // representar cada pixel, mudamos para 8 bits:
  if (color_type == PNG_COLOR_TYPE_GRAY &&
      bit_depth < 8) png_set_expand_gray_1_2_4_to_8(png_ptr);
  // Se a informação do canal Alpha está em um bloco do arquivo,
  // passamos para cada um dos pixels:
  if (png_get_valid(png_ptr, info_ptr,
                    PNG_INFO_tRNS)) png_set_tRNS_to_alpha(png_ptr);
  // Se usamos mais de 8 bits por pixel, reduzimos para 8:
  if (bit_depth == 16)
    png_set_strip_16(png_ptr);
  // Se usamos menos de 8, passamos para 8:
  if (bit_depth < 8)
    png_set_packing(png_ptr);
  // Agora convertemos imagens preto-e-branco para RGB:
  if (color_type == PNG_COLOR_TYPE_GRAY ||
      color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
    png_set_gray_to_rgb(png_ptr);
}
@

Agora já terminamos de ler todo o cabeçalho e inicializar. Vamos pedir
para que o PNG atualize a informação que já lemos todas essas
informações e vamos usar outro |setjmp| que será usado caso um erro
aconteça durante a leitura dos pixels:

@<PNG: Extrair Arquivo@>+=
{
  png_read_update_info(png_ptr, info_ptr);
  if(setjmp(png_jmpbuf(png_ptr))){
    fprintf(stderr, "ERROR: Failed to interpret %s .\n", filename);
    goto error_png;
  }
}
@

Para ler o arquivo, vamos alocar memória agora que temos o cabeçalho e
sabemos o tamanho da imagem. A função |png_read_image| nos retorna a
imagem na forma de um array de ponteiros para linhas. Vamos precisar
passar isso para um arra de pixels, que é o formato que precisamos
para passar para o OpenGL.

@<PNG: Extrair Arquivo@>+=
{
  int y, z;
  returned_data = (GLuint *) Walloc(sizeof(GLuint));
  if(returned_data == NULL){
    fprintf(stderr, "ERROR: Not enough memory to read %s. Please, increase "
            "the value of W_MAX_MEMORY at conf/conf.h.\n", filename);
    goto error_png;
  }
  pixel_array = (unsigned char *) Walloc(width * height * 4);
  if(pixel_array == NULL){
    fprintf(stderr, "ERROR: No enough memory to load %s. "
            "Please increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_png;
  }
  row_pointers = (png_bytep*) Walloc(sizeof(png_bytep) * height);
  if(row_pointers == NULL){
    Wfree(pixel_array);
    fprintf(stderr, "ERROR: No enough memory to load %s. "
            "Please increase the value of W_MAX_MEMORY at conf/conf.h.\n",
            filename);
    goto error_png;
  }
  for(y = 0; y < height; y ++){
    row_pointers[y] = (png_byte*) Walloc(png_get_rowbytes(png_ptr, info_ptr));
    if(row_pointers[y] == NULL){
      for(z = y - 1; z >= 0; z --)
        Wfree(row_pointers[z]);
      Wfree(row_pointers);
      row_pointers = NULL;
      Wfree(pixel_array);
      pixel_array = NULL;
      fprintf(stderr, "ERROR: No enough memory to load %s. "
              "Please increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              filename);
      goto error_png;
    }
  }
  // Lemos a imagem em row_pointers
  png_read_image(png_ptr, row_pointers);
}
@

Se formos encerrar o arquivo por algum motivo, teremos que desalocar a
memória alocada:

@<PNG: Encerrando Arquivo@>=
{
  if(row_pointers != NULL){
    int z;
    for(z = height - 1; z >= 0; z --)
      Wfree(row_pointers[z]);
    Wfree(row_pointers);
  }
  if(pixel_array != NULL)
    Wfree(pixel_array);
}
@

A imagem PNG foi lida. Mas não está em um formato adequado para nós a
passarmos para a placa de vídeo como textura. Para isso vamos
processar a imagem abaixo:

@<PNG: Extrair Arquivo@>+=
{
  color_type = png_get_color_type(png_ptr, info_ptr);
  switch(color_type){
  case PNG_COLOR_TYPE_RGB:
    @<PNG: Extrai Imagem RGB@>
    break;
  case PNG_COLOR_TYPE_RGBA:
    @<PNG: Extrai RGBA@>
    break;
  }
}
@

Para extrairmos uma imagem RGBA usamos:

@<PNG: Extrai RGBA@>=
{
  int x, y;
  for (y = 0; y < height; y++){
    png_byte* row = row_pointers[y];
    for (x = 0; x < width; x++){
      png_byte* ptr = &(row[x*4]);
      pixel_array[4 * width * (height - y - 1) + x * 4] = ptr[0];
      pixel_array[4 * width * (height - y - 1) + x * 4 + 1] = ptr[1];
      pixel_array[4 * width * (height - y - 1) + x * 4 + 2] = ptr[2];
      pixel_array[4 * width * (height - y - 1) + x * 4 + 3] = ptr[3];
    }
  }
}
@

E uma imagem RGB:

@<PNG: Extrai Imagem RGB@>=
{
  int x, y;
  for (y = 0; y < height; y++){
    png_byte* row = row_pointers[y];
    for (x = 0; x < width; x++){
      png_byte* ptr = &(row[x*3]);
      pixel_array[4 * width * (height - y - 1) + x * 4] = ptr[0];
      pixel_array[4 * width * (height - y - 1) + x * 4 + 1] = ptr[1];
      pixel_array[4 * width * (height - y - 1) + x * 4 + 2] = ptr[2];
      pixel_array[4 * width * (height - y - 1) + x * 4 + 3] = 255;
    }
  }
}
@

Tendo extraído todos os pixels e deixado eles no formato certo,
podemos nos livrar da memória alocada para os dados no formato da
libpng:

@<PNG: Extrair Arquivo@>+=
{
  int z;
  for(z = height - 1; z >= 0; z --)
    Wfree(row_pointers[z]);
  Wfree(row_pointers);
  row_pointers = NULL;
}
@

E agora podemos gerar uma nova textura OpenGL com a imagem que
acabamos de extrair:

@<PNG: Extrair Arquivo@>+=
{
  glGenTextures(1, returned_data);
  glBindTexture(GL_TEXTURE_2D, *returned_data);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA,
               GL_UNSIGNED_BYTE, pixel_array);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindTexture(GL_TEXTURE_2D, 0);
}
@

E isso encerra nossa extração e definição da função de extrair
arquivos PNG. Mas agora precisamos integrá-la dentro das outras
funções que são usadas para extrair imagens para interfaces:

@<Interface: Extraindo Arquivos de Imagens Adicionais@>=
#ifndef W_DISABLE_PNG
  if(!strcmp(ext, ".png") || !strcmp(ext, ".PNG")){ // Suportando .png
    _interfaces[_number_of_loops][i]._texture =
      _extract_png(complete_path,
                   &(_interfaces[_number_of_loops][i].number_of_frames),
                   &(_interfaces[_number_of_loops][i].frame_duration),
                   &(_interfaces[_number_of_loops][i].max_repetition),
                   &ret);
    if(ret){ // Se algum erro aconteceu:
      _interfaces[_number_of_loops][i].type = W_NONE;
      return NULL;
    }
    // Sem animação:
    _interfaces[_number_of_loops][i].animate = false;
    _interfaces[_number_of_loops][i]._loaded_texture = true;
    // Limpa a textura antes de encerrar
    _finalize_after(&(_interfaces[_number_of_loops][i]),
                    _finalize_interface_texture);
  }
#endif
@

Quando usamos shaders personalizados também será útil podermos
interpretar PNGs:

@<Interface: Formatos Adicionais com Shaders Personalizados@>=
  if(!strcmp(ext, ".png") || !strcmp(ext, ".PNG")){ // Suportando .gif

  }
@
