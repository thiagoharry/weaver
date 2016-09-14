@* Shaders e Interface.

Quase todo jogo ou aplicação gráfica possui uma interface visual. Esta
interface são imagens que possuem um determinado tamanho e posição na
tela. Elas podem reagir de forma diferente quando um usuário coloca ou
remove o cursor do mouse sobre ela e quando é clicada com algum dos
botões do mouse. E ela pode ser ou não animada. Apesar da aparente
complexidade, é um dos elementos mais simples com os quais temos que
lidar. Uma interface não interaje com o mundo de nosso jogo, portanto
ignora a engine de física. O movimento da câmera não muda sua
posição. E elas também não interagem diretamente entre si. Geralmente
não precisamos verificar se uma interface colidiu com outra ou não.

Mas para que possamos mostrar interaces visualmente precisaremos enfim
preencher o código de nosso \italico{shader}. Mas além disso seria
interessante se os \italico{shaders} pudessem ser modificados tais
como \italico{plugins}: tanto em tempo de execução como de
compilação. E para isso precisaremos definir um formato no qual iremos
permitir nossos \italico{shaders}.

Além de \italico{shaders} sob medida criado por usuários, iremos
também, fornecer \italico{shaders} padronizados para a renderização
padrão dos objetos.

@*1 Interfaces.

Primeiro criaremos os arquivos básicos para lidarmos com interfaces:

