@* Objetos Básicos.

Vamos começar agora a definir os objetos reais dos mundos que podemos
construir com Weaver. Poderão haver vários tipos de objetos. A ideia é
que uma nuvem de partículas seja um objeto, uma mesa seja outro
objeto, a água de um cenário um terceiro e o golfinho que nada nela
seja mais um.

Mas vários objetos diferentes podem ter características diferentes. Um
objeto pode ser apenas uma seta ou um ícone que aparece, sem que ele
seja algo sólido capaz de colidir com os outros. Da mesma forma, a
nuvem de partículas também não colide, mas a sua forma muda. A água
tanto colide como muda de forma. A mesa colide, mas não muda de
forma. E o golfinho clide, se move, mas muda de forma de maneira mais
bem-definida (segundo um esqueleto).

Por causa disso, definiremos os objetos Weaver como uma união de
vários tipos diferentes. Todos eles terão uma variável inteira de tipo
para indicar que tipo de objeto eles são, outra para indicar quantos
vértices eles tem e uma terceira para indicar a posição inicial de
cada vértice, onde o centro do objeto é a coordenada $(0, 0, 0)$. Ou,
$(0,0)$ se estivermos em um universo bidimensional.

Além disso, é necessário diferenciar entre uma definição de objeto e
representantes do objeto em si. Em Orientação à Objetos, seria o
conceito de classe e instância. Todas as cadeiras poderão ser
definidas como tendo os mesmos vértices exatamente nas mesmas
coordenadas. Seria desperdício de memória fazer com que todas as
cadeiras memorizem cada um de seus vértices. Cada cadeira precisa
memorizar apenas uma matriz que representa a sua posição e outra que
representa como ela está rotacionada (nem todas podem estar de pé e
voltadas para a mesma direção). E precisa também de um ponteiro para a
definição geral de todas as cadeiras onde informações mais gerais
podem ser obtidas.

Então, o que chamamos de definição de um objeto (ou classe) deverá ter
também um vetor com informações específicas de cada exemplo de objeto
(instâncias). A quantidade de memória que cada instância usa é baixa
em relação à memória da classe (que vai ter a lista de vértices,
texturas e essas coisas). Sendo assim, podemos usar um vetor estático
para armazenar cada instância. A questão é: qual o tamanho deste
vetor? Ou qual o número máximo de instâncias que uma classe pode ter?
Esta questão é relevante pelo fato de querermos armazenar o máximo
possível de coisas em vetores sequenciais ao invés de coisas que usam
muitos ponteiros como referência (listas encadeadas). Além disso, nosso
gerenciador de memória não suporta algo como |realloc|. Então,
contamos que haja no \texttt{conf/conf.h} uma macro que informe isso:

\begin{itemize}
\item|W_MAX_CLASSES|: O número máximo de classes que pode ser definida.
\item|W_MAX_INSTANCES|: O número máximo de instâncias que um objeto
  Weaver pode ter. Se você definir uma cadeira, o número máximo de
  cadeiras simultâneas que podem existir é este.
\end{itemize}

E a nossa definição de Objeto Weaver é:

