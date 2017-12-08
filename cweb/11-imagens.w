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

@<Interface: Declarações@>+=
#ifndef W_DISABLE_PNG
GLuint *_extract_png(char * filename, unsigned *number_of_frames,
                     unsigned  **frame_duration, int *max_repetition,
                     bool *error){
  int width, height, number_of_passes;
  unsigned char *pixel_array;
  png_byte color_type, bit_depth;
  png_structp png_ptr;
  png_infop info_ptr;
  png_bytep * row_pointers;
  GLuint *returned_data  = NULL;
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
  //@<PNG: Encerrando Arquivo@>
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
  char header[8]; // Armazena o cabeçalho do arquivo
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

Assim como um GIF, um PNG também pode ser armazenado com as linhas
entrelaçadas. Mas temos que ler no cabeçalho quantas vees temos que
passar pela imagem para obtermos todas as linhas:

@<PNG: Extrair Arquivo@>+=
{
  number_of_passes = png_set_interlace_handling(png_ptr);
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
      for(z = y - 1; z >= 0; x --)
        Wfree(row_pointers[z]);
      Wfree(pixel_array);
      fprintf(stderr, "ERROR: No enough memory to load %s. "
              "Please increase the value of W_MAX_MEMORY at conf/conf.h.\n",
              filename);
      goto error_png;
    }
  }
  // Lemos a imagem em row_pointers
  png_read_image(png_ptr, row_pointers);
  fclose(fp);
}
@
