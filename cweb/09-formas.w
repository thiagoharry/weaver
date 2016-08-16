@* Formas Geométricas.

Vamos agora definir um tipo de objeto que possui seus vértices
relativamente fixos em relação uns aos outros (pode ser que eles
tenham estruturas especiais que simulem movimento de ossos, mas mesmo
assim eles tem uma forma padrão fixa e cujo movimento, se existir,
sempre será algo bem-definido). Além disso, este tipo de objeto,
quando visualizado, possui arestas e faces. Não apenas vértices.

Internamente, representaremos uma forma geométrica simples, que possui
apenas as características listadas, pelo número 2:

@<Wobject: Cabeçalho@>=
// Tipo de Wobject:
#define W_SHAPE  2  
@

Mas podem haver outros tipos de formas geométricas. Todas elas sempre
serão um múltiplo de 2. Sendo assim, serão fáceis de serem
identificadas:

@<Wobject: Cabeçalho@>=
#define Wis_shape(wobj) ((wobj -> type % 2) == 0)
@

As classes que são formas geométricas são iguais às classes de
objetos. A diferença é que elas possuem também como atributo interno
uma lista de índices que especifica a ordem de cada vértice em cada
face do polígono que será desenhado. Usa-se o número |0xFFFF| para
separar os dados de uma face da outra. E o índice de cada vértice é a
ordem na qual ele aparece na lista de vértices. Podemos nos referir ao
número mágico de separar faces por |W_FACE_BREAK|:

@<Wobject: Cabeçalho@>=
#define W_FACE_BREAK  0xffff  
@

Para que este valor possa ser usado como separador de índices de
vértices, durante a inicialização do programa precisamos chamar a
seguinte função:

@<API Weaver: Inicialização@>+=
{
  //glEnable(GL_PRIMITIVE_RESTART); // Emscripten reconhece?
}
@

Além disso, precisamos também de uma variável para armazenar o ID de
um buffer de índices de elementos OpenGL, que será a ordem na qual
cada vértice será percorrido na hora de desenhar.

Todas as faces de polígonos desenhados sempre deverão ser
convexas. Faces côncavas só poderão ser desenhadas caso sejam tratadas
como duas ou mais faces. Essa restrição simplifica muito o algoritmo
de desenho. Tudo o que precisamos fazer é pedir para o servidor OpenGL
desenhar triângulos e passar os vértices na ordem que temos. E assim
obtemos a face desejada:

@<Wobject: Tipo de Classe@>=
struct{
  // Típico de objetos:
  int type;
  int number_of_objects;
  int number_of_vertices;
  int essential;
  float *vertices;
  GLuint _vertex_object, _buffer_object;
  float width, height, depth;
  union Wobject instances[W_MAX_INSTANCES];
  // Específico de Formas Geométricas:
  int number_of_indices;
  GLushort *indices;
  GLuint _element_object;
} shape;
@

Já instâncias de tais classes seriam idênticas às instâncias de
objetos básicos. Não seria necessário nenhum atributo adicional:

@<Wobject: Tipo de Objeto@>=
struct{
  // Geral de Todos os Objetos:
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
  union Wclass *wclass;
} shape;
@

@*1 Definindo Classe e Criando Instâncias.

Definir uma forma geométrica manualmente é como definir um objeto
básico. Só precisamos depois preencher a ordem dos vértices de acordo
com a especificação de cada face:

@<Wobject: Declaração@>=
union Wclass *define_shape(int number_of_vertices, float *vertices, 
			   int number_of_faces, unsigned int *faces);
@