@(project/src/weaver/wobject.h@>=
#ifndef _wobject_h_
#define _wobject_h_
#ifdef __cplusplus
  extern "C" {
#endif

@<Inclui Cabeçalho de Configuração@>@/

@<Wobject: Cabeçalho@>@/

@<Wobject: Declaração@>@/

#ifdef __cplusplus
  }
#endif
#endif
@

@<Wobject: Cabeçalho@>=
union Wobject{
  @<Wobject: Tipo de Objeto@>@/
};

union Wclass{
  @<Wobject: Tipo de Classe@>@/
};
@

@(project/src/weaver/wobject.c@>=
#include "weaver.h"

@<Wobject: Definição@>@/

@

@*1 Definindo a Classe de Objetos Básicos.

O primeiro tipo de objeto que definiremos são objetos básicos. Ou,
|basic|, como definiremos no código. Tudo o que pode ser feito com um
objeto básico é exibir seus vértices, movê-los e rotacioná-los. Em
suma, qualquer coisa que pode ser feita com qualquer tipo de
objeto. Objetos Básicos não são úteis por si só. Mas o código inicial
que criarmos para ele poderá ser reaproveitado em todos os outros
objetos, então nós os criamos mais para usá-los internamente para
definir outros objetos que para usá-los externamente.

Apesar deles serem relativamente simples, já precisamos de vários
dados diferentes para conseguirmos defini-los:

@<Wobject: Cabeçalho@>=
// Tipo de Wobject:
#define W_NONE  0  
#define W_BASIC 1
@

@<Wobject: Tipo de Classe@>=
struct{
  int type;
  int number_of_objects;
  int number_of_vertices;
  int essential;
  float *vertices;
  GLuint _vertex_object, _buffer_object;
  float width, height, depth;
  union Wobject instances[W_MAX_INSTANCES];
} basic;
@

Destas coisas que usamos na definição, a única coisa que ainda não
discutimos é a variável |essential|. O propósito desta variável tem à
ver com o gerenciamento de novas instâncias. Vamos supor que
|W_MAX_INSTANCES| é igual à 5. Isso significa que cada classe de
objeto só pode ter 5 instâncias. Mas o que deve acontecer se já
existirem 5 objetos e então pedirmos para criar mais um? Se definimos
este tipo de objeto como não-essencial (a variável for 0), então
iremos apagar o objeto mais antigo e colocamos o novo objeto em seu
lugar. Já se o objeto for essencial, não podemos apagá-lo somente para
que ceda lugar à um novo. Neste caso, a criação do novo objeto irá
falhar e a função de criação retornará |NULL|. Por padrão, assumiremos
que todo objeto será não-essencial, à menos que diga-se o contrário.

A instância de um objeto básico terá a seguinte forma:

@<Wobject: Tipo de Objeto@>=
struct{
  int type;
  int number;
  int visible;
  float x, y, z;
  float scale_x, scale_y, scale_z;
  float translation[4][4];
  float angle_x, angle_y, angle_z;
  float rotation_x[4][4], rotation_y[4][4], rotation_z[4][4];
  float rotation_total[4][4];
  float scale_matrix[4][4];
  float model_matrix[4][4];
  float model_view_matrix[4][4];
  float normal_matrix[4][4];
  union Wclass *wclass;
} basic;
@

Cada objeto terá um número entre 0 e |W_MAX_INSTANCES|. Objetos mais
antigos terão números menores. Esta variável será usada para
identificarmos quais são os objetos mais antigos. Estes serão os
desalocados se for necessário e se a sua classe for marcada como
não-essencial.

Outra coisa que devemos lembrar. A própria API Weaver deve estar
ciente de todas as classes já definidas. Isso precisa ser feito para
que durante o loop principal ela possa fazer coisas como desenhá-las
na tela ou calcular interações físicas dependendo da forma. Por causa
disso, vamos definir um vetor de classes de objetos a ser usado
durante a execução do programa:

@<Cabeçalhos Weaver@>+=
#include "wobject.h"

extern union Wclass _wclasses[W_MAX_CLASSES];
@

@<API Weaver: Definições@>+=
union Wclass _wclasses[W_MAX_CLASSES];
@

Inicializamos esta lista de classes no início do programa:

@<API Weaver: Inicialização@>+=
{
  int i;
  for(i = 0; i <  W_MAX_CLASSES; i ++){
    _wclasses[i].basic.type = W_NONE;
  }
}
@

Como objetos básicos não foram feitos para serem usados diretamente, a
sua função de definição começará com um ``underline'':

@<Wobject: Declaração@>=
union Wclass *_define_basic_object(int number_of_vertices, float *vertices);
@

@<Wobject: Definição@>=
union Wclass *_define_basic_object(int number_of_vertices, float *vertices){
  int i, j, total;
  // Variáveis usadas para deixar a coordenada (0,0,0) no centro da imagem:
  float min_x, max_x, min_y, max_y, min_z, max_z;
  float x_offset, y_offset, z_offset;
  min_x = min_y = min_z = INFINITY;
  max_x = max_y = max_z = - INFINITY;
  // Primeiro tentamos alocar uma classe no vetor de classes:
  for(i = 0; i < W_MAX_CLASSES; i ++){
    if(_wclasses[i].basic.type == W_NONE)
      break;
  }
  if(i >= W_MAX_CLASSES)
    return NULL;

  // Se conseguimos, preenchemos os dados da classe:
  _wclasses[i].basic.type = W_BASIC;
  _wclasses[i].basic.number_of_objects = 0;
  _wclasses[i].basic.number_of_vertices = number_of_vertices;
  _wclasses[i].basic.essential = 0;
  /* O vetor de vértices deve ser grande o bastante para armazenar as
     coordenadas do vértice (3 floats) e o vetor normal de cada
     vértice para o cálculo de iluminação (3 floats) */
  _wclasses[i].basic.vertices = (float *) Walloc(sizeof(float) *
						 (number_of_vertices + 1) * 6);
  if(_wclasses[i].basic.vertices == NULL)
    return NULL;
  total = (number_of_vertices + 1) * 6;
  /* Vértices armazenados no vetor à partir da posição 1. A posição 0
     é ignorada. Isso somente em |_wclasses[i].basic.vertices|, não em
     |vertices|, que é de onde lemos o vértice. Ver abaixo o
     motivo. */
  for(j = 6; j < total; j += 6){
    _wclasses[i].basic.vertices[j] = vertices[(j-6)/2];
    if(min_x > vertices[j]) min_x = vertices[(j-6)/2];
    if(max_x < vertices[j]) max_x = vertices[(j-6)/2];
    _wclasses[i].basic.vertices[j+1] = vertices[(j-4)/2];
    if(min_y > vertices[j+1]) min_y = vertices[(j-4)/2];
    if(max_y < vertices[j+1]) max_y = vertices[(j-4)/2];
    _wclasses[i].basic.vertices[j+2] = vertices[(j-2)/2];
    if(min_z > vertices[j+2]) min_z = vertices[(j-2)/2];
    if(max_z < vertices[j+2]) max_z = vertices[(j-2)/2];
  }
  // Corrigindo a posição dos vértices para que (0,0,0) fique no meio:
  x_offset = -(min_x + max_x) / 2;
  y_offset = -(min_y + max_y) / 2;
  z_offset = -(min_z + max_z) / 2;
  for(j = 6; j < total; j += 6){
    _wclasses[i].basic.vertices[j] += x_offset;
    _wclasses[i].basic.vertices[j+1] += y_offset;
    _wclasses[i].basic.vertices[j+2] += z_offset;
  }
  // Preenchendo altura, largura e comprimento:
  _wclasses[i].basic.width = max_x - min_x;
  _wclasses[i].basic.height = max_y - min_y;
  _wclasses[i].basic.depth = max_z - min_z;
  // Inicializando os vértices e buffers OpenGL
  glGenVertexArrays(1, &_wclasses[i].basic._vertex_object);
  glBindVertexArray(_wclasses[i].basic._vertex_object);
  glGenBuffers(1, &_wclasses[i].basic._buffer_object);
  glBindBuffer(GL_ARRAY_BUFFER, _wclasses[i].basic._buffer_object);
  glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 6 * (number_of_vertices + 1),
	       _wclasses[i].basic.vertices, GL_STATIC_DRAW);

  // Inicializando as instâncias
  for(j = 0; j < W_MAX_INSTANCES; j ++){
    int k, l;
    _wclasses[i].basic.instances[j].basic.type = W_NONE;
    _wclasses[i].basic.instances[j].basic.wclass = &(_wclasses[i]);
    _wclasses[i].basic.instances[j].basic.number = -1;
    _wclasses[i].basic.instances[j].basic.x = 0;
    _wclasses[i].basic.instances[j].basic.y = 0;
    _wclasses[i].basic.instances[j].basic.z = 0;
    _wclasses[i].basic.instances[j].basic.scale_x = 1.0;
    _wclasses[i].basic.instances[j].basic.scale_y = 1.0;
    _wclasses[i].basic.instances[j].basic.scale_z = 1.0;
    _wclasses[i].basic.instances[j].basic.angle_x = 0;
    _wclasses[i].basic.instances[j].basic.angle_y = 0;
    _wclasses[i].basic.instances[j].basic.angle_z = 0;
    _wclasses[i].basic.instances[j].basic.visible = 1;
    /* inicializando as matrizes como matrizes identidade: */
    for(k = 0; k < 4; k ++)
      for(l = 0; l < 4; l ++){
	if(k == l){
	  _wclasses[i].basic.instances[j].basic.rotation_x[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.rotation_y[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.rotation_z[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.rotation_total[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.translation[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.scale_matrix[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.model_matrix[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.model_view_matrix[k][l] = 1;
	  _wclasses[i].basic.instances[j].basic.normal_matrix[k][l] = 1;
	}
	else{
	  _wclasses[i].basic.instances[j].basic.rotation_x[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.rotation_y[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.rotation_z[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.rotation_total[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.translation[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.scale_matrix[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.model_matrix[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.model_view_matrix[k][l] = 0;
	  _wclasses[i].basic.instances[j].basic.normal_matrix[k][l] = 0;
	}
      }
  }
  return &(_wclasses[i]);
}
@

Talvez seja estranho no código acima que aloquemos espaço para $n+1$
vértices, quando precisamos de $n$ vértices e que ignoremos a primeira
posição (a posição 0). Isso acontece que no OpenGL ES, o qual é usado
em navegadores de Internet na forma de WebGL, podemos desenhar figuras
na tela passando índices dos vértices que usaremos na ordem correta
(|glDrawElements|). Entretanto, o valor de zero é reservado para
interromper a continuidade do desenho atual e por isso não é um índice
válido. Por causa disso, lidamos com tal escolha de projeto
questionável fazendo com que internamente nunca precisemos referenciar
um vértice na posição zero. Futuramente, no próximo capítulo,
esconderemos do usuário esta bagunça fazendo com que ele possa usar o
zero para se referir à primeira posição e possa usar alguma macro para
interromper o desenho. A API fará a tradução conforme necessário.

Caso não precisemos mais de uma classe de objeto básico, podemos
querer removê-la. Alguns ``buracos'' podem se formar entre as classes
por causa disso. Não podemos removê-los movendo as próximas classes
porque cada classe é identificada pelo seu endereço na memória. Isso
também nos impede de ordená-las. Entretanto, como o usuário tem
controle sobre o número de classes suportadas (o tamanho do vetor de
classes) e como o acesso à uma região contínua de memória é muito
rápida, estima-se que isso não será um problema.

@<Wobject: Declaração@>=
void _undefine_basic_object(union Wclass *wclass);
@

@<Wobject: Definição@>=
void _undefine_basic_object(union Wclass *wclass){
  int i;
  // Localiza a classe:
  for(i = 0; i < W_MAX_CLASSES; i ++)
    if(&(_wclasses[i]) == wclass)
      break;
  if(i >= W_MAX_CLASSES)
    return;
  // Marca o espaço da classe como vazio:
  _wclasses[i].basic.type = W_NONE;
  // Desaloca os vetores alocados:
  Wfree(_wclasses[i].basic.vertices);
}
@

Uma última coisa que iremos querer fazer com relação às definições de
classes é evitar uma mensagem de vazamento de memória ao encerrar o
programa. Um usuário pode tanto escolher desalocar manualmente as suas
classes ou não. Caso ele não desaloque, quando o programa se encerrar,
iremos desalocá-las automaticamente. Desta forma, quando encerrarmos o
nosso gerenciador de memória, ele não encontrará memória
não-desalocada na forma de vetores de vértices:

@<API Weaver: Desalocações@>=
{
  int i;
  for(i = W_MAX_CLASSES - 1; i >= 0; i --){
    if(_wclasses[i].basic.type == W_BASIC){
      Wfree(_wclasses[i].basic.vertices);
      _wclasses[i].basic.type = W_NONE;
      continue;
    }
    @<Desalocação Automática de Classes@>@/
  }
}
@

Ainda assim, a única forma de evitar mensagens que acusam memória
desalocada na ordem errada é realmente desalocar manualmente a
definição de classes.

@*1 Criando Instâncias de Objetos Básicos.

Criar uma nova instância geralmente é fácil. Se existirem menos
instâncias que o permitido, é só percorrer o vetor de instâncias de
uma classe, encontrar um vazio e marcá-lo como não-vazio. Se tudo já
estiver preenchido e a classe for essencial, então simplesmente
retornamos |NULL|. O único caso mais complicado é quando tudo já está
preenchido e estamos diante de uma classe não-essencial. Neste caso,
percorremos todas as instâncias e decrementamos o seu número. A
instâncias que ficar com um -1 é a mais antiga e será
removida. Reinicializamos todos os seus valores. E ajustamos o seu
número como sendo |W_MAX_INSTANCES-1|:

@<Wobject: Declaração@>=
union Wobject *_new_basic_object(union Wclass *wclass);
@

@<Wobject: Definição@>=
union Wobject *_new_basic_object(union Wclass *wclass){
  int i;
  // Caso 1: Tem espaço pra mais um objeto
  if(wclass -> basic.number_of_objects < W_MAX_INSTANCES){
    for(i = 0; i < W_MAX_INSTANCES; i ++){
      if(wclass -> basic.instances[i].basic.type == W_NONE){
	wclass -> basic.instances[i].basic.type = W_BASIC;
	wclass -> basic.instances[i].basic.number = wclass ->
	  basic.number_of_objects;
	wclass -> basic.number_of_objects ++;
	return &(wclass -> basic.instances[i]);
      }
    }
    return NULL;
  }
  // Caso 2: Não tem e é uma classe essencial
  else if(wclass -> basic.essential)
    return NULL;
  // Caso 3: Não tem e não é uma classe essencial
  else{
    int k, l;
    union Wobject *ptr;
    for(i = 0; i < W_MAX_INSTANCES; i ++){
      wclass -> basic.instances[i].basic.number --;
      if(wclass -> basic.instances[i].basic.number == -1)
	wclass -> basic.instances[i].basic.number = W_MAX_INSTANCES - 1;
	ptr = &(wclass -> basic.instances[i]);
    }
    ptr -> basic.x = 0;
    ptr -> basic.y = 0;
    ptr -> basic.z = 0;
    ptr -> basic.angle_x = 0;
    ptr -> basic.angle_y = 0;
    ptr -> basic.angle_z = 0;
    ptr -> basic.scale_x = 1.0;
    ptr -> basic.scale_y = 1.0;
    ptr -> basic.scale_z = 1.0;

    ptr -> basic.visible = 1;
    // Ininicializando as matrizes de rotação e translação:
    for(k = 0; k < 4; k ++)
      for(l = 0; l < 4; l ++){
	if(k == l){
	  ptr -> basic.rotation_x[k][l] = 1;
	  ptr -> basic.rotation_y[k][l] = 1;
	  ptr -> basic.rotation_z[k][l] = 1;
	  ptr -> basic.rotation_total[k][l] = 1;
	  ptr -> basic.translation[k][l] = 1;
	  ptr -> basic.scale_matrix[k][l] = 1;
	  ptr -> basic.model_matrix[k][l] = 1;
	  ptr -> basic.normal_matrix[k][l] = 1;
	  ptr -> basic.model_view_matrix[k][l] = 1;
	}
	else{
	  ptr -> basic.rotation_x[k][l] = 0;
	  ptr -> basic.rotation_y[k][l] = 0;
	  ptr -> basic.rotation_z[k][l] = 0;
	  ptr -> basic.rotation_total[k][l] = 0;
	  ptr -> basic.translation[k][l] = 0;
	  ptr -> basic.scale_matrix[k][l] = 0;
	  ptr -> basic.model_view_matrix[k][l] = 0;
	  ptr -> basic.model_matrix[k][l] = 0;
	  ptr -> basic.normal_matrix[k][l] = 0;
	}
      }
    return ptr;
  }
}
@

Já destruir um objeto é algo um pouco mais direto. Marca-se o objeto
como desalocado, decrementa o contador de objetos da classe e
decrementa-se o número de todos os objetos da classe que tinham um
número maior que o objeto destruído:

@<Wobject: Declaração@>=
void _destroy_basic_object(union Wobject *wobj);
@

@<Wobject: Definição@>=
void _destroy_basic_object(union Wobject *wobj){
  union Wclass *wclass;
  int number, i;
  wclass = wobj -> basic.wclass;
  number = wobj -> basic.number;
  wobj -> basic.type = W_NONE;
  wclass -> basic.number_of_objects --;
  for(i = 0; i < W_MAX_INSTANCES; i ++){
    if(wclass -> basic.instances[i].basic.number > number)
      wclass -> basic.instances[i].basic.number --;
  }
}
@

@*1 Processando Objetos no Loop Princpal.

Qundo estamos em um loop principal, temos que processar os
objetos. Isso envolve desenhá-los na tela se forem visíveis e para
objetos mais sofisticados, movê-los, realizar colisões e coisas
assim. O modo de fazer isso é percorrer o vetor de classes e cada um
de seus objetos e fazer as operações adequadas para cada um deles no
loop principal:

@<API Weaver: Loop Principal@>+=
{
  int i, j;
  for(i = 0; i < W_MAX_CLASSES; i ++){
    switch(_wclasses[i].basic.type){
    case W_NONE:
      continue;
    case W_BASIC:
      for(j = 0; j < W_MAX_INSTANCES; j ++){
	if(_wclasses[i].basic.instances[j].basic.type == W_NONE)
	  continue;
	@<Transformação Linear de Objeto (i, j)@>@/
        glVertexAttribPointer(_shader_vPosition, 3, GL_FLOAT, GL_FALSE,
			      6 * sizeof(float), (void *) 0);
	glVertexAttribPointer(_shader_VertexNormal, 3, GL_FLOAT, GL_FALSE,
			      6 * sizeof(float), (void *) (sizeof(float) * 3));
	glEnableVertexAttribArray(_shader_vPosition);
	glEnableVertexAttribArray(_shader_VertexNormal);
	glBindVertexArray(_wclasses[i].basic._vertex_object);
	/* Note que abaixo ignoramos o primeiro vértice. Seu valor não
	   deve ser usado conforme mencionado na definição de classe: */
	glDrawArrays(GL_POINTS, 1, _wclasses[i].basic.number_of_vertices);
      }
      continue;
      @<Desenho de Objetos no Loop Principal@>@/
    }
  }
}
@

@*1 Escala de Objetos.

Objetos podem ser esticados ou comprimidos ao longo dos eixos $x$, $y$
e $z$. Se ele for esticado ou comprimido a mesma quantidade nos três
eixos ele cresce ou encolhe mantendo a proporção. Caso contrário, ele
sofre uma deformação. A possibilidade de podermos fazer esta
transformação com ele é o motivo de cada objeto possuir valores
|scale_x|, |scale_y| e |scale_z|, e também o de possuir uma matriz
$4\times 4$ chamada |scale_matrix|.

A matriz serve para representar a própria transformação linear que
representa a escala de um objeto. Por exemplo, assumindo que queremos
deixar um vetor $(x, y, z, 1)$ ao todo $a$ vezes maior no eixo $x$,
$b$ vezes maior no eixo $y$ e $c$ vezes maior no eixo $z$, então
podemos representar a transformação por meio da seguinte multiplicação
de matrizes:

$$
\begin{bmatrix}
    a & 0 & 0 & 0 \\
    0 & b & 0 & 0 \\
    0 & 0 & c & 0 \\
    0 & 0 & 0 & 1 \\
\end{bmatrix}
\begin{bmatrix}
  x\\
  y\\
  z\\
  1\\
\end{bmatrix} =
\begin{bmatrix}
  ax\\
  by\\
  cz\\
  1\\
\end{bmatrix}
$$

A matriz será o que será passada para a GPU para o cálculo.  Já os
valores |scale_x|, |scale_y| e |scale_z| será mais útil para a
CPU. Modificar a escala de um objeto pode ser feito então com o
seguinte código:

@<Wobject: Declaração@>=
void Wscale(union Wobject *wobj, float scale_x, float scale_y, float scale_z);
@

@<Wobject: Definição@>=
void Wscale(union Wobject *wobj, float scale_x, float scale_y, float scale_z){
  wobj -> basic.scale_x = scale_x;
  wobj -> basic.scale_y = scale_y;
  wobj -> basic.scale_z = scale_z;
  wobj -> basic.scale_matrix[0][0] = scale_x;
  wobj -> basic.scale_matrix[1][1] = scale_y;
  wobj -> basic.scale_matrix[2][2] = scale_z;
  _regenerate_model_matrix(wobj);
}
@

A última linha da função na qual invocamos a função ainda não definida
|_regenerate_model_matrix| serve para que a matriz modelo de nosso
objeto seja atualizada. Esta matriz representa a multiplicação de
todas as matrizes que representam transformações lineares pelas quais
nosso objeto irá passar. Sendo assim, toda vez que uma das matrizes do
objeto for modificada, ela precisará ser gerada novamente. Por
representar a união de todas as transformações lineares de um objeto,
essa é a matriz que realmente será passada para a GPU.

@*1 Translação de Objetos.

A translação é usada para mover todos os pontos de um objeto no eixo
XYZ. Ela é algo que ocorre para cada um dos vértices dentro da GPU
durante o shader de vértice. Como é algo feito pela GPU, então é algo
feito de modo mais eficiente se for expresso como uma multiplicação de
matrizes. Para realizar uma translação de um ponto $(x, y, z)$ em um
espaço cartesiano tridimensional, movendo-o $(a, b, c)$ posições,
realizamos a seguinte multiplicação:

$$
\begin{bmatrix}
    1 & 0 & 0 & a \\
    0 & 1 & 0 & b \\
    0 & 0 & 1 & c \\
    0 & 0 & 0 & 1 \\
\end{bmatrix}
\begin{bmatrix}
  x\\
  y\\
  z\\
  1\\
\end{bmatrix} =
\begin{bmatrix}
  x+a\\
  y+b\\
  z+c\\
  1\\
\end{bmatrix}
$$

Como nós armazenamos esta matriz $4\times 4$, nem mesmo seria
necessário fazer com que os objetos tivessem atributos |x|, |y| e
|z|. Tais variáveis existem só por questão de conveniência de acesso
das coordenadas dos objetos.

Um função que realiza a translação de um objeto pode ser definida
então da seguinte forma:

@<Wobject: Declaração@>=
void Wtranslate(union Wobject *wobj, float x, float y, float z);
@

@<Wobject: Definição@>=
void Wtranslate(union Wobject *wobj, float x, float y, float z){
  wobj -> basic.x += x;
  wobj -> basic.y += y;
  wobj -> basic.z += z;
  wobj -> basic.translation[0][3] += x;
  wobj -> basic.translation[1][3] += y;
  wobj -> basic.translation[2][3] += z;
  _regenerate_model_matrix(wobj);
}
@

@*1 Rotação de Objetos.

Rotacionar um objeto é girá-lo ao redor de um eixo que passa pelo seu
próprio centro. Os eixos nos quais permitiremos rotação são o $x$, $y$
e $z$. Como o objeto já está inicialmente centralizado em $(0, 0, 0)$,
a matriz para rotacioná-lo em um ângulo $\theta$ no eixo $x$ é:

$$
\begin{bmatrix}
    1 & 0 & 0 & 0\\
    0 & cos\theta & -sin\theta & 0\\
    0 & sin\theta & cos\theta & 0\\
    0 & 0 & 0 & 1\\
\end{bmatrix}
\begin{bmatrix}
  x\\
  y\\
  z\\
  1\\
\end{bmatrix} =
\begin{bmatrix}
  x\\
  y\ cos\theta - z\ sin\theta\\
  y\ sin\theta + z\ cos\theta\\
  1\\
\end{bmatrix}
$$

E no eixo $y$:

$$
\begin{bmatrix}
    cos\theta & 0 & sin\theta & 0\\
    0 & 1 & 0 & 0\\
    -sin\theta & 0 & cos\theta & 0\\
    0 & 0 & 0 & 1\\
\end{bmatrix}
\begin{bmatrix}
  x\\
  y\\
  z\\
  1\\
\end{bmatrix} =
\begin{bmatrix}
  x\ cos\theta + z\ sin\theta\\
  y\\
  -x\ sin\theta + z\ cos\theta\\
  1\\
\end{bmatrix}
$$

E finalmente, no eixo $z$:

$$
\begin{bmatrix}
    cos\theta & -sin\theta & 0 & 0\\
    sin\theta & cos\theta & 0 & 0\\
    0 & 0 & 1 & 0\\
    0 & 0 & 0 & 1\\
\end{bmatrix}
\begin{bmatrix}
  x\\
  y\\
  z\\
  1\\
\end{bmatrix} =
\begin{bmatrix}
  x\ cos\theta - y\ sin\theta\\
  x\ sin\theta + y\ cos\theta\\
  z\\
  1\\
\end{bmatrix}
$$

E para modificarmos estas matrizes, podemos então definir a função
|Wrotate|, análoga à |Wtranslate|:

@<Wobject: Declaração@>=
void Wrotate(union Wobject *wobj, float x, float y, float z);
@

@<Wobject: Definição@>=
void Wrotate(union Wobject *wobj, float x, float y, float z){
  float aux[4][4];
  wobj -> basic.angle_x += x;
  wobj -> basic.angle_y += y;
  wobj -> basic.angle_z += z;

  if(x != 0){
    wobj -> basic.rotation_x[1][1] = cosf(wobj -> basic.angle_x);
    wobj -> basic.rotation_x[1][2] = sinf(wobj -> basic.angle_x);
    wobj -> basic.rotation_x[2][1] = -sinf(wobj -> basic.angle_x);
    wobj -> basic.rotation_x[2][2] = cosf(wobj -> basic.angle_x);
  }
  if(y != 0){
    wobj -> basic.rotation_y[0][0] = cosf(wobj -> basic.angle_y);
    wobj -> basic.rotation_y[0][2] = sinf(wobj -> basic.angle_y);
    wobj -> basic.rotation_y[2][0] = -sinf(wobj -> basic.angle_y);
    wobj -> basic.rotation_y[2][2] = cosf(wobj -> basic.angle_y);
  }
  if(z != 0){
    wobj -> basic.rotation_z[0][0] = cosf(wobj -> basic.angle_z);
    wobj -> basic.rotation_z[0][1] = -sinf(wobj -> basic.angle_z);
    wobj -> basic.rotation_z[1][0] = sinf(wobj -> basic.angle_z);
    wobj -> basic.rotation_z[1][1] = cosf(wobj -> basic.angle_z);
  }
  // Multiplicamos agora as matrizes. Primeiro a rotação X pela Y:
  _matrix_multiplication4x4(wobj -> basic.rotation_x, wobj -> basic.rotation_y,
			    aux);
  // E depois multiplicamos o resultado por Z:
  _matrix_multiplication4x4(aux, wobj -> basic.rotation_z,
			    wobj -> basic.rotation_total);
  // Por fim, atualizamos a matriz de modelo:
  _regenerate_model_matrix(wobj);
}
@

Definiremos a multiplicação de matrizes com outras funções auxiliares
ao fim do capítulo.


@*1 A Matriz de Modelo.

Tendo já definido as várias transformações lineares possíveis para um
objeto, agora já podemos combinar todas elas em uma só matriz. Para
isso, é só finalmente definirmos a função
|_regenerate_model_matrix|. Ela envolve apenas a multiplicação de
várias matrizes até obtermos a nossa matriz de modelo. A única coisa
com a qual temos de nos preocupar é com a ordem das multiplicações. Os
efeitos são diferentes dependendo de como multiplicamos as matrizes. A
ordem que usaremos será:

$$
v \times (T \times R \times S)
$$

Onde $v$ é o vértice dentro do shader, $T$ é a translação, $R$ é a
rotação e $S$ é a escala. A ordem é invertida devido à forma pela qual
o vértice e as matrizes são multiplicadas. A translação fica mais
próxima do vértice porque ela deve ser feita separadamente da rotação
e da escala pelo fato de mudar a origem do nosso modelo do centro da
figura para o centro do mundo no qual estamos. A rotação e a escala
funcionam assumindo que a origem é o centro do objeto que elas
transformam.

@<Wobject: Declaração@>=
void _regenerate_model_matrix(union Wobject *wobj);
@

@<Wobject: Definição@>=
void _regenerate_model_matrix(union Wobject *wobj){
  float aux[4][4];
  _matrix_multiplication4x4(wobj -> basic.translation,
			    wobj -> basic.rotation_total,			    
			    aux);
  _matrix_multiplication4x4(aux,
			    wobj -> basic.scale_matrix,			    
			    wobj -> basic.model_matrix);
  _regenerate_model_view_matrix(wobj);
}
@

Note que toda vez que geramos novamente a matriz de modelo de um
objeto, geramos novamente a sua matriz de modelo e visualização. A
matriz de modelo e visualização tem tanto informações sobre os
movimentos feitos sobre um objeto como sobre os movimentos feitos pela
câmera. Por causa disso, esta é a matriz que nós realmente passamos
para o shader.

Agora vamos declarar no shader de vértice a matriz de modelo e
visualização que será modificada toda vez que formos renderizar um
novo objeto:

@<Shader de Vértice: Declarações@>+=
  uniform mat4 Wmodelview_matrix;
@

Durante a inicialização o programa em C vai precisar obter a
localização desta variável GLSL:

@<API Weaver: Definições@>+=
  static GLfloat _shader_model_matrix;
@

@<API Weaver: Inicialização@>+=
{
  _shader_model_matrix = glGetUniformLocation(_program, "Wmodelview_matrix");
}
@

O lugar de atualizar o valor desta matriz no programa em C é
imediatamente antes de renderizar cada objeto. Atualizar esta matriz é
realizar a transformação linear do objeto:

@<Transformação Linear de Objeto (i, j)@>=
{
  float *p = (float *) &_wclasses[i].basic.instances[j].basic.model_view_matrix;
  glUniformMatrix4fv(_shader_model_matrix, 1, GL_FALSE, p);
}
@

Dentro do shader de vértice aplicamos a matriz de modelo como sendo o
primeiro tratamento para cada vértice:

@<Shader de Vértice: Aplicar Matriz de Modelo@>=
  gl_Position *= Wmodelview_matrix;
@

@*1 Translação e Rotação da Câmera.

Outra coisa que vamos precisar fazer é, além de mover objetos, mover
também a câmera. Isso implica que será útil para nós armazenarmos a
coordenada atual da câmera. Para isso definiremos um novo arquivo de
código-fonte e declararemos as estruturas necessárias nele:

@(project/src/weaver/camera.h@>=
#ifndef _camera_h_
#define _camera_h_
#ifdef __cplusplus
  extern "C" {
#endif

@<Inclui Cabeçalho de Configuração@>@/

@<Câmera: Cabeçalho@>@/

@<Câmera: Declaração@>@/

#ifdef __cplusplus
  }
#endif
#endif
@
@<Cabeçalhos Weaver@>+=
#include "camera.h"
@

@(project/src/weaver/camera.c@>=
#include "weaver.h"

@<Câmera: Definição@>@/

@

Assim como os objetos, a câmera também terá matrizes representando a
transformação de translação e rotação (mas não escala). E também uma
matriz que representa a união das outras transformações (a matriz de
visualização):

@<Câmera: Cabeçalho@>=
  extern float Wcamera_x, Wcamera_y, Wcamera_z;
  extern float Wcamera_angle_x, Wcamera_angle_y, Wcamera_angle_z;
  extern float _view_matrix[4][4];
@

@<Câmera: Definição@>=
  float Wcamera_x, Wcamera_y, Wcamera_z;
  float Wcamera_angle_x, Wcamera_angle_y, Wcamera_angle_z;
  static float _camera_translation[4][4];
  static float _camera_rotation_x[4][4], _camera_rotation_y[4][4];
  static float _camera_rotation_z[4][4], _camera_rotation_total[4][4];
  float _view_matrix[4][4];
@

Na inicialização da API Weaver inicializamos o valor da posição da
câmera e inicializamos todas as matrizes. Definiremos uma função de
inicialização de câmera para nos ajudar:

@<Câmera: Declaração@>=
void _initialize_camera(void);
@

@<Câmera: Definição@>=
void _initialize_camera(void){
  int i, j;
  Wcamera_x = Wcamera_y = Wcamera_z = 0.0;
  Wcamera_angle_x = Wcamera_angle_y = Wcamera_angle_z = 0.0;
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      if(i == j){
	_camera_translation[i][j] = 1.0;
	_camera_rotation_x[i][j] = 1.0;
	_camera_rotation_y[i][j] = 1.0;
	_camera_rotation_z[i][j] = 1.0;
	_camera_rotation_total[i][j] = 1.0;
	_view_matrix[i][j] = 1.0;
      }
      else{
	_camera_translation[i][j] = 0.0;
	_camera_rotation_x[i][j] = 0.0;
	_camera_rotation_y[i][j] = 0.0;
	_camera_rotation_z[i][j] = 0.0;
	_camera_rotation_total[i][j] = 0.0;
	_view_matrix[i][j] = 0.0;
      }
}
@

@<API Weaver: Inicialização@>+=
  _initialize_camera();
@

Agora quanto a realizar translação de câmeras e de objetos, as duas
coisas são muito semelhantes. De fato, mover a câmera para a direita é
equivalente a mover todos os objetos para a esquerda, e
vice-versa. Portanto, caso a câmera sofre rotação, nós atualizamos a
sua matriz de maneira idêntica. Só que com valores invertidos, pois
tal matriz será depois multiplicada com a matriz de modelo de cada
objeto para assim termos a matriz de modelo e visualização.

O nosso código de translação de câmera é:

@<Câmera: Declaração@>=
void Wtranslate_camera(float x, float y, float z);
@

@<Câmera: Definição@>=
void Wtranslate_camera(float x, float y, float z){
  Wcamera_x += x;
  Wcamera_y += y;
  Wcamera_z += z;
  _camera_translation[0][3] = - Wcamera_x;
  _camera_translation[1][3] = - Wcamera_y;
  _camera_translation[2][3] = - Wcamera_z;
  _regenerate_view_matrix();
}
@

Assim como fizemos na definição de transformação d eobjetos,
definiremos posteriormente a função |_regenerate_view_matrix|.

A rotação da câmera envolve girar todos os demais objetos ao redor da
câmera no sentido inverso do pedido. Para isso, basta simplesmente
rotacionarmos os objetos depois que as suas coordenadas estiverem com
a origem onde está a câmera.

A função de rotacionar a câmera então é semelhante à rotação de um
objeto e envolve modificar as matrizes relacionadas à câmera. Com a
diferença de que invertemos os ângulos antes de passarmos para a
matriz:

@<Câmera: Declaração@>=
void Wrotate_camera(float x, float y, float z);
@

@<Câmera: Definição@>=
void Wrotate_camera(float x, float y, float z){
  float aux[4][4];
  Wcamera_angle_x -= x;
  Wcamera_angle_y -= y;
  Wcamera_angle_z -= z;

  if(x != 0){
    _camera_rotation_x[1][1] = cosf(Wcamera_angle_x);
    _camera_rotation_x[1][2] = -sinf(Wcamera_angle_x);
    _camera_rotation_x[2][1] = sinf(Wcamera_angle_x);
    _camera_rotation_x[2][2] = cosf(Wcamera_angle_x);
  }
  if(y != 0){
    _camera_rotation_y[0][0] = cosf(Wcamera_angle_y);
    _camera_rotation_y[0][2] = sinf(Wcamera_angle_y);
    _camera_rotation_y[2][0] = -sinf(Wcamera_angle_y);
    _camera_rotation_y[2][2] = cosf(Wcamera_angle_y);
  }
  if(z != 0){
    _camera_rotation_z[0][0] = cosf(Wcamera_angle_z);
    _camera_rotation_z[0][1] = -sinf(Wcamera_angle_z);
    _camera_rotation_z[1][0] = sinf(Wcamera_angle_z);
    _camera_rotation_z[1][1] = cosf(Wcamera_angle_z);
  }
  // Multiplicamos agora as matrizes. Primeiro a rotação X pela Y:
  _matrix_multiplication4x4(_camera_rotation_x, _camera_rotation_y, aux);
  // E depois multiplicamos o resultado por Z:
  _matrix_multiplication4x4(aux, _camera_rotation_z, _camera_rotation_total);
  
  _regenerate_view_matrix();
}
@

Agora enfim iremos definir a função para gerar novamente a matriz de
visualização toda vez que a câmera sofrer rotação e translação. Ela é
basicamente uma multiplicação das matrizes de rotação e
translação. Mas além disso, toda vez que modificamos esta matriz,
precisamos também percorrer todos os objetos e gerar novamente a sua
matriz de modelo e visualização.

@<Câmera: Declaração@>=
void _regenerate_view_matrix(void);
@
@<Câmera: Definição@>=
void _regenerate_view_matrix(void){
  int i, j;
  _matrix_multiplication4x4(_camera_translation,
			    _camera_rotation_total,
			    _view_matrix);
  for(i = 0; i < W_MAX_CLASSES; i ++)
    for(j =0; j < W_MAX_INSTANCES; j ++)
      _regenerate_model_view_matrix(&_wclasses[i].basic.instances[j]);
}
@

E agora por fim definimos a função que gera novamente a matriz de
modelo e visualização para cada objeto, a qual funciona simplesmente
multiplicando as matrizes de modelo e visualização. O único detalhe
adicional que fazemos aqui também é atualizar a matriz normal do
objeto, a qual é útil para calcularmos a rotação e translação dos
efeitos de luz e sombra do objeto. A matriz normal de um objeto é a
transposta da inversa da matriz de modelo-visualização:

@<Wobject: Declaração@>=
void _regenerate_model_view_matrix(union Wobject *wobj);
@

@<Wobject: Definição@>=
void _regenerate_model_view_matrix(union Wobject *wobj){
  int i, j;
  _matrix_multiplication4x4(_view_matrix,
			    wobj -> basic.model_matrix,
			    wobj -> basic.model_view_matrix);
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      wobj -> basic.normal_matrix[i][j] = wobj -> basic.model_view_matrix[i][j];
  _matrix_inverse4x4(wobj -> basic.normal_matrix);
  _matrix_transpose4x4(wobj -> basic.normal_matrix);
}
@

As funções de inverter e transpor matrizes $4\times 4$ serão definidas
ao fim do capítulo.

@*1 A Projeção de Objetos.

Após realizar todas as transformações necessárias sobre um objeto,
colocarmos ele em sua posição relativa em relação à câmera, a última
coisa que temos a fazer é definir como será feita a projeção de seus
pontos na tela. Existem muitos tipos de projeção diferentes. A mais
comum é a projeção em perspectiva, que tenta imitar mais fielmente a
visão humana fazendo com que objetos mais distantes pareçam
menores. Alguns jogos, por outro lado, baseiam-se em uma projeção
ortográfica, onde objetos mais distantes não ficam menores (Sim City,
por exemplo). Podem haver muitas outras formas de projeção para criar
diferentes tipos de efeitos visuais. O jogo \textbf{Animal Crossing:
  New Leaf}, por exemplo, possui uma projeção peculiar que faz com que
o espaço em si tenha uma curvatura cilíndrica.

Independente da projeção, assumimos que no ponto $(0, 0, 0)$ está a
nossa câmera. Na visão em perspectiva temos uma visão piramidal, onde
a ponta da pirâmide fica bem no seu ponto focal $(0,0,0)$, e a base da
pirâmide é um quadrado projetado em algum ponto distante. A pirâmide
pode ser cortada em qualquer ponto do eixo $z$ e assim obtemos um
quadrado. A proporção de um objeto na tela é a proporção dele em
relação ao quadrado obtido seccionando a nossa pirâmide no eixo $z$ na
mesma posição em que o objeto está. Desta forma, quanto mais próximo
um objeto estiver do nosso ponto focal, maior ele será, e quanto mais
distante estiver, menor ele parecerá. Na visão ortogonal, a nossa
região de visão simplesmente é um cuboide. A proporção ocupada na tela
por um objeto então é sempre a mesma, independente da distância.

Entretanto, dependendo da projeção, não poderemos representar objetos
próximos demais de nosso ponto focal. Na visão em perspectiva, à
medida que um objeto se aproxima dela, o seu tamanho tenderá ao
infinito. Deve existir então uma distância mínima que um objeto deve
estar para ser representado (o plano próximo). E independente da
projeção não podemos ficar representando objetos distantes demais. Se
algo está longe demais, geralmente não tem tanta relevância para a
cena. Então será um desperdício ficarmos renderizando ele,
principalmente se ele for formado por muitos polígonos. Além do mais,
como o buffer $z$ usado para detectar quais objetos estão na frente
dos outros tem uma precisão de apenas 8 bits, podemos acabar perdendo
a precisão desta noção quando objetos estão distantes demais. por
isso, se um objeto está além de um ponto no eixo $z$ (o plano
distante), ele também não será renderizado.

Isso faz com que precisemos de 3 valores diferentes que precisam ser
configurados. Primeiro a menor distância da câmera que um objeto pode
estar para ser detectado (|W_NEAR_PLANE|, ou $Z_{near}$), a máxima
distância que a câmera pode captar (|W_FAR_PLANE|, ou $Z_{far}$) e
também o tamanho máximo que um quadrado deve ter para ser visto por
inteiro quando está na menor distância possível da câmera
(|W_CAMERA_SIZE|, ou $n$). Estes três valores devem estar definidos e
ser configurados no \texttt{conf/conf.h}.

Tendo tais valores, o método de se obter a projeção em perspectiva é
multiplicando os vetores pela seguinte matriz:

$$
\begin{bmatrix}
    \frac{Z_{near}}{n / 2} & 0 & 0 & 0\\
    0 & \frac{Z_{near}}{n / 2} & 0 & 0\\
    0 & 0 & -\frac{Z_{far} + Z_{near}}{Z_{far} - Z_{near}} &
    \frac{-2Z_{far}Z_{near}}{Z_{far} - Z_{near}}\\
    0 & 0 & -1 & 0\\
\end{bmatrix}
$$

E para obtermos uma projeção ortográfica, usamos a seguinte matriz:

$$
\begin{bmatrix}
    \frac{1}{n / 2} & 0 & 0 & 0\\
    0 & \frac{1}{n / 2} & 0 & 0\\
    0 & 0 & -\frac{1}{2(Z_{far} - Z_{near})} &
    -\frac{Z_{far}+Z_{near}}{Z_{far} - Z_{near}}\\
    0 & 0 & 0 & 1\\
\end{bmatrix}
$$

Qual destas matrizes iremos usar? Isso também é algo que deve ser
configurável no \texttt{conf/conf.h}. Vamos definir um significado
para as macros |W_PERSPECTIVE| e |W_ORTHOGONAL| que poderão ser usadas
neste arquivo:

@(project/src/weaver/conf_begin.h@>+=
#define W_PERSPECTIVE 2
#define W_ORTHOGONAL  3
@

Ambos os valores podem ser definidos para a macro |W_PROJECTION| no
\texttt{conf/conf.h}

Como a matriz de projeção é inicializada só no começo do programa e
nunca mais é mudada, vamos declará-la como estática no mesmo arquivo
onde está a função de inicialização, e na inicialização aplicamos os
valores:

@<API Weaver: Definições@>=
  static float _projection_matrix[4][4];
@
@<API Weaver: Inicialização@>+=
{
  int i, j;
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      _projection_matrix[i][j] = 0.0;
  // Inicializando os valores diferentes de 0:
#if W_PROJECTION == W_PERSPECTIVE
  _projection_matrix[0][0] = W_NEAR_PLANE/(W_CAMERA_SIZE/2);
  _projection_matrix[1][1] = W_NEAR_PLANE/(W_CAMERA_SIZE/2);
  _projection_matrix[2][2] = -(W_FAR_PLANE+W_NEAR_PLANE) /
    (W_FAR_PLANE-W_NEAR_PLANE);
  _projection_matrix[2][3] = (-2.0*W_FAR_PLANE*W_NEAR_PLANE) /
    (W_FAR_PLANE-W_NEAR_PLANE);
  _projection_matrix[3][2] = -1.0;
#elif W_PROJECTION == W_ORTHOGONAL
  _projection_matrix[0][0] = 1.0/(W_CAMERA_SIZE/2);
  _projection_matrix[1][1] = 1.0/(W_CAMERA_SIZE/2);
  _projection_matrix[2][2] = -1.0 / ((W_FAR_PLANE-W_NEAR_PLANE)/2.0);
  _projection_matrix[2][3] = -(W_FAR_PLANE+W_NEAR_PLANE) /
    (W_FAR_PLANE-W_NEAR_PLANE);
  _projection_matrix[3][3] = 1.0;
#endif

}
@

Mas não basta apenas termos a matriz. Nós precisamos também informar
ao OpenGL a posição de |W_FAR_PLANE| e |W_NEAR_PLANE| para que o
servidor possa ignorar os objetos que estiverem fora do alcance da
câmera por estarem muito longe ou muito perto. Isso é feito invocando
na inicialização a seguinte função:

@<API Weaver: Inicialização@>+=
{
  glDepthRangef(W_NEAR_PLANE, W_FAR_PLANE);
}
@

Agora o shader precisa estar ciente da nova matriz que usaremos:

@<Shader de Vértice: Declarações@>+=
  uniform mat4 Wprojection_matrix;
@

E precisamos inicializar tal matriz no shader durante a inicialização
do programa. E também precisamos da variável do programa que vai
armazenar a localização de tal matriz dentro do shader:

@<API Weaver: Inicialização@>+=
{
  GLuint _shader_projection_address;
  float *ptr = (float *) &_projection_matrix;
  _shader_projection_address = glGetUniformLocation(_program,
						     "Wprojection_matrix");
  glUniformMatrix4fv(_shader_projection_address, 1, GL_FALSE, ptr);
}
@

Por fim, usaremos tal matriz dentro do Shader multiplicando cada um
dos vértices por ela:

@<Shader de Vértice: Câmera (Perspectiva)@>=
  gl_Position *= Wprojection_matrix;
@

@*1 Funções Auxiliares.

Vamos definir um arquivo que irá conter funções auxiliares:

@(project/src/weaver/aux.h@>=
#ifndef _aux_h_
#define _aux_h_
#ifdef __cplusplus
  extern "C" {
#endif

@<Inclui Cabeçalho de Configuração@>@/

@<Funções Auxiliares: Declaração@>@/

#ifdef __cplusplus
  }
#endif
#endif
@

@(project/src/weaver/aux.c@>=
#include "weaver.h"

@<Funções Auxiliares: Definição@>@/
@
@<Cabeçalhos Weaver@>+=
#include "aux.h"
@

@*2 Multiplicação de Matrizes $4 \times 4$.

E a nossa multiplicação de matrizes 4x4 será a primeira função que irá
para tal arquivo:

@<Funções Auxiliares: Declaração@>=
void _matrix_multiplication4x4(float a[4][4], float b[4][4],
			       float result[4][4]);
@
@<Funções Auxiliares: Definição@>=
void _matrix_multiplication4x4(float a[4][4], float b[4][4],
			       float result[4][4]){
  int i, j, k;
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++){
      result[i][j] = 0;
      for(k = 0; k < 4; k ++){
	result[i][j] += a[i][k] * b[k][j];
      }
    }
}
@

@*2 Calcular a Inversa de Matrizes $4 \times 4$.

Como estamos querendo calcular a inversa apenas de matrizes $4 \times
4$ e não de outros tamanhos, podemos apenas usar uma fórmula
``hard-coded'' que apesar de feia é testada pelo tempo e irá
funcionar:

@<Funções Auxiliares: Declaração@>=
void _matrix_inverse4x4(float m[4][4]);
@

@<Funções Auxiliares: Definição@>=
void _matrix_inverse4x4(float m[4][4]){
  float aux[4][4];
  float multiplier;
  int i, j;

  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      aux[i][j] = m[i][j];

  multiplier = 1.0/_matrix_determinant4x4(m);

  m[0][0] = aux[1][1] * aux[2][2] * aux[3][3] +
    aux[1][2] * aux[2][3] * aux[3][1] + aux[1][3] * aux[2][1] * aux[3][2] -
    aux[1][1] * aux[2][3] * aux[3][2] - aux[1][2] * aux[2][1] * aux[3][3] -
    aux[1][3] * aux[2][2] * aux[3][1];
  m[0][1] = aux[0][1] * aux[2][3] * aux[3][2] +
    aux[0][2] * aux[2][1] * aux[3][3] + aux[0][3] * aux[2][2] * aux[3][1] -
    aux[0][1] * aux[2][2] * aux[3][3] - aux[0][2] * aux[2][3] * aux[3][1] -
    aux[0][3] * aux[2][1] * aux[3][2];
  m[0][2] = aux[0][1] * aux[1][2] * aux[3][3] +
    aux[0][2] * aux[1][3] * aux[3][1] + aux[0][3] * aux[1][1] * aux[3][2] -
    aux[0][1] * aux[1][3] * aux[3][2] - aux[0][2] * aux[1][1] * aux[3][3] -
    aux[0][3] * aux[1][2] * aux[3][1];
  m[0][3] = aux[0][1] * aux[1][3] * aux[2][2] +
    aux[0][2] * aux[1][1] * aux[2][3] + aux[0][3] * aux[1][2] * aux[2][1] -
    aux[0][1] * aux[1][2] * aux[2][3] - aux[0][2] * aux[1][3] * aux[2][1] -
    aux[0][3] * aux[1][1] * aux[2][2];
  m[1][0] = aux[1][0] * aux[2][3] * aux[3][2] +
    aux[1][2] * aux[2][0] * aux[3][3] + aux[1][3] * aux[2][2] * aux[3][0] -
    aux[1][0] * aux[2][2] * aux[3][3] - aux[1][2] * aux[2][3] * aux[3][0] -
    aux[1][3] * aux[2][0] * aux[3][2];
  m[1][1] = aux[0][0] * aux[2][2] * aux[3][3] +
    aux[0][2] * aux[2][3] * aux[3][0] + aux[0][3] * aux[2][0] * aux[3][2] -
    aux[0][0] * aux[2][3] * aux[3][2] - aux[0][2] * aux[2][0] * aux[3][3] -
    aux[0][3] * aux[2][2] * aux[3][0];
  m[1][2] = aux[0][0] * aux[1][3] * aux[3][2] +
    aux[0][2] * aux[1][0] * aux[3][3] + aux[0][3] * aux[1][2] * aux[3][0] -
    aux[0][0] * aux[1][2] * aux[3][3] - aux[0][2] * aux[1][3] * aux[3][0] -
    aux[0][3] * aux[1][0] * aux[3][2];
  m[1][3] = aux[0][0] * aux[1][2] * aux[2][3] +
    aux[0][2] * aux[1][3] * aux[2][0] + aux[0][3] * aux[1][0] * aux[2][2] -
    aux[0][0] * aux[1][3] * aux[2][2] - aux[0][2] * aux[1][0] * aux[2][3] -
    aux[0][3] * aux[1][2] * aux[2][0];
  m[2][0] = aux[1][0] * aux[2][1] * aux[3][3] +
    aux[1][1] * aux[2][3] * aux[3][0] + aux[1][3] * aux[2][0] * aux[3][1] -
    aux[1][0] * aux[2][3] * aux[3][1] - aux[1][1] * aux[2][0] * aux[3][3] -
    aux[1][3] * aux[2][1] * aux[3][0];
  m[2][1] = aux[0][0] * aux[2][3] * aux[3][1] +
    aux[0][1] * aux[2][0] * aux[3][3] + aux[0][3] * aux[2][1] * aux[3][0] -
    aux[0][0] * aux[2][1] * aux[3][3] - aux[0][1] * aux[2][3] * aux[3][0] -
    aux[0][3] * aux[2][0] * aux[3][1];
  m[2][2] = aux[0][0] * aux[1][1] * aux[3][3] +
    aux[0][1] * aux[1][3] * aux[3][0] + aux[0][3] * aux[1][0] * aux[3][1] -
    aux[0][0] * aux[1][3] * aux[3][1] - aux[0][1] * aux[1][0] * aux[3][3] -
    aux[0][3] * aux[1][1] * aux[3][0];
  m[2][3] = aux[0][0] * aux[1][3] * aux[2][1] +
    aux[0][1] * aux[1][0] * aux[2][3] + aux[0][3] * aux[1][1] * aux[2][0] -
    aux[0][0] * aux[1][1] * aux[2][3] - aux[0][1] * aux[1][3] * aux[2][0] -
    aux[0][3] * aux[1][0] * aux[2][1];
  m[3][0] = aux[1][0] * aux[2][2] * aux[3][1] +
    aux[1][1] * aux[2][0] * aux[3][2] + aux[1][2] * aux[2][1] * aux[3][0] -
    aux[1][0] * aux[2][1] * aux[3][2] - aux[1][1] * aux[2][2] * aux[3][0] -
    aux[1][2] * aux[2][0] * aux[3][1];
  m[3][1] = aux[0][0] * aux[2][1] * aux[3][2] +
    aux[0][1] * aux[2][2] * aux[3][0] + aux[0][2] * aux[2][0] * aux[3][1] -
    aux[0][0] * aux[2][2] * aux[3][1] - aux[0][1] * aux[2][0] * aux[3][2] -
    aux[0][2] * aux[2][1] * aux[3][0];
  m[3][2] = aux[0][0] * aux[1][2] * aux[3][1] +
    aux[0][1] * aux[1][0] * aux[3][2] + aux[0][2] * aux[1][1] * aux[3][0] -
    aux[0][0] * aux[1][1] * aux[3][2] - aux[0][1] * aux[1][2] * aux[3][0] -
    aux[0][2] * aux[1][0] * aux[3][1];
  m[3][3] = aux[0][0] * aux[1][1] * aux[2][2] +
    aux[0][1] * aux[1][2] * aux[2][0] + aux[0][2] * aux[1][0] * aux[2][1] -
    aux[0][0] * aux[1][2] * aux[2][1] - aux[0][1] * aux[1][0] * aux[2][2] -
    aux[0][2] * aux[1][1] * aux[2][0];
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      m[i][j] *= multiplier;
}
@

@*2 Calcular o Determinante de Matrizes $4 \times 4$.

Seguido a mesma lógica de usarmos código feio, mas rápido e testado
pelo tempo, programaremos a função que retorna o determinante de
matrizes $4 \times 4$:

@<Funções Auxiliares: Declaração@>=
float _matrix_determinant4x4(float m[4][4]);
@

@<Funções Auxiliares: Definição@>=
float _matrix_determinant4x4(float m[4][4]){
  return m[0][3] * m[1][2] * m[2][1] * m[3][0] -
    m[0][2] * m[1][3] * m[2][1] * m[3][0] -
    m[0][3] * m[1][1] * m[2][2] * m[3][0] +
    m[0][1] * m[1][3] * m[2][2] * m[3][0] +
    m[0][2] * m[1][1] * m[2][3] * m[3][0] -
    m[0][1] * m[1][2] * m[2][3] * m[3][0] -
    m[0][3] * m[1][2] * m[2][0] * m[3][1] +
    m[0][2] * m[1][3] * m[2][0] * m[3][1] +
    m[0][3] * m[1][0] * m[2][2] * m[3][1] -
    m[0][0] * m[1][3] * m[2][2] * m[3][1] -
    m[0][2] * m[1][0] * m[2][3] * m[3][1] +
    m[0][0] * m[1][2] * m[2][3] * m[3][1] +
    m[0][3] * m[1][1] * m[2][0] * m[3][2] -
    m[0][1] * m[1][3] * m[2][0] * m[3][2] -
    m[0][3] * m[1][0] * m[2][1] * m[3][2] +
    m[0][0] * m[1][3] * m[2][1] * m[3][2] +
    m[0][1] * m[1][0] * m[2][3] * m[3][2] -
    m[0][0] * m[1][1] * m[2][3] * m[3][2] -
    m[0][2] * m[1][1] * m[2][0] * m[3][3] +
    m[0][1] * m[1][2] * m[2][0] * m[3][3] +
    m[0][2] * m[1][0] * m[2][1] * m[3][3] -
    m[0][0] * m[1][2] * m[2][1] * m[3][3] -
    m[0][1] * m[1][0] * m[2][2] * m[3][3] +
    m[0][0] * m[1][1] * m[2][2] * m[3][3];
}
@

@*2 Calcular a Transposição de Matrizes $4 \times 4$.

Transpor uma matriz é só trocar as coordenadas de linhas e colunas de
cada valor:

@<Funções Auxiliares: Declaração@>=
void _matrix_transpose4x4(float m[4][4]);
@

@<Funções Auxiliares: Definição@>=
void _matrix_transpose4x4(float m[4][4]){
  int i, j;
  float aux[4][4];
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      aux[i][j] = m[i][j];
  for(i = 0; i < 4; i ++)
    for(j = 0; j < 4; j ++)
      m[i][j] = aux[j][i];

}
@