@(project/src/weaver/interface.h@>=
#ifndef _interface_h_
#define _interface_h_
#ifdef __cplusplus
  extern "C" {
#endif
#include "weaver.h"
@<Inclui Cabeçalho de Configuração@>
@<Interface: Declarações@>
#ifdef __cplusplus
  }
#endif
#endif
@
@(project/src/weaver/interface.c@>=
#include "interface.h"
//@<Interface: Definições@>
@
@<Cabeçalhos Weaver@>=
#include "interface.h"
@

Cada interface deverá ter no mínimo uma posição e um tamanho. Para
isso, vamos usar a mesma convenção que já usamos para o cursor do
mouse. Seu tamanho e posição será dado por números inteiros que
representam valores em pixels. A posição de uma interface é a
localização de seu canto superior esquerdo (todas as interfaces são
retangulares). O canto superior direito da ela é a posição $(0,0)$.

Assim, nossa lista de interfaces é declarada da seguinte forma:

@<Interface: Declarações@>=
struct interface {
    int _type; // Como renderizar
    int x, y; // Posição
    float r, g, b, a; // Cor
    int height, length; // Tamanho
    void *_data; // Se é uma imagem, ela estará aqui
    /* Variáveis necessárias para o OpenGL: */
    GLuint _vao;
    GLfloat _vertices[12];
    float _ofset_x, _offset_y;
    /* Funções a serem executadas em eventos: */
    void (*onmouseover)(struct interface *);
    void (*onmouseout)(struct interface *);
    void (*onleftclick)(struct interface *);
    void (*onrightclick)}(struct interface *);
    /* Mutex: */
#ifdef W_MULTITHREAD
    pthread_mutex_t _mutex;
#endif
 _interfaces[W_LIMIT_SUBLOOP][W_MAX_INTERFACES];
#ifdef W_MULTITHREAD
  // Para impedir duas threads de iserirem ou removerem interfaces
  // desta matriz:
  pthread_mutex_t _interface_mutex;
#endif
@

Notar que cada subloop do jogo tem as suas interfaces. E o número
máximo para cada subloop deve ser dado por |W_MAX_INTERFACES|.

O atributo |_type| conterá a regra de renderização sobre como o shader
deve tratar o elemento. Por hora definiremos dois tipos:

@<Interface: Declarações@>+=
#define W_NONE                 0
#define W_INTERFACE_SQUARE    -1
#define W_INTERFACE_PERIMETER -2
@

O primeiro valor indica que a interface ainda não foi definida. O
segundo deverá avisar o \italico{shader} para desenhar a interface
como um quadrado todo colorido com a cor indicada. O segundo é para
desenhar apenas o perímetro da superfície, também com as cores
indicadas. Caso uma interface não tenha sido definida, seu valor
deverá ser meramente |W_NONE|.

Na inicialização do programa preenchemos a nossa matriz de interfaces:

@<API Weaver: Inicialização@>+=
{
    int i, j;
    for(i = 0; i < W_LIMIT_SUBLOOP; i ++)
        for(j = 0; j < W_MAX_INTERFACES; j ++)
            _interfaces[i][j]._type = W_NONE;
#ifdef W_MULTITHREAD
    if(pthread_mutex_init(&_interface_mutex, NULL) != 0){
        perror("Initializing interface mutex:");
        return false;
    }
#endif
}
@

Durante a finalização, a única preocupação que realmente precisamos
ter é destruir o mutex:

@<API Weaver: Finalização@>+=
#ifdef W_MULTITHREAD
if(pthread_mutex_destroy(&_interface_mutex) != 0)
    perror("Finalizing interface mutex:", NULL);
#endif
@

Também precisamos limpar as interfaces de um loop caso estejamos
descartando ele para começar um novo loop. Vamos definir como fazer
isso em uma função auxiliar que invocaremos quando necessário:

@<Interface: Declarações@>+=
void _flush_interfaces(void);
@
@<Interface: Definições@>=
void _flush_interfaces(void){
    int i;
    for(i = 0; i < W_MAX_INTERFACES; i ++){
        switch(_interfaces[_number_of_loops][i]._type){
            // Dependendo do tipo da interface, podemos fazer desalocações
            // específicas aqui. Embora geralmente possamos simplesmente
            //confiar no coletor de lixo implementado
            //<@Desaloca Interfaces de Vários Tipos@>
        default:
        }
#ifdef W_MULTITHREAD
        if(pthread_mutex_destroy(&(_interfaces[_number_of_loops][i].mutex)) !=
           0)
            perror("Finalizing interface mutex:", NULL);
#endif
        _interfaces[_number_of_loops][i]._type = W_NONE;
    }
}
@

Ao usarmos |Wloop|, estamos descartando o loop principal atual e
trocando por outro. Desta forma, queremos descartar também suas
interfaces:

@<Código antes de Loop, mas não de Subloop@>+=
_flush_interfaces();
@

E também precisamos fazer a mesma limpeza no caso de estarmos saindo
de um subloop:

@<Código após sairmos de Subloop@>+=
_flush_interfaces();
@

Desta forma garantimos que ao iniciar um novo loop principal, a lista
de interfaces que temos estará vazia.

@*2 Criação e Destruição de Interfaces.

Criar uma interface é só um processo mais complicado porque podem
haver muitos tipos de interfaces. A verdadeira diferença é como elas
são renderizadas. Algumas poderão ser imagens animadas, imagens
estáticas, outras serão coisas completamente customizadas, com seus
shaders criados pelo usuário e outras, as mais simples, poderão ser
apenas quadrados preenchidos ou não. São estas últimas que definiremos
mais explicitamente neste capítulo.

Para gerar uma nova interface, usaremos a função abaixo. O seu número
de parâmetros será algo dependente do tipo da interrface. Mas no
mínimo precisaremos informar a posição e o tamanho dela. Um espaço
vazio é então procurado na nossa matriz de interfaces e o processo
particular de criação dela dependendo de seu tipo tem início:

@<Interface: Declarações@>+=
struct interface *_new_interface(int type, int x, int y, int width,
                                 int height, ...);
@
@<Interface: Definições@>=
  struct interface *_new_interface(struct interface *inter, int x, int y,
                                   int width, int height, ...){
    int i;
#ifdef W_MULTITHREAD
    pthread_mutex_lock(&_interface_mutex);
#endif
    // Vamos encontrar no pool de interfaces um espaço vazio:
    for(i = 0; i < W_MAX_INTERFACES; i ++)
        if(_interfaces[_number_of_loops][i]._type == W_NONE)
            break;
    if(i == W_MAX_INTERFACES; i ++){
        fprintf(stderr, "ERROR (0): Not enough space for interfaces. Please, "
                "increase the value of W_MAX_INTERFACES at conf/conf.h.\n");
#ifdef W_MULTITHREAD
        pthread_mutex_unlock(&_interface_mutex);
#endif
        Wexit();
    }
    // TODO
#ifdef W_MULTITHREAD
    pthread_mutex_unlock(&_interface_mutex);
#endif
}
@

@*2 Movendo Interfaces.

Para mudarmos a cor de uma interface, nós podemos sempre mudar
manualmente seus valores dentro da estrutura. Para mudar seu
comportamento em relação ao mouse, podemos também atribuir manualmente
as funções na estrutura. Mas para mudar a posição, não basta meramente
mudar os seus valores $(x, y)$, pois precisamos também modificar
variáveis internas que serão usadas pelo OpenGL durante a
renderização. Então teremos que fornecer funções específicas para
mover as interfaces.

Para mudar a posição de uma interface usaremos a função:

@<Interface: Declarações@>+=
void _move_interface(struct interface *);
@
@<Interface: Definições@>=
void _move_interface(struct interface *inter, int x, int y){
    inter -> x = x;
    inter -> y = y;
    // TODO
}
@

@*1 Shaders.

Aqui apresentamos todo o código que é executado na GPU ao invés da
CPU. Como usaremos shaders, precisaremos usar e inicializar também a
biblioteca GLEW:

@<API Weaver: Inicialização@>+=
{
  GLenum dummy;
  glewExperimental = GL_TRUE;
  GLenum err = glewInit();
  if (err != GLEW_OK){
    fprintf(stderr, "ERROR: GLW not supported.\n");
    exit(1);
  }
  /*
    Dependendo da versão, glewInit gera um erro completamente inócuo
    acusando valor inválido passado para alguma função. A linha
    seguinte serve apenas para ignorarmos o erro, impedindo-o de se
    propagar.
   */
  dummy = glGetError();
  glewExperimental += dummy;
  glewExperimental -= dummy;
}
@

Para isso, primeiro precisamos declarar na inicialização que iremos
usá-los. As versões mais novas de OpenGL permitem 4 Shaders
diferentes. Um para processar os vértices, outro para processar cada
pixel e mais dois para adicionar vértices e informações aos modelos
dentro da GPU. Mas quando programamos para WebGL, só podemos contar
com o padrão OpenGL ES 1.0. Por isso, só podemos usar os dois
primeiros tipos de shaders. Iremos declará-los abaixo:

@<API Weaver: Definições@>=
  static GLuint _vertex_shader, _fragment_shader;
@

Primeiro precisamos avisar o servidor OpenGL que iremos usá-los. Isso
dará à eles um ID para poderem ser referenciados:

@<API Weaver: Inicialização@>+=
{
  _vertex_shader = glCreateShader(GL_VERTEX_SHADER);
  _fragment_shader = glCreateShader(GL_FRAGMENT_SHADER);
}
@

E quando o programa terminar, nós destruímos os shaders criados:

@<API Weaver: Finalização@>+=
{
  glDeleteShader(_vertex_shader);
  glDeleteShader(_fragment_shader);
}
@

Mas como acrescentar o código para os shaders? O seu código é escrito
em GLSL e é compilado durante a execução do programa que os invoca. O
seu código deve então estar na memória do programa como uma string.

O problema é que não queremos definir o código GLSL desta
forma. Idealmente, queremos que o código GLSL seja em parte definido
por programação literária, já que ele é suficientemente próximo do
código C. E se formos faze isso, será chato definirmos ele como
string, pois teremos que ficar inserindo quebras de linha, temos que
tomar cuidado para escapar abertura de aspas e coisas assim. Sem falar
que perderemos a identação.

A solução? Iremos definir o código GLSL de cada shader para um
arquivo. O Makefile será responsável por converter o arquivo de código
GLSL para um outro arquivo onde cada caractere é traduzido para a
representação em C de seu valor hexadecimal. E então, nós inserimos
tais valores abaixo:


@<API Weaver: Inicialização@>+=
{
  char vertex_source[] = {
#include "vertex.data"
    , 0x00};
  char fragment_source[] = {
#include "fragment.data"
    , 0x00};
  const char *ptr1 = (char *) &vertex_source, *ptr2 = (char *) &fragment_source;
  glShaderSource(_vertex_shader, 1, &ptr1, NULL);
  glShaderSource(_fragment_shader, 1, &ptr2, NULL);
}
@

Agora compilamos os Shaders, imprimindo uma mensagem de erro e
abortando o programa se algo der errado:

@<API Weaver: Inicialização@>+=
{
  char error[200];
  GLint result;
  glCompileShader(_vertex_shader);
  glGetShaderiv(_vertex_shader, GL_COMPILE_STATUS, &result);
  if(result != GL_TRUE){
    glGetShaderInfoLog(_vertex_shader, 200, NULL, error);
    fprintf(stderr, "ERROR: While compiling vertex shader: %s\n", error);
    exit(1);
  }
  glCompileShader(_fragment_shader);
  glGetShaderiv(_fragment_shader, GL_COMPILE_STATUS, &result);
  if(result != GL_TRUE){
    glGetShaderInfoLog(_fragment_shader, 200, NULL, error);
    fprintf(stderr, "ERROR: While compiling fragment shader: %s\n", error);
    exit(1);
  }
}
@

Uma vez que tenhamos compilado os shaders, precisamos criar um
programa que irá contê-los:

@<API Weaver: Definições@>=
  GLuint _program;
@
@<Cabeçalhos Weaver@>+=
  extern GLuint _program;
@
@<API Weaver: Inicialização@>+=
{
  _program = glCreateProgram();
}
@
@<API Weaver: Finalização@>+=
{
  glDeleteProgram(_program);
}
@

Depois de criado um programa, precisamos associá-lo aos shaders
compilados. E quando terminarmos, vamos desassociá-los:

@<API Weaver: Inicialização@>+=
{
  glAttachShader(_program, _vertex_shader);
  glAttachShader(_program, _fragment_shader);
}
@
@<API Weaver: Finalização@>+=
{
  glDetachShader(_program, _vertex_shader);
  glDetachShader(_program, _fragment_shader);
}
@

Tendo colocado todos os shaders juntos no programa, precisamos
ligá-los entre si, verificando se um erro não ocorreu nesta etapa:

@<API Weaver: Inicialização@>+=
{
  GLint result;
  glLinkProgram(_program);
  glGetProgramiv(_program, GL_LINK_STATUS, &result);
  if(result != GL_TRUE){
    char error[200];
    glGetProgramInfoLog(_program, 200, NULL, error);
    fprintf(stderr, "ERROR: While linking shaders: %s\n", error);
    exit(1);
  }
}
@

Por fim, se nenhum erro aconteceu, podemos usar o programa:

@<API Weaver: Inicialização@>+=
  glUseProgram(_program);
@

@*1 Shader de Vértice.

Este é o shader de vértice inicial com a computação feita pela GPU
para cada vértice. Inicialmente ele será apenas um shader que passará
adiante o que recebe de entrada:

A primeira coisa que recebemos de entrada é a posição do vértice:

@(project/src/weaver/vertex.glsl@>=
#version 100

  attribute vec3 vPosition;
  @<Shader de Vértice: Declarações@>@/
@

E no programa principal, passamos para a saída o que recebemos de
entrada:

@(project/src/weaver/vertex.glsl@>+=
void main(){
  gl_Position = vec4(vPosition, 1.0);
  //@<Shader de Vértice: Aplicar Matriz de Modelo@>@/
  @<Shader de Vértice: Ajuste de Resolução@>@/
  //@<Shader de Vértice: Câmera (Perspectiva)@>@/
  @<Shader de Vértice: Cálculo do Vetor Normal@>@/
}
@

Isso significa que no programa principal em C, nós precisamos obter e
armazenar a localização da variável |vPosition| dentro do programa de
shader para que possamos passar tal variável:

@<API Weaver: Definições@>=
  GLint _shader_vPosition;
@

E se nosso shader foi compilado sem problemas, não teremos
dificuldades em obter a sua localização:

@<API Weaver: Inicialização@>+=
  _shader_vPosition = glGetAttribLocation(_program, "vPosition");
  if(_shader_vPosition == -1){
    fprintf(stderr, "ERROR: Couldn't get shader attribute index.\n");
    exit(1);
  }
@

@*1 Shader de Fragmento.

Agora o shader de fragmento, a ser processado para cada pixel que
aparecer na tela.

@(project/src/weaver/fragment.glsl@>=
#version 100

@<Shader de Fragmento: Declarações@>@/

void main(){
  @<Shader de Fragmento: Variáveis Locais@>@/
  gl_FragColor = vec4(0.5, 0.5, 0.5, 1.0);
  @<Shader de Fragmento: Modelo Clássico de Iluminação@>@/
  gl_FragColor = min(gl_FragColor, vec4(1.0));
}
@

@*1 Corrigindo Diferença de Resolução Horizontal e Vertical.

Por padrão aparecerá na tela qualquer primitiva geométrica que esteja
na posição $x$ no intervalo $[-1.0, +1.0]$ e na posição $y$ no mesmo
intervalo. Entretanto, nossa resolução pode variar horizontalmente ou
verticalmente. Se a resolução horizontal for maior (como ocorre
tipicamente), as figuras geométricas serão esticadas na horizontal. Se
a resolução vertical for maior, as figuras serão esticadas
verticalmente.

Precisamos fazer então com que a menor resolução (seja ela horizontal
ou vertical) tenha o intervalo $[-1.0, +1.0]$, mas que a outra
resolução represente um intervalo proporcionalmente maior. Isso faz
com que telas horizontais maiores, ou mesmo o xinerama dê o benefício
de uma visão horizontal maior.

Do ponto de vista do shader, teremos um multiplicador horizontal e
vertical que aplicaremos sobre cada vértice antes de qualquer outra
transformação:

@<Shader de Vértice: Declarações@>=
uniform float Whorizontal_multiplier, Wvertical_multiplier;
@

Na inicialização do Weaver, devemos obter a localização destas
variáveis no shader. A localização será armazenada nas variáveis
abaixo:

@<Cabeçalhos Weaver@>+=
  extern GLfloat _horizontal_multiplier, _vertical_multiplier;
@
@<API Weaver: Definições@>+=
  GLfloat _horizontal_multiplier, _vertical_multiplier;
@

O código de obtenção da localização junto com a inicialização dos
multiplicadores:

@<API Weaver: Inicialização@>+=
{
  _horizontal_multiplier = glGetUniformLocation(_program,
                                                "Whorizontal_multiplier");
  if(W.width > W.height)
    glUniform1f(_horizontal_multiplier, ((float) W.height / (float) W.width));
  else
    glUniform1f(_horizontal_multiplier, 1.0);
  _vertical_multiplier = glGetUniformLocation(_program,
                                              "Wvertical_multiplier");
  if(W.height > W.width)
    glUniform1f(_vertical_multiplier, ((float) W.width / (float) W.height));
  else
    glUniform1f(_vertical_multiplier, 1.0);
}
@

O uso dos multiplicadores para corrigir a posição do vértice deve
sempre ocorrer depois da rotação do objeto. Mas antes da translação:

@<Shader de Vértice: Ajuste de Resolução@>=
gl_Position *= vec4(Whorizontal_multiplier, Wvertical_multiplier, 1.0, 1.0);
@

Lembrando que o código para realizar tal correção não termina por
aí. Uma janela pode ter o seu tamanho modificado, e assim teremos uma
resolução com valores diferentes. Por isso temos que atualizar as
variáveis do shader toda vez que a janela ou canvas tem o seu tamanho
mudado:

@<Ações após Redimencionar Janela@>=
{
  if(W.width > W.height)
    glUniform1f(_horizontal_multiplier, ((float) W.height / (float) W.width));
  else
    glUniform1f(_horizontal_multiplier, 1.0);
  if(W.height > W.width)
    glUniform1f(_vertical_multiplier, ((float) W.width / (float) W.height));
  else
    glUniform1f(_vertical_multiplier, 1.0);
}
@

@*1 O Modelo Clássico de Iluminação.

Uma das principais utilidades do Shader de Fragmento é calcular
efeitos de luz e sombra. Vamos começar com a luz. O ponto de partida
para os efeitos de iluminação é o uso do Modelo Clássico de
Iluminação. Ele costuma dividir a luz em três tipos diferentes: a luz
ambiente (que representa a luz espalhada por um ambiente devido à ser
refletida pelo conjunto de objetos que faz parte da cena), a luz
difusa (luz emitida à partir de um ponto distante e que incide mais
sobre superfícies voltadas diretamente para ele) e a luz especular
(luz refletida por superfícies brilhantes).

Cada uma destas luzes pode possuir diferentes cores e intensidades.

@*2 A Luz Ambiente.

Este é o tipo de luz mais simples que existe. Ela não muda de um
objeto que está sendo renderizado para outro, não depende da posição
dos objetos e nem da direção de cada uma de suas faces. Por causa
disso, seus valores podem ser passados como sendo uma variável
uniforme para o shader:

@<Shader de Fragmento: Declarações@>=
  uniform mediump vec3 Wambient_light;
@

A luz nada mais é do que um valor RGB. E iluminar usando esta luz
significa simplesmente multiplicar o seu valor com o valor da cor do
pixel que estamos para desenhar na tela:

@<Shader de Fragmento: Modelo Clássico de Iluminação@>=
  gl_FragColor *= vec4(Wambient_light, 1.0);
@

Dentro do shader é só isso. Agora só precisamos criar uma estrutura
para armazenar a cor da luz (e sua intensidade):

@<API Weaver: Definições@>=
struct _ambient_light Wambient_light;
@
@<Cabeçalhos Weaver@>=
extern struct _ambient_light{
  float r, g, b;
  GLuint _shader_variable;
} Wambient_light;
@

Durante a inicialização do programa precisamos inicializar os
valores. Vamos começar deixando eles como sendo uma luz branca de
intensidade máxima.

@<API Weaver: Inicialização@>+=
{
  Wambient_light.r = 0.5;
  Wambient_light.g = 0.5;
  Wambient_light.b = 0.5;
  Wambient_light._shader_variable = glGetUniformLocation(_program,
                                                         "Wambient_light");
  glUniform3f(Wambient_light._shader_variable, Wambient_light.r,
              Wambient_light.g, Wambient_light.b);
}
@

E toda vez que quisermos atualizar o valor da luz ambiente, podemos
usar a seguinte função:

@<Cabeçalhos Weaver@>=
void Wset_ambient_light_color(float r, float g, float b);
@

@<API Weaver: Definições@>=
void Wset_ambient_light_color(float r, float g, float b){
  Wambient_light.r = r;
  Wambient_light.g = g;
  Wambient_light.b = b;
  glUniform3f(Wambient_light._shader_variable, Wambient_light.r,
              Wambient_light.g, Wambient_light.b);
}
@

@*2 A Luz Direcional.

A Luz Direcional é formada por raios paralelos de luz que percorrem
sempre a mesma direção em uma cena. Ela representa luz emitida por
pontos luminosos distantes. Por isso, a sua intensidade não depende da
posição de um objeto, apenas da orientação de suas faces. Se uma face
está voltada para o lado oposto da luz, ela não recebe iluminação. Se
estiver voltado para a luz, recebe a maior quantidade possível de
raios. É uma boa forma de simular a luz do sol em uma boa parte das
cenas.

Para calcularmos melhor a orientação de um polígono em relação à fonte
de luz, nós precisamos saber o valor da normal de cada vértice do
polígono. Ou seja, precisamos saber o valor de um vetor unitário que
tenha a mesma direção e sentido do vértice. Quando geramos o valor de
cada pixel no shader de fragmento, obteremos assim uma interpolação
deste valor e saberemos aproximadamente qual é a normal para cada
pixel renderizado da imagem. Então, no shader de vértice nós devemos
receber como atributo também a normal de cada vértice junto com suas
coordenadas:

@<Shader de Vértice: Declarações@>+=
  attribute vec3 VertexNormal;
@

A localização deste atributo no Shader precisa ser obtida pelo
programa em C, e por isso definimos e inicializamos a variável:

@<API Weaver: Definições@>=
  GLint _shader_VertexNormal;
@

@<API Weaver: Inicialização@>+=
  _shader_VertexNormal = glGetAttribLocation(_program, "VertexNormal");
  if(_shader_vPosition == -1){
    fprintf(stderr, "ERROR: Couldn't get shader attribute index.\n");
    exit(1);
  }
@

Ao longo do shader de vértice nós provavelmente podemos querer
modificar o vetor normal do vértice recebido. Muito provavelmente para
levar em conta eventuais rotações e transformações do modelo. E no fim
vamos querer passar o valor adiante para o shader de fragmento, onde o
valor da iluminação de cada pixel será computado. Para passar adiante
o valor da normal, usaremos:

@<Shader de Vértice: Declarações@>+=
  varying vec3 Wnormal;
@

E para modificarmos o valor conforme necessário, usamos:

@<Shader de Vértice: Cálculo do Vetor Normal@>=
  Wnormal = VertexNormal;
@

No shader de fragmento nós precisaremos receber do de vértice um vetor
normal interpolado para cada pixel dentro do polígono que se está
desenhando:

@<Shader de Fragmento: Declarações@>+=
  varying mediump vec3 Wnormal;
@

Duas outras coisas que precisamos receber no shader de fragmento: a
direção da luz e a sua cor:

@<Shader de Fragmento: Declarações@>+=
uniform mediump vec3 Wlight_direction;
uniform mediump vec3 Wdirectional_light;
@

Assim como no caso da luz ambiente, criamos uma estrutura para que o
programa em C possa acessar os valores da luz direcional:

@<API Weaver: Definições@>=
struct _directional_light Wdirectional_light;
@
@<Cabeçalhos Weaver@>=
extern struct _directional_light{
  // A cor:
  float r, g, b;
  // A direção:
  float x, y, z;
  GLuint _shader_variable, _direction_variable;
} Wdirectional_light;
@

Na inicialização fazemos com que a luz torne-se branca e aponte para
uma direção padrão:

@<API Weaver: Inicialização@>+=
{
  Wdirectional_light.r = 1.0;
  Wdirectional_light.g = 1.0;
  Wdirectional_light.b = 1.0;
  Wdirectional_light.x = 0.5;
  Wdirectional_light.y = 0.5;
  Wdirectional_light.z = -1.0;
  Wdirectional_light._shader_variable = glGetUniformLocation(_program,
                                                         "Wdirectional_light");
  glUniform3f(Wdirectional_light._shader_variable, Wdirectional_light.r,
              Wdirectional_light.g, Wdirectional_light.b);
  Wdirectional_light._direction_variable = glGetUniformLocation(_program,
                                                            "Wlight_direction");
  glUniform3f(Wdirectional_light._direction_variable, Wdirectional_light.x,
              Wdirectional_light.y, Wdirectional_light.z);
}
@

Tal como na luz ambiente, precisamos de uma função para ajustar a sua
cor:

@<Cabeçalhos Weaver@>=
void Wset_directional_light_color(float r, float g, float b);
@

@<API Weaver: Definições@>=
void Wset_directional_light_color(float r, float g, float b){
  Wdirectional_light.r = r;
  Wdirectional_light.g = g;
  Wdirectional_light.b = b;
  glUniform3f(Wdirectional_light._shader_variable, Wdirectional_light.r,
              Wdirectional_light.g, Wdirectional_light.b);
}
@

E além disso, para este tipo de luz precisamos também de uma função
para modificarmos a sua direção:

@<Cabeçalhos Weaver@>=
void Wset_directional_light_direction(float x, float y, float z);
@

@<API Weaver: Definições@>=
void Wset_directional_light_direction(float x, float y, float z){
  Wdirectional_light.x = x;
  Wdirectional_light.y = y;
  Wdirectional_light.z = z;
  glUniform3f(Wdirectional_light._direction_variable, Wdirectional_light.x,
              Wdirectional_light.y, Wdirectional_light.z);
}
@

Agora que todos os valores para a luz direcional já foram passados, o
que precisamos é fazer o shader de fragmento usar tais valores no
cálculo da cor de cada pixel. Primeiro precisamos de uma variável
local para calcularmos a intensidade da luz, que irá variar de acordo
com a direção da luz e a normal do ponto em que estamos:

@<Shader de Fragmento: Variáveis Locais@>=
mediump float directional_light;
@
@<Shader de Fragmento: Modelo Clássico de Iluminação@>+=
  directional_light = max(0.0, dot(Wnormal, Wdirectional_light));
@

Em seguida, multiplicamos a intensidade obtida pela própria cor da luz
e somamos ao valor já obtido da cor do pixel modificado pela luz
ambiente:

@<Shader de Fragmento: Modelo Clássico de Iluminação@>+=
  gl_FragColor += vec4(directional_light * Wdirectional_light,
                       0.0);
@