@<Wobject: Definição@>=
union Wclass *define_shape(int number_of_vertices, float *vertices, 
			   int number_of_faces, unsigned int *faces){
  int count = 0, number_of_indices = 0, i;
  /* Will store the number of adjacent faces for each vertex. Later
     will be used to compute the vertex normal: */
  int *number_of_adjacent_faces;
  union Wclass *new_class = _define_basic_object(number_of_vertices, vertices);
  if(new_class == NULL)
    return NULL;
  new_class -> shape.type = W_SHAPE;
  // Obtendo o número de índices:
  for(number_of_indices = 0; count < number_of_faces; number_of_indices ++){
    if(faces[number_of_indices] == W_FACE_BREAK)
      count ++;
  }
  new_class -> shape.number_of_indices = number_of_indices;
  // Alocando os índices:
  new_class -> shape.indices = (GLushort *) Walloc(sizeof(GLushort) *
						   number_of_indices);
  if(new_class -> shape.indices == NULL){
    _undefine_basic_object(new_class);
    return NULL;
  }
  // Alocando a contagem do número de faces adjacentes por vértice:
  number_of_adjacent_faces = (int *) Walloc(sizeof(int) * number_of_vertices+1);
  if(number_of_adjacent_faces == NULL){
    Wfree(new_class -> shape.indices);
    _undefine_basic_object(new_class);
    return NULL;
  }
  // inicializando a contagem de faces adjacentes:
  for(i = 0; i < number_of_vertices; i ++)
    number_of_adjacent_faces[i] = 0;
  // Inicializando os índices e a contagem de faces adjacentes:
  {
    /* A normal da face atual que percorremos ficará armazenada na
       variável abaixo. Usaremos a informação para calcular a normal
       de cada vértice para o cálculo de iluminação. */
    float normal[3];
    /* Começamos o cálculo do vetor normal à primeira face: */
    if(number_of_faces > 0){
      /* Passamos sempre três vértices consecutivos da face para o
	 cálculo do seu vetor normal. Podemos então assumir estarmos
	 calculando a normal de um triângulo: */
      _normal_vector_to_triangle(&normal[0], &vertices[faces[0] * 3],
				 &vertices[faces[1] * 3],
				 &vertices[faces[2] * 3]);
    }
    for(i = 0; i < number_of_indices; i ++){
      if(faces[i] == W_FACE_BREAK){
	new_class -> shape.indices[i] = (GLushort) 0;
	// Se existe uma próxima face, calculamos a sua normal:
	if(i + 1 < number_of_indices)
	  _normal_vector_to_triangle(&normal[0], &vertices[faces[i+1] * 3],
				     &vertices[faces[i + 2] * 3],
				     &vertices[faces[i + 3] * 3]);
      }
      else{
	new_class -> shape.indices[i] = (GLushort) faces[i] + 1;
	// Incrementamos a contagem de faces do vértice encontrado:
	number_of_adjacent_faces[faces[i]+1] ++;
	// Somamos a normal atual ao vetor associado ao vértice:
	new_class -> shape.vertices[(faces[i] + 1) * 6 + 3] += normal[0];
	new_class -> shape.vertices[(faces[i] + 1) * 6 + 4] += normal[1];
	new_class -> shape.vertices[(faces[i] + 1) * 6 + 5] += normal[2];
      }
    }
  }
  /* Agora uma iteração para percorrermos os vetores associados a cada
     vértice e dividirmos ele pelo número de faces que contém o
     vértice. Por fim, os normallizamos. E assim teremos terminado de
     calcular a normal de cada vértice:*/
  for(i = 0; i < number_of_vertices; i ++){
    new_class -> shape.vertices[(i + 1) * 6 + 3] /= number_of_adjacent_faces[i];
    new_class -> shape.vertices[(i + 1) * 6 + 4] /= number_of_adjacent_faces[i];
    new_class -> shape.vertices[(i + 1) * 6 + 5] /= number_of_adjacent_faces[i];
    _normalize(&new_class -> shape.vertices[(i + 1) * 6 + 3]);
  }
  // Agora podemos enviar os vértices para o servidor openGL:
  glBindVertexArray(new_class -> shape._vertex_object);
  glBindBuffer(GL_ARRAY_BUFFER, new_class -> shape._buffer_object);
  glBufferData(GL_ARRAY_BUFFER, sizeof(float) * 6 * (number_of_vertices + 1),
	       new_class -> shape.vertices, GL_STATIC_DRAW);

  // Inicializando a lista de índices no servidor OpenGL:
  glGenBuffers(1, &(new_class -> shape._element_object));
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, new_class -> shape._element_object);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER,
	       number_of_indices * sizeof(GLushort),
	       new_class -> shape.indices, GL_STATIC_DRAW);
  // Limpeza:
  Wfree(number_of_adjacent_faces);
  return new_class;
}
@

As funções auxiliares para calcular a normal de um triângulo e
normalizar um vetor serão apresentadas só ao fim deste capítulo.

Remover a definição de forma geométrica também é como remover a
definição de um objeto básico. Novamente, só temos antes que desalocar
os índices de cada vértice:

@<Wobject: Declaração@>=
void undefine_shape(union Wclass *wclass);
@

@<Wobject: Definição@>=
void _undefine_shape(union Wclass *wclass){
  Wfree(wclass -> shape.indices);
  _undefine_basic_object(wclass);
}
@

Da mesma forma, para que não seja estritamente necessário remover
definições de classes, ao término do programa nós desalocamos as
formas básicas que encontramos ainda definidas:

@<Desalocação Automática de Classes@>=
if(_wclasses[i].basic.type == W_SHAPE){
  Wfree(_wclasses[i].shape.indices);
  Wfree(_wclasses[i].shape.vertices);
  _wclasses[i].basic.type = W_NONE;
  continue;
}
@

Por fim, criar e remover instâncias de formas geométricas é trivial,
pois tais instâncias são idênticas à instâncias de objetos básicos:

@<Wobject: Declaração@>=
union Wobject *new_shape(union Wclass *wclass);
#define destroy_shape(wobj) _destroy_basic_object(wobj);
@

@<Wobject: Definição@>=
union Wobject *new_shape(union Wclass *wclass){
  union Wobject *new_obj = _new_basic_object(wclass);
  new_obj -> basic.type = W_SHAPE;
  return new_obj;
}
@

@*1 Desenhando Formas no Loop Principal.

As formas poderão ser desenhadas quando estivermos em cada iteração do
loop principal. Para isso, basta que elas sejam visíveis. Nós
precisamos informar o servidor OpenGL do vetor de índices que
especifica a ordem de cada vértice no desenho. Fora isso, o
procedimento é idêntico ao de objetos básicos:

@<Desenho de Objetos no Loop Principal@>=
case W_SHAPE:
  for(j = 0; j < W_MAX_INSTANCES; j ++){
    if(_wclasses[i].shape.instances[j].basic.type == W_NONE)
      continue;
    @<Transformação Linear de Objeto (i, j)@>@/
    glVertexAttribPointer(_shader_vPosition, 3, GL_FLOAT, GL_FALSE,
			  6 * sizeof(float), (void *) 0);
    glVertexAttribPointer(_shader_VertexNormal, 3, GL_FLOAT, GL_FALSE,
			  6 * sizeof(float), (void *) (sizeof(float) * 3));
    glEnableVertexAttribArray(_shader_vPosition);
    glEnableVertexAttribArray(_shader_VertexNormal);
    glBindVertexArray(_wclasses[i].shape._vertex_object);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _wclasses[i].shape._element_object);
    glDrawElements(GL_TRIANGLE_FAN, _wclasses[i].shape.number_of_indices,
		   GL_UNSIGNED_SHORT, NULL);
  }
continue;
@

@*1 Funções Auxiliares.

@*2 Calcular o Vetor Normal à um Triângulo.

Um triângulo é definido por três pontos $A$, $B$ e $C$. Definiremos
uma função que recebe como argumento quatro vetores de três pontos
flutuantes. O primeiro vetor armazenará a resposta. Os próximos três
irão conter a coordenada de cada um dos pontos do triângulo:

@<Funções Auxiliares: Declaração@>+=
void _normal_vector_to_triangle(float *answer, float *A, float *B, float *C);
@
@<Funções Auxiliares: Definição@>+=
void _normal_vector_to_triangle(float *answer, float *A, float *B, float *C){
  @<Cálculo do Vetor Normal ao Triângulo@>@/
}
@

Nosso primeiro objetivo é obter dois vetores $U$ e $V$. Estes vetores
são obtidos pegando dois lados do triângulo, colocando uma ponta na
origem e obtendo o valor do vetor cuja posição corresponde à outra
ponta do lado do triângulo. Os lados do triângulo precisam ser
distintos:

@<Cálculo do Vetor Normal ao Triângulo@>=
  float U[3], V[3];
{
  int i;
  for(i = 0; i < 3; i ++){
    V[i] = B[i] - A[i];
    U[i] = C[i] - B[i];
  }  
}
@

Tendo obtido os vetores $U$ e $V$, podemos agora calcular o seu
produto vetorial usando o ``Método de Sarrus'':

@<Cálculo do Vetor Normal ao Triângulo@>+=
{
  answer[0] = U[1] * V[2] - U[2] * V[1];
  answer[1] = U[2] * V[0] - U[0] * V[2];
  answer[2] = U[0] * V[1] - U[1] * V[0];
}
@

O resultado deste produto vetorial é o vetor normal que queríamos.

@*2 Normalizar um Vetor.

A função de normalizar um vetor deve receber como argumento um vetor
de três posições. Ela irá modificá-lo para deixá-lo normalizado:

@<Funções Auxiliares: Declaração@>+=
void  _normalize(float *V);
@

Normalizar um vetor é simplesmente obter sua magnitude e dividir por
ela cada um de seus elementos:

@<Funções Auxiliares: Definição@>+=
void  _normalize(float *V){
  int i;
  float magnitude = sqrtf(V[0] * V[0] + V[1] * V[1] + V[2] * V[2]);
  for(i = 0; i < 3; i ++)
    V[0] /= magnitude;
}
@

