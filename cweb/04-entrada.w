@* Teclado e Mouse.

Uma vez que tenhamos uma janela, podemos começar a acompanhar os
eventos associados à ela. Um usuário pode apertar qualquer botão no
seu teclado ou mouse e isso gerará um evento. Devemos tratar tais
eventos no mesmo local em que já estamos tratando coisas como o mover
e o mudar tamanho da janela (algo que também é um evento). Mas devemos
criar uma interface mais simples para que um usuário possa acompanhar
quando certas teclas são pressionadas, quando são soltas, por quanto
tempo elas estão sendo pressionadas e por quanto tempo foram
pressionadas antes de terem sido soltas.

Nossa proposta é que exista um vetor de inteiros chamado |W.keyboard|,
por exemplo, e que cada posição dele represente uma tecla
diferente. Se o valor dentro de uma posição do vetor é 0, então tal
tecla não está sendo pressionada. Caso o seu valor seja um número
positivo, então a tecla está sendo pressionada e o número representa
por quantos milissegundos a tecla vem sendo pressionada. Caso o valor
seja um número negativo, significa que a tecla acabou de ser solta e o
inverso deste número representa por quantos milissegundos a tecla
ficou pressionada. E caso o valor seja 1, isso significa que a tecla
começou a ser pressionada exatamente neste \italico{frame}.

Acompanhar o tempo no qual uma tecla é pressionada é tão importante
quanto saber se ela está sendo pressionada ou não. Por meio do tempo,
podemos ser capazes de programar personagens que pulam mais alto ou
mais baixo, dependendo do quanto um jogador apertou uma tecla, ou
fazer com que jogadores possam escolher entre dar um soco rápido e
fraco ou lento e forte em outros tipos de jogo. Tudo depende da
intensidade com a qual eles pressionam os botões.

Entretanto, tanto o Xlib como SDL funcionam reportando apenas o
momento no qual uma tecla é pressionada e o momento na qual ela é
solta. Então, em cada iteração, precisamos memorizar quais teclas
estão sendo pressionadas. Se duas pessoas estiverem compartilhando um
mesmo teclado, teoricamente, o número máximo de teclas que podem ser
pressionadas é 20 (se cada dedo da mão de cada uma delas estiver sobre
uma tecla). Então, vamos usar um vetor de 20 posições para armazenar o
número de cada tecla sendo pressionada. Isso é apenas para podermos
atualizar em cada iteração do loop principal o tempo em que cada tecla
é pressionada. Se hipoteticamente mais de 20 teclas forem
pressionadas, o fato de perdermos uma delas não é algo muito grave e
não deve causar qualquer problema.

Até agora estamos falando do teclado, mas o mesmo pode ser
implementado nos botões do mouse. Mas no caso do mouse, além dos
botões, temos o seu movimento. Então será importante armazenarmos a
sua posição $(x, y)$, mas também um vetor representando a sua
velocidade. Tal vetor deve considerar como se a posição atual do
ponteiro do mouse fosse a $(0,0)$ e deve conter qual a sua posição no
próximo segundo caso o seu deslocamento continue constante na mesma
direção e sentido em que vem sendo desde a última iteração. Desta
forma, tal vetor também será útil para verificar se o mouse está em
movimento ou não. E saber a intensidade e direção do movimento do
mouse pode permitir interações mais ricas com o usuário.

@*1 Preparando o Loop Principal: Medindo a Passagem de Tempo.

Conforme exposto na introdução, toda vez que estivermos em um loop
principal do jogo, a função |Wrest| deve ser invocada uma vez a
cada iteração. Devemos então manter algumas variáveis controlando a
passagem do tempo, e tais variáveis devem ser atualizadas sempre
dentro destas funções.

No caso, vamos precisar inicialmente de uma variável para armazenar o
tempo da iteração atual e a da iteração anterior, em escala de
microssegundos:

@<API Weaver: Definições@>=
static struct timeval _last_time, _current_time;
@

É importante que ambos os valores sejam inicializados como zero, caso
contrário, valores estranhos podem ser derivados caso usemos os
valores antes de serem corretamente inicializados na primeira iteração
de um loop principal:

@<API Weaver: Inicialização@>+=
_last_time.tv_sec = 0;
_last_time.tv_sec = 0;
_current_time.tv_sec = 0;
_current_time.tv_usec = 0;
@

No loop principal em si, o valor que temos como o do tempo atual deve
ser passado para o tempo anterior, e em seguida deve ser sobrescrito
por um novo tempo atual:

@<API Weaver: Loop Principal@>+=
{
  _last_time.tv_sec = _current_time.tv_sec;
  _last_time.tv_usec = _current_time.tv_usec;
  gettimeofday(&_current_time, NULL);
}
@

Estas medidas de tempo serão realmente usadas para atualizar duas
variáveis a cada iteração. A primeira será uma variável interna e
armazenará quantos milissegundos se passaram entre uma iteração e
outra. Usaremos ela para gerar a variável global |W.fps| que poderá
ser consultada por usuários e conterá à quantos frames por segundo o
jogo está rodando:

@<API Weaver: Definições@>=
  static int _elapsed_milisseconds;
@

@<Variáveis Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
int fps;
@


Naturalmente, tais valores também precisam ser inicializados para
prevenir que contenham números absurdos na primeira iteração:

@<API Weaver: Inicialização@>+=
{
  _elapsed_milisseconds = 0;
  W.fps = 0;
}
@

E em cada iteração do loop principal, atualizamos os valores. Assim
subtraímos dois |struct timeval| para obter os valores de
|elapsed_milisseconds| e |W.fps| em cada \italico{frame}:

@<API Weaver: Loop Principal@>+=
{
  _elapsed_milisseconds = (_current_time.tv_sec - _last_time.tv_sec) * 1000;
  _elapsed_milisseconds += (_current_time.tv_usec - _last_time.tv_usec) / 1000;
  if(_elapsed_milisseconds > 0)
    W.fps = 1000 / _elapsed_milisseconds;
  else
    W.fps = 0;
}
@

@*1 O Teclado.

Para o teclado precisaremos de uma variável local que armazenará as
teclas que já estão sendo pressionadas e uma variável global que será
um vetor de números representando a quanto tempo cada tecla é
pressionada. Adicionalmente, também precisamos tomar nota das teclas
que acabaram de ser soltas para que na iteração seguinte possamos
zerar os seus valores no vetor de por quanto tempo estão pressionadas.

Mas a primeira questão que temos a responder é que tamanho deve ter
tal vetor? E como associar cada posição à uma tecla?

Um teclado típico tem entre 80 e 100 teclas diferentes. Entretanto,
diferentes teclados representam em cada uma destas teclas diferentes
símbolos e caracteres. Alguns teclados possuem ``Ç'', outros possuem o
símbolo do Euro, e outros podem possuir símbolos bem mais exóticos. Há
também teclas modificadoras que transformam determinadas teclas em
outras. O Xlib reconhece diferentes teclas associando à elas um número
chamado de \negrito{KeySym}, que são inteiros de 29 bits.

Entretanto, não podemos criar um vetor de $2^{29}$ números para
representar se uma das diferentes teclas possíveis está
pressionada. Se cada inteiro tiver 4 bytes, vamos precisar de 2GB de
memória para conter tal vetor. Por isso, precisamos nos ater à uma
quantidade menor de símbolos.

A vasta maioria das teclas possíveis é representada por números entre
0 e 0xffff. Isso inclui até mesmo caracteres em japonês, ``Ç'', todas
as teclas do tipo Shift, Esc, Caps Lock, Ctrl e o ``N'' com um til do
espanhol. Mas algumas coisas ficam de fora, como cirílico, símbolos
árabes, vietnamitas e símbolos matemáticos especiais. Contudo, isso
não será algo grave, pois podemos fornecer uma função capaz de
redefinir alguns destes símbolos para valores dentro de tal
intervalo. O que significa que vamos precisar também de espaço em
memória para armazenar tais traduções de uma tecla para outra. Um
número de 100 delas pode ser estabelecido como máximo, pois a maioria
dos teclados tem menos teclas que isso.

Note que este é um problema do XLib. O SDL de qualquer forma já se
atém somente à 16 bytes para representar suas teclas. Então, podemos
ignorar com segurança tais traduções quando estivermos programando
para a Web.

Sabendo disso, o nosso vetor de teclas |W.keyboard| e vetor de
traduções pode ser declarado, bem como o vetor de teclas
pressionadas. Além das teclas pressionadas do teclado, vamos dar o
mesmo tratamento para os botões pressionados no \italico{mouse}:

@<Variáveis Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
  int keyboard[0xffff];
@

@<API Weaver: Definições@>=
#if W_TARGET == W_ELF
  static struct _k_translate{ // Traduz uma tecla em outra
    unsigned original_symbol, new_symbol;
  } _key_translate[100];
#endif
// Lista de teclas do teclado que estão sendo pressionadas e que estão
// sendo soltas:
  static unsigned _pressed_keys[20];
  static unsigned _released_keys[20];
// List de botões do mouse que estão sendo pressionados e soltos:
  static unsigned _pressed_buttons[5];
  static unsigned _released_buttons[5];
@

@<Cabeçalhos Weaver@>+=
#ifdef W_MULTITHREAD
  pthread_mutex_t _input_mutex;
#endif

@

A inicialização de tais valores consiste em deixar todos contendo zero
como valor:

@<API Weaver: Inicialização@>+=
{
  int i;
  for(i = 0; i < 0xffff; i ++)
    W.keyboard[i] = 0;
#if W_TARGET == W_ELF
  for(i = 0; i < 100; i ++){
    _key_translate[i].original_symbol = 0;
    _key_translate[i].new_symbol = 0;
  }
#endif
  for(i = 0; i < 20; i ++){
    _pressed_keys[i] = 0;
    _released_keys[i] = 0;
  }
#ifdef W_MULTITHREAD
  if(pthread_mutex_init(&_input_mutex, NULL) != 0){ // Inicializa mutex
    perror(NULL);
    exit(1);
  } 
#endif
}
@

Assim como inicializamos valores, ao término do programa, podemos
precisar finalizá-los:

@<API Weaver: Finalização@>+=
#ifdef W_MULTITHREAD
  if(pthread_mutex_destroy(&_input_mutex) != 0){ // Finaliza mutex
    perror(NULL);
    exit(1);
} 
#endif
@

Inicializar a lista de teclas pressionadas com zero funciona porque
nem o SDL e nem o XLib associa qualquer tecla ao número zero. Então
podemos usá-lo para representar a ausência de qualquer tecla sendo. De
fato, o XLib ignora os primeiros 31 valores e o SDL ignora os
primeiros 7. Desta forma, podemos usar tais espaços com segurança para
representar conjuntos de teclas ao invés de uma tecla individual. Por
exemplo, podemos associar a posição 6 como sendo o de todas as
teclas. Qualquer tecla pressionada faz com que ativemos o seu
valor. Outra posição pode ser associada ao Shift, que faria com que
fosse ativada toda vez que o Shift esquerdo ou direito fosse
pressionado. O mesmo para o Ctrl e Alt. Já o valor zero deve continuar
sem uso para que possamos reservá-lo para valores inicializados, mas
vazios ou indefinidos. Os demais valores nos indicam que uma tecla
específica está sendo pressionada.

@<Cabeçalhos Weaver@>=
#define W_SHIFT 2 // Shift esquerdo ou direito
#define W_CTRL  3 // Ctrl esquerdo ou direito
#define W_ALT   4 // Alt esquerdo ou direito
#define W_ANY   6 // Qualquer botão
@

A função que nos permite traduzir uma tecla para outra consiste em
percorrer o vetor de traduções e verificar se temos uma tradução
registrada para o símbolo que estamos procurando:

@<API Weaver: Definições@>+=
#if W_TARGET == W_ELF
static unsigned _translate_key(unsigned symbol){
  int i;
  for(i = 0; i < 100; i ++){
    if(_key_translate[i].original_symbol == 0)
      return symbol % 0xffff; // Sem mais traduções. Nada encontrado.
    if(_key_translate[i].original_symbol == symbol)
      return _key_translate[i].new_symbol % 0xffff; // Retorna tradução
  }
#if W_DEBUG_LEVEL >= 2
  if(symbol >= 0xffff)
    fprintf(stderr, "WARNING (2): Key with unknown code pressed: %lu",
           (unsigned long) symbol);
#endif
  return symbol % 0xffff; // Vetor percorrido e nenhuma tradução encontrada
}
#endif
@

Agora respectivamente a tarefa de adicionar uma nova tradução de tecla
e a tarefa de limpar todas as traduções existentes. O que pode dar
errado aí é que pode não haver espaço para novas traduções quando
vamos adicionar mais uma. Neste caso, a função sinaliza isso
retornando 0 ao invés de 1.

@<Cabeçalhos Weaver@>=
int _Wkey_translate(unsigned old_value, unsigned new_value);
void _Werase_key_translations(void);
@


@<API Weaver: Definições@>=
int _Wkey_translate(unsigned old_value, unsigned new_value){
#if W_TARGET == W_ELF
  int i;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_input_mutex);
#endif
  for(i = 0; i < 100; i ++){
    if(_key_translate[i].original_symbol == 0 ||
       _key_translate[i].original_symbol == old_value){
      _key_translate[i].original_symbol = old_value;
      _key_translate[i].new_symbol = new_value;
#ifdef W_MULTITHREAD
      pthread_mutex_unlock(&_input_mutex);
#endif
      return 1;
    }
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_input_mutex);
#endif
#else
  // Isso previne aviso de que os argumentos da função não foram
  // usados se W_TARGET != W_ELF:
  old_value = new_value;
  new_value = old_value;
#endif
  return 0;
}

void _Werase_key_translations(void){
#if W_TARGET == W_ELF
  int i;
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_input_mutex);
#endif
  for(i = 0; i < 100; i ++){
    _key_translate[i].original_symbol = 0;
    _key_translate[i].new_symbol = 0;
  }
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_input_mutex);
#endif
#endif
}
@

Iremos atribuir tanto a função de adiconar nova tradução como a função
de remover todas as traduções à estrutura |W|:

@<Funções Weaver@>+=
int (*key_translate)(unsigned, unsigned);
void (*erase_key_translations)(void);
@

@<API Weaver: Inicialização@>=
W.key_translate = &_Wkey_translate;
W.erase_key_translations = &_Werase_key_translations;
@


Uma vez que tenhamos preparado as traduções, podemos enfim ir até o
loop principal e acompanhar o surgimento de eventos para saber quando
o usuário pressiona ou solta uma tecla. No caso de estarmos usando
XLib e uma tecla é pressionada, o código abaixo é executado. A coisa
mais críptica abaixo é o suo da função |XkbKeycodeToKeysym|. Mas
basicamente o que esta função faz é traduzir o valor da variável
|event.xkey.keycode| de uma representação inicial, que representa a
posição da tecla  em um teclado para o símbolo específico associado
àquela tecla, algo que muda em diferentes teclados.

@<API Weaver: Trata Evento Xlib@>=
if(event.type == KeyPress){
  unsigned int code =  _translate_key(XkbKeycodeToKeysym(_dpy,
                                                         event.xkey.keycode, 0,
                                                         0));
  int i;
  // Adiciona na lista de teclas pressionadas:
  for(i = 0; i < 20; i ++){
    if(_pressed_keys[i] == 0 || _pressed_keys[i] == code){
      _pressed_keys[i] = code;
      break;
    }
  }
  // Apesar de estarmos aqui, pode ser que esta tecla já estava sendo
  // pressionada antes. O evento de 'tecla pressionada' pode ser
  // gerado mais de uma vez se uma tecla for segurada por muito
  // tempo. Mas só podemos marcar a quantidade de tempo que ela é
  // pressionada como 1 se ela realmente começou a ser pressionada
  // agora. E caso contrário, também verificamos se o valor é
  // negativo. Se for, isso significa que a tecla foi solta e
  // pressionada ao mesmo tempo no mesmo frame. Esta seqüência de
  // eventos também pode ser gerada incorretamente se a tecla for
  // pressionada por muito tempo e precisamos corrigir se isso
  // ocorrer.
  if(W.keyboard[code] == 0)
    W.keyboard[code] = 1;
  else if(W.keyboard[code] < 0)
    W.keyboard[code] *= -1;
  continue;
}
@

Já se uma tecla é solta, precisamos removê-la da lista de teclas
pressionadas e adicioná-la na lista de teclas que acabaram de ser
soltas:

@<API Weaver: Trata Evento Xlib@>=
if(event.type == KeyRelease){
  unsigned int code =  _translate_key(XkbKeycodeToKeysym(_dpy,
                                                         event.xkey.keycode, 
                                                         0, 0));
  int i;
  // Remove da lista de teclas pressionadas
  for(i = 0; i < 20; i ++){
    if(_pressed_keys[i] == code){
      _pressed_keys[i] = 0;
      break;
    }
  }
  for(; i < 19; i ++){// Preenche o buraco que ficou na lista após a remoção
    _pressed_keys[i] = _pressed_keys[i + 1];
  }
  _pressed_keys[19] = 0;
  // Adiciona na lista de teclas soltas:
  for(i = 0; i < 20; i ++){
    if(_released_keys[i] == 0 || _released_keys[i] == code){
      _released_keys[i] = code;
      break;
    }
  }
  // Atualiza vetor de teclado
  W.keyboard[code] *= -1;
  continue;
}
@

O evento de pressionar uma tecla faz com que ela vá para a lista de
teclas pressionadas. O evento de soltar uma tecla remove ela desta
lista e faz ela ir para a lista de teclas soltas. Mas a
cada \italico{frame} temos que também limpar a lista de teclas que
foram soltas no \italico{frame} anterior. E incrementar os valores no
vetor que mede o tempo em que cada tecla está sendo pressionada para
cada tecla que está na lista de teclas pressionadas. Isso precisa ser
feito imediatamente antes de lermos os eventos pendentes. Somente
imediatamente antes de obtermos os eventos deste \italico{frame}
devemos terminar de processar todas as ocorrências do \italico{frame}
anterior. Caso contrário, ocorreriam valores errôneos e nunca
conseguiríamos manter em 1 o valor de tempo para uma tecla que acabou
de ser pressionada neste \italico{frame}.

@<API Weaver: Imediatamente antes de tratar eventos@>=
{
  int i, key;
  // Limpar o vetor de teclas soltas e zerar seus valores no vetor de teclado:
  for(i = 0; i < 20; i ++){
    key = _released_keys[i];
    // Se a tecla está com um valor positivo, isso significa que os
    //  eventos de soltar a tecla e apertar ela de novo foram gerados
    //  juntos. Isso geralmente acontece quando um usuário pressiona uma
    //  tecla por muito tempo. Depois de algum tempo, o servidor passa a
    //  interpretar isso como se o usuário estivesse apertando e
    //  soltando a tecla sem parar. Isso é útil em editores de texto
    //  quando você segura uma tecla e a letra que ela representa começa
    //  a ser inserida sem parar após um tempo. Mas aqui isso deixa o
    //  ato de medir o tempo cheio de detalhes incômodos. Temos que
    //  remover da lista de teclas soltas esta tecla, que provavelmente
    //  não foi solta de verdade:
    while(W.keyboard[key] > 0){
      int j;
      for(j = i; j < 19; j ++){
        _released_keys[j] = _released_keys[j+1];
      }
      _released_keys[19] = 0;
      key = _released_keys[i];
    }
    if(key == 0) break; // Chegamos ao fim da lista de teclas pressionadas
    // Tratando casos especiais de valores que representam mais de uma tecla:
    if(key == W_LEFT_CTRL || key == W_RIGHT_CTRL) W.keyboard[W_CTRL] = 0;
    else if(key == W_LEFT_SHIFT || key == W_RIGHT_SHIFT)
       W.keyboard[W_SHIFT] = 0;
    else if(key == W_LEFT_ALT || key == W_RIGHT_ALT) W.keyboard[W_ALT] = 0;
    // Como foi solta no frame anterior, o tempo que ela está pressionada é 0:
    W.keyboard[key] = 0;
    _released_keys[i] = 0; // Tecla removida da lista de teclas soltas
  }
  // Para teclas pressionadas, incrementar o seu contador de tempo:
  for(i = 0; i < 20; i ++){
    key = _pressed_keys[i];
    if(key == 0) break; // Fim da lista, encerrar
    // Casos especiais:
    if(key == W_LEFT_CTRL || key == W_RIGHT_CTRL) 
      W.keyboard[W_CTRL] += _elapsed_milisseconds;
    else if(key == W_LEFT_SHIFT || key == W_RIGHT_SHIFT)
      W.keyboard[W_SHIFT] += _elapsed_milisseconds;
    else if(key == W_LEFT_ALT || key == W_RIGHT_ALT)
      W.keyboard[W_ALT] += _elapsed_milisseconds;
    // Aumenta o contador de tempo:
    W.keyboard[key] += _elapsed_milisseconds;
  }
}
@

Por fim, preenchemos a posição |W.keyboard[W_ANY]| depois de tratarmos
todos os eventos:

@<API Weaver: Loop Principal@>+=
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_input_mutex);
#endif
W.keyboard[W_ANY] = (_pressed_keys[0] != 0); // Se há alguma tecla pressionada
@

Isso conclui o código que precisamos para o teclado no Xlib. Mas ainda
não acabou. Precisamos de macros para representar as diferentes teclas
de modo que um usuário possa consultar se uma tecla está pressionada
sem saber o código da tecla no Xlib:

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_ELF
#define W_UP          XK_Up
#define W_RIGHT       XK_Right
#define W_DOWN        XK_Down
#define W_LEFT        XK_Left
#define W_PLUS        XK_KP_Add
#define W_MINUS       XK_KP_Subtract
#define W_ESC         XK_Escape
#define W_A           XK_a
#define W_S           XK_s
#define W_D           XK_d
#define W_W           XK_w
#define W_ENTER       XK_Return
#define W_SPACEBAR    XK_space
#define W_LEFT_CTRL   XK_Control_L
#define W_RIGHT_CTRL  XK_Control_R
#define W_F1          XK_F1
#define W_F2          XK_F2
#define W_F3          XK_F3
#define W_F4          XK_F4
#define W_F5          XK_F5
#define W_F6          XK_F6
#define W_F7          XK_F7
#define W_F8          XK_F8
#define W_F9          XK_F9
#define W_F10         XK_F10
#define W_F11         XK_F11
#define W_F12         XK_F12
#define W_BACKSPACE   XK_BackSpace
#define W_TAB         XK_Tab
#define W_PAUSE       XK_Pause
#define W_DELETE      XK_Delete
#define W_SCROLL_LOCK XK_Scroll_Lock
#define W_HOME        XK_Home
#define W_PAGE_UP     XK_Page_Up
#define W_PAGE_DOWN   XK_Page_Down
#define W_END         XK_End
#define W_INSERT      XK_Insert
#define W_NUM_LOCK    XK_Num_Lock
#define W_ZERO        XK_KP_0
#define W_ONE         XK_KP_1
#define W_TWO         XK_KP_2
#define W_THREE       XK_KP_3
#define W_FOUR        XK_KP_4
#define W_FIVE        XK_KP_5
#define W_SIX         XK_KP_6
#define W_SEVEN       XK_KP_7
#define W_EIGHT       XK_KP_8
#define W_NINE        XK_KP_9
#define W_LEFT_SHIFT  XK_Shift_L
#define W_RIGHT_SHIFT XK_Shift_R
#define W_CAPS_LOCK   XK_Caps_Lock
#define W_LEFT_ALT    XK_Alt_L
#define W_RIGHT_ALT   XK_Alt_R
#define W_Q           XK_q
#define W_E           XK_e
#define W_R           XK_r
#define W_T           XK_t
#define W_Y           XK_y
#define W_U           XK_u
#define W_I           XK_i
#define W_O           XK_o
#define W_P           XK_p
#define W_F           XK_f
#define W_G           XK_g
#define W_H           XK_h
#define W_J           XK_j
#define W_K           XK_k
#define W_L           XK_l
#define W_Z           XK_z
#define W_X           XK_x
#define W_C           XK_c
#define W_V           XK_v
#define W_B           XK_b
#define W_N           XK_n
#define W_M           XK_m
#endif
@

A última coisa que resta para termos uma API funcional para lidar com
teclados é uma função para limpar o vetor de teclados e a lista de
teclas soltas e pressionadas. Desta forma, podemos nos livrar de
teclas pendentes quando saímos de um loop principal para outro, além
de termos uma forma de fazer com que o programa possa descartar teclas
pressionadas em momentos dos quais não era interessante levá-las em
conta.

Mas não vamos querer fazer isso só com o teclado, mas com todas as
formas de entrada possíveis. Portanto, vamos deixar este trecho de
código com uma marcação para inserirmos mais coisas depois:

@<Cabeçalhos Weaver@>+=
void _Wflush_input(void);
@

@<API Weaver: Definições@>+=
void _Wflush_input(void){
#ifdef W_MULTITHREAD
    pthread_mutex_lock(&_input_mutex);
#endif
  {
 // Limpa informação do teclado
    int i, key;
    for(i = 0; i < 20; i ++){
      key = _pressed_keys[i];
      _pressed_keys[i] = 0;
      W.keyboard[key] = 0;
      key = _released_keys[i];
      _released_keys[i] = 0;
      W.keyboard[key] = 0;
    }
  }
  @<Limpar Entrada@>
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_input_mutex);
#endif
}
@

E para usar esta função, a adicionamos à estrutura |W|:

@<Funções Weaver@>+=
void (*flush_input)(void);
@

@<API Weaver: Inicialização@>=
W.flush_input = &_Wflush_input;
@

E esta é uma função importante de ser chamada antes de cada loop
principal:

@<Código Imediatamente antes de Loop Principal@>=
W.flush_input();
@

Quase tudo o que foi definido aqui aplica-se tanto para o Xlib rodando
em um programa nativo para Linux como em um programa SDL compilado
para a Web. A única exceção é o tratamento de eventos, que é feita
usando funções diferentes nas duas bibliotecas.

Para um programa compilado para a Web, precisamos inserir o cabeçalho
SDL:

@<Cabeçalhos Weaver@>+=
#if W_TARGET == W_WEB
#include <SDL/SDL.h>
#endif
@

E tratamos o evento de uma tecla ser pressionada exatamente da mesma
forma, mas respeitando as diferenças das bibliotecas em como acessar
cada informação:

@<API Weaver: Trata Evento SDL@>=
if(event.type == SDL_KEYDOWN){
  unsigned int code =  event.key.keysym.sym;
  int i;
  // Adiciona na lista de teclas pressionadas
  for(i = 0; i < 20; i ++){
    if(_pressed_keys[i] == 0 || _pressed_keys[i] == code){
      _pressed_keys[i] = code;
      break;
    }
  }
    // Atualiza vetor de teclado se a tecla não estava sendo
    // pressionada. Algumas vezes este evento é gerado repetidas vezes
    // quando apertamos uma tecla por muito tempo. Então só devemos
    // atribuir 1 à posição do vetor se realmente a tecla não estava
    // sendo pressionada antes.
  if(W.keyboard[code] == 0)
    W.keyboard[code] = 1;
  else if(W.keyboard[code] < 0)
    W.keyboard[code] *= -1;
  continue;
}
@

Por fim, o evento da tecla sendo solta:

@<API Weaver: Trata Evento SDL@>=
if(event.type == SDL_KEYUP){
  unsigned int code =  event.key.keysym.sym;
  int i;
  // Remove da lista de teclas pressionadas
  for(i = 0; i < 20; i ++){
    if(_pressed_keys[i] == code){
      _pressed_keys[i] = 0;
      break;
    }
  }
  for(; i < 19; i ++){
    _pressed_keys[i] = _pressed_keys[i + 1];
  }
  _pressed_keys[19] = 0;
  // Adiciona na lista de teclas soltas:
  for(i = 0; i < 20; i ++){
    if(_released_keys[i] == 0 || _released_keys[i] == code){
      _released_keys[i] = code;
      break;
    }
  }
  // Atualiza vetor de teclado
  W.keyboard[code] *= -1;
  continue;
}

@

E por fim, a posição das teclas para quando usamos SDL no vetor de
teclado será diferente e correspondente aos valores usados pelo SDL:

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_WEB
#define W_UP          SDLK_UP
#define W_RIGHT       SDLK_RIGHT
#define W_DOWN        SDLK_DOWN
#define W_LEFT        SDLK_LEFT
#define W_PLUS        SDLK_PLUS
#define W_MINUS       SDLK_MINUS
#define W_ESC         SDLK_ESCAPE
#define W_A           SDLK_a
#define W_S           SDLK_s
#define W_D           SDLK_d
#define W_W           SDLK_w
#define W_ENTER       SDLK_RETURN
#define W_SPACEBAR    SDLK_SPACE
#define W_LEFT_CTRL   SDLK_LCTRL
#define W_RIGHT_CTRL  SDLK_RCTRL
#define W_F1          SDLK_F1
#define W_F2          SDLK_F2
#define W_F3          SDLK_F3
#define W_F4          SDLK_F4
#define W_F5          SDLK_F5
#define W_F6          SDLK_F6
#define W_F7          SDLK_F7
#define W_F8          SDLK_F8
#define W_F9          SDLK_F9
#define W_F10         SDLK_F10
#define W_F11         SDLK_F11
#define W_F12         SDLK_F12
#define W_BACKSPACE   SDLK_BACKSPACE
#define W_TAB         SDLK_TAB
#define W_PAUSE       SDLK_PAUSE
#define W_DELETE      SDLK_DELETE
#define W_SCROLL_LOCK SDLK_SCROLLOCK
#define W_HOME        SDLK_HOME
#define W_PAGE_UP     SDLK_PAGEUP
#define W_PAGE_DOWN   SDLK_PAGEDOWN
#define W_END         SDLK_END
#define W_INSERT      SDLK_INSERT
#define W_NUM_LOCK    SDLK_NUMLOCK
#define W_ZERO        SDLK_0
#define W_ONE         SDLK_1
#define W_TWO         SDLK_2
#define W_THREE       SDLK_3
#define W_FOUR        SDLK_4
#define W_FIVE        SDLK_5
#define W_SIX         SDLK_6
#define W_SEVEN       SDLK_7
#define W_EIGHT       SDLK_8
#define W_NINE        SDLK_9
#define W_LEFT_SHIFT  SDLK_LSHIFT
#define W_RIGHT_SHIFT SDLK_RSHIFT
#define W_CAPS_LOCK   SDLK_CAPSLOCK
#define W_LEFT_ALT    SDLK_LALT
#define W_RIGHT_ALT   SDLK_RALT
#define W_Q           SDLK_q
#define W_E           SDLK_e
#define W_R           SDLK_r
#define W_T           SDLK_t
#define W_Y           SDLK_y
#define W_U           SDLK_u
#define W_I           SDLK_i
#define W_O           SDLK_o
#define W_P           SDLK_p
#define W_F           SDLK_f
#define W_G           SDLK_g
#define W_H           SDLK_h
#define W_J           SDLK_j
#define W_K           SDLK_k
#define W_L           SDLK_l
#define W_Z           SDLK_z
#define W_X           SDLK_x
#define W_C           SDLK_c
#define W_V           SDLK_v
#define W_B           SDLK_b
#define W_N           SDLK_n
#define W_M           SDLK_m
#endif
@

@*1 Invocando o loop principal.

Um jogo pode ter vários loops principais. Um para a animação de
abertura. Outro para a tela de título onde escolhe-se o modo do
jogo. Um para cada fase ou cenário que pode-se visitar. Pode haver
outro para cada ``fase especial'' ou mesmo para cada batalha em um
jogo de RPG.

Em cada um dos loops principais, precisamos rodar possivelmente
milhares de iterações. E em cada uma delas precisamos fazer algumas
coisas em comum. Imediatamente antes do loop precisamos limpar todos
os valores prévios armazenados no vetor de teclado. E depois em cada
iteração precisamos rodar |Wrest| para obtermos os eventos de
entrada, atualizarmos várias variáveis e poder desenhar na tela.


No caso do nosso ambiente de execução ser o de um programa Linux
normal, a definição da função é:


Já se estamos no ambiente de execução de um navegador de Internet,
temos preocupações adicionais. Precisamos registrar uma função como um
loop principal. Mas se já existe um loop principal anteriormente
registrado, precisamos cancelar ele primeiro. 

@<Cabeçalhos Weaver@>+=
#if W_TARGET == W_WEB
#include <emscripten.h>
#endif
@

@<API Weaver: Definições@>+=
#if W_TARGET == W_WEB
void Wloop(void (*f)(void)){
  emscripten_cancel_main_loop();
  W.flush_input();
  _loop_begin = 0;
  @<Código Imediatamente antes de Loop Principal@>
  // O segundo argumento é o número de frames por segundo (deixamos a
  // cargo do navegador):
  emscripten_set_main_loop(f, 0, 1);
  // Nunca chegamos nesta parte. Inútil colocar qualquer coisa após
  // 'emscripten_set_main_loop'.
}
#endif
@

A função |Wloop| é uma das poucas que não serão colocadas dentro da
estrutura |W|. Não é do nosso interesse que ela seja invocada
por \italico{plugins}, somente pelo programa principal. Não havendo
necessidade de descobrirmos seu endereço, não temos motivos para
colocá-la dentro da estrutura. Além do mais, o fato dela ser invocada
como |Wloop| e não como |W.loop| ajuda a lembrar do caráter
excepcional da função.

Tudo isso significa que um loop principal nunca chega ao fim. Podemos
apenas invocar outro loop principal recursivamente dentro do
atual. Não há como evitar esta limitação com a atual API Emscripten
que precisa usar |emscripten_set_main_loop| para ativar o loop sem
interferir na usabilidade do navegador de Internet. Isso também traz a
limitação de que o \italico{loop} principal seja uma função que não
retorna nada e nem recebe argumentos.

A única possibilidade de evitar isso seria se fosse possível usar
clausuras (\italico{closures}). Neste caso, poderíamos definir |Wloop|
como uma macro que expandiria para a definição de uma clausura que
poderia ter acesso à todas as variáveis da função atual ao mesmo tempo
em que ela poderia ser passada para a função de invocaçã do loop. O
único compilador compatível com Emscripten é o Clang, que até
implementa clausuras por meio de uma extensão não-portável chamada de
``blocos''. O problema é que um bloco não é intercambiável e nem pode
ser convertido para uma função. Então não seria possível passá-lo para
a atual função da API Emscripten que espera uma função. O GCC suporta
clausuras na forma de funções aninhadas por meio de extensão
não-portável, mas o GCC não é compatível com Emscripten. Então
simplesmente não temos como evitar este efeito colateral.

@*1 Ajustando o Mutex de entrada.

Durante o tratamento de eventos em cada loop principal estaremos
consultando e modificando continuamente variáveis e estruturas
relacionadas à entrada. O vetor de teclas pressionadas, por
exemplo. Por causa disso, se necessário iremos bloquear um mutex
durante todo o tratamento:

@<API Weaver: Imediatamente antes de tratar eventos@>+=
#ifdef W_MULTITHREAD
  pthread_mutex_lock(&_input_mutex);
#endif
@

@*1 O Mouse.

Um mouse do nosso ponto de vista é como se fosse um teclado, mas com
menos teclas. O Xlib reconhece que mouses podem ter até 5 botões
(|Button1|, |Button2|, |Button3|, |Button4| e |Button5|). O SDL,
tentando manter portabilidade, em sua versão 1.2 reconhece 3 botões
(|SDL_BUTTON_LEFT|, |SDL_BUTTON_MIDDLE|,
|SDL_BUTTON_RIGHT|). Convenientemente, ambas as bibliotecas numeram
cada um dos botões sequencialmente à partir do número 1. Nós iremos
suportar 5 botões, mas um jogo deve assumir que apenas dois botões são
realmente garantidos: o botão direito e esquerdo.

Além dos botões, um mouse possui também uma posição $(x, y)$ na janela
em que o jogo está. Mas às vezes mais importante do que sabermos a
posição é sabermos a sua velocidade ou mesmo a sua aceleração.  A
velocidade será representada nas variáveis $(dx, dy)$. Elas são o
componente horizontal e vertical do vetor velocidade
do \italico{mouse} medido em pixels por segundo. Da mesma forma, a
aceleração será armazenada nos componentes $(ddx, ddy)$.

Em suma, podemos representar o mouse como a seguinte estrutura:

@<Cabeçalhos Weaver@>=
struct _mouse{
  /* Posições de 1 a 5 representarão cada um dos botões e o 6 é
     reservado para qualquer tecla.*/
  int buttons[7];
  int x, y, dx, dy, ddx, ddy;
};
@

@<Variáveis Weaver@>=
// Esta declaração fica dentro de "struct _weaver_struct{(...)} W;"
  struct _mouse mouse;
@


E a tradução dos botões, dependendo do ambiente de execução será dada
por:

@<Cabeçalhos Weaver@>=
#if W_TARGET == W_ELF
#define W_MOUSE_LEFT   Button1
#define W_MOUSE_MIDDLE Button2
#define W_MOUSE_RIGHT  Button3
#define W_MOUSE_B1     Button4
#define W_MOUSE_B2     Button5
#endif
#if W_TARGET == W_WEB
#define W_MOUSE_LEFT   SDL_BUTTON_LEFT
#define W_MOUSE_MIDDLE SDL_BUTTON_MIDDLE
#define W_MOUSE_RIGHT  SDL_BUTTON_RIGHT
#define W_MOUSE_B1     4
#define W_MOUSE_B2     5
#endif
@


Agora podemos inicializar os vetores de botões soltos e pressionados:

@<API Weaver: Inicialização@>+=
{ // Inicialização das estruturas do mouse
  int i;
  for(i = 0; i < 5; i ++)
    W.mouse.buttons[i] = 0;
  for(i = 0; i < 5; i ++){
    _pressed_buttons[i] = 0;
    _released_buttons[i] = 0;
  }
}
@

Imediatamente antes de tratarmos eventos, precisamos percorrer a lista
de botões pressionados para atualizar seus valores e a lista de botões
recém-soltos para removê-los da lista. É essencialmente o mesmo
trabalho que fazemos com o teclado.

@<API Weaver: Imediatamente antes de tratar eventos@>=
{
  int i, button;
  // Limpar o vetor de botõoes soltos e zerar seus valores no vetor de mouse:
  for(i = 0; i < 5; i ++){
    button = _released_buttons[i];
    while(W.mouse.buttons[button] > 0){
      int j;
      for(j = i; j < 4; j ++){
        _released_buttons[j] = _released_buttons[j+1];
      }
      _released_buttons[4] = 0;
      button = _released_buttons[i];
    }    
    if(button == 0) break;
#if W_TARGET == W_ELF
    // Se recebemos um clique com o botão esquerdo, devemos garantir que
    // a janela em que estamos receba o foco
    if(button == W_MOUSE_LEFT)
      XSetInputFocus(_dpy, _window, RevertToParent, CurrentTime);
#endif
    W.mouse.buttons[button] = 0;
    _released_buttons[i] = 0;
  }
  // Para botões pressionados, incrementar o tempo em que estão pressionados:
  for(i = 0; i < 5; i ++){
    button = _pressed_buttons[i];
    if(button == 0) break;
    W.mouse.buttons[button] += _elapsed_milisseconds;
  }
}
@

Tendo esta estrutura pronta, iremos então tratar a chegada de eventos
de botões do mouse sendo pressionados caso estejamos em um ambiente de
execução baseado em Xlib:

@<API Weaver: Trata Evento Xlib@>=
if(event.type == ButtonPress){
  unsigned int code =  event.xbutton.button;
  int i;
  // Adiciona na lista de botões pressionados:
  for(i = 0; i < 5; i ++){
    if(_pressed_buttons[i] == 0 || _pressed_buttons[i] == code){
      _pressed_buttons[i] = code;
      break;
    }
  }
    // Atualiza vetor de mouse se a tecla não estava sendo
    // pressionada. Ignoramos se o evento está sendo gerado mais de uma
    // vez sem que o botão seja solto ou caso o evento seja gerado
    // imediatamente depois de um evento de soltar o mesmo botão:
  if(W.mouse.buttons[code] == 0)
    W.mouse.buttons[code] = 1;
  else if(W.mouse.buttons[code] < 0)
    W.mouse.buttons[code] *= -1;
  continue;
}
@

E caso um botão seja solto, também tratamos tal evento:

@<API Weaver: Trata Evento Xlib@>=
if(event.type == ButtonRelease){
  unsigned int code = event.xbutton.button;
  int i;
  // Remove da lista de botões pressionados
  for(i = 0; i < 5; i ++){
    if(_pressed_buttons[i] == code){
      _pressed_buttons[i] = 0;
      break;
    }
  }
  for(; i < 4; i ++){
    _pressed_buttons[i] = _pressed_buttons[i + 1];
  }
  _pressed_buttons[4] = 0;
  // Adiciona na lista de botões soltos:
  for(i = 0; i < 5; i ++){
    if(_released_buttons[i] == 0 || _released_buttons[i] == code){
      _released_buttons[i] = code;
      break;
    }
  }
  // Atualiza vetor de mouse
  W.mouse.buttons[code] *= -1;
  continue;
}
@

No ambiente de execução com SDL também precisamos checar quando um
botão é pressionado:

@<API Weaver: Trata Evento SDL@>=
if(event.type == SDL_MOUSEBUTTONDOWN){
  unsigned int code =  event.button.button;
  int i;
  // Adiciona na lista de botões pressionados
  for(i = 0; i < 5; i ++){
    if(_pressed_buttons[i] == 0 || _pressed_buttons[i] == code){
      _pressed_buttons[i] = code;
      break;
    }
  }
  // Atualiza vetor de mouse se o botão já não estava sendo pressionado
  // antes.
  if(W.mouse.buttons[code] == 0)
    W.mouse.buttons[code] = 1;
  else if(W.mouse.buttons[code] < 0)
    W.mouse.buttons[code] *= -1;
  continue;
}
@

E quando um botão é solto:

@<API Weaver: Trata Evento SDL@>=
if(event.type == SDL_MOUSEBUTTONUP){
  unsigned int code =  event.button.button;
  int i;
  // Remove da lista de botões pressionados
  for(i = 0; i < 5; i ++){
    if(_pressed_buttons[i] == code){
      _pressed_buttons[i] = 0;
      break;
    }
  }
  for(; i < 4; i ++){
    _pressed_buttons[i] = _pressed_buttons[i + 1];
  }
  _pressed_buttons[4] = 0;
  // Adiciona na lista de botões soltos:
  for(i = 0; i < 5; i ++){
    if(_released_buttons[i] == 0 || _released_buttons[i] == code){
      _released_buttons[i] = code;
      break;
    }
  }
  // Atualiza vetor de teclado
  W.mouse.buttons[code] *= -1;
  continue;
}
@

E finalmente, o caso especial para verificar se qualquer botão foi
pressionado:

@<API Weaver: Loop Principal@>+=
W.mouse.buttons[W_ANY] = (_pressed_buttons[0] != 0);
#ifdef W_MULTITHREAD
  pthread_mutex_unlock(&_input_mutex);
#endif
@

@*2 Obtendo o movimento.

Agora iremos calcular o movimento do mouse. Primeiramente, no início
do programa devemos zerar tais valores para evitarmos valores absurdos
na primeira iteração. Os únicos valores que não são zerados é o da
posição do cursor, que precisamos descobrir para não parecer no início
do primeiro movimento do cursor que ele se teletransportou.

@<API Weaver: Inicialização@>+=
#if W_TARGET == W_ELF
{
  Window root_return, child_return;
  int root_x_return, root_y_return, win_x_return, win_y_return;
  unsigned mask_return;
  XQueryPointer(_dpy, _window, &root_return, &child_return, &root_x_return,
		&root_y_return, &win_x_return, &win_y_return, &mask_return);
  // A função acima falha apenas se o mouse estiver em outra
  // tela. Neste caso, não há o que fazer, mas adotar o padrão de
  // assumir que a posição é zero é razoável. Então não precisamos
  // checar se a função falha.
  W.mouse.x = root_x_return;
  W.mouse.y = root_y_return;
}
#endif
#if W_TARGET == W_WEB
  SDL_GetMouseState(&(W.mouse.x), &(W.mouse.y));
#endif
W.mouse.ddx = W.mouse.ddy = W.mouse.dx = W.mouse.dy = 0;
@


É importante que no início de cada iteração, antes de tratarmos os
eventos, nós zeremos os valores $(dx, dy)$ do mouse. Caso o mouse não
receba nenhum evento de movimento, tais valores já estarão
corretos. Caso contrário, atualizaremos eles. Mas isso também
significa que temos que guardar os valores antigos em variáveis para
que possamos calcular a aceleração depois do tratamento de eventos:

@<API Weaver: Definições@>+=
static int old_dx, old_dy;
@

@<API Weaver: Inicialização@>+=
  old_dx = old_dy = 0;
@

@<API Weaver: Imediatamente antes de tratar eventos@>+=
  old_dx = W.mouse.dx;
  old_dy = W.mouse.dy;
  W.mouse.dx = W.mouse.dy = 0;
@

@<API Weaver: Imediatamente após tratar eventos@>=
  // Cálculo de aceleração:
  W.mouse.ddx = (int) ((float) (W.mouse.dx - old_dx) / _elapsed_milisseconds) *
                1000;
  W.mouse.ddy = (int) ((float) (W.mouse.dy - old_dy) / _elapsed_milisseconds) *
                1000;
#ifdef W_MULTITHREAD
  // Mutex bloqueado antes de tratar eventos:
  pthread_mutex_unlock(&_input_mutex);
#endif
@

Notar que o código acima não é exclusivo do Xlib e funcionará da mesma
forma ao usar Emscripten.

Em seguida, cuidamos do caso no qual temos um evento Xlib de movimento
do mouse:

@<API Weaver: Trata Evento Xlib@>+=
if(event.type == MotionNotify){
  int x, y, dx, dy;
  x = event.xmotion.x;
  y = event.xmotion.y;
  dx = x - W.mouse.x;
  dy = y - W.mouse.y;
  W.mouse.dx = ((float) dx / _elapsed_milisseconds) * 1000;
  W.mouse.dy = ((float) dy / _elapsed_milisseconds) * 1000;
  W.mouse.x = x;
  W.mouse.y = y;
  continue;
}
@

Agora é só usarmos a mesma lógica para tratarmos o evento SDL:

@<API Weaver: Trata Evento SDL@>+=
if(event.type == SDL_MOUSEMOTION){
  int x, y, dx, dy;
  x = event.motion.x;
  y = event.motion.y;
  dx = x - W.mouse.x;
  dy = y - W.mouse.y;
  W.mouse.dx = ((float) dx / _elapsed_milisseconds) * 1000;
  W.mouse.dy = ((float) dy / _elapsed_milisseconds) * 1000;
  W.mouse.x = x;
  W.mouse.y = y;
  continue;
}
@

E a última coisa que precisamos fazer é zerar e limpar todos os
vetores de botões e variáveis de movimento toda vez que for
requisitado limpar todos os buffers de entrada. Como ocorre antes de
entrarmos em um loop principal:

@<Limpar Entrada@>+=
{
  int i;
  for(i = 0; i < 5; i ++){
    _released_buttons[i] = 0;
    _pressed_buttons[i] = 0;
  }
  for(i = 0; i < 7; i ++)
    W.mouse.buttons[i] = 0;
  W.mouse.dx = 0;
  W.mouse.dy = 0;
}
@

@*2 Ocultando o Cursor do Mouse.

Nem sempre podemos querer manter o mesmo cursor na tela que o usado
pelo gerenciador de janelas. Pode ser que queiramos um cursor
diferente, com o formato de um alvo ou de uma mão. Ou então podemos
não querer nenhum cursor na frente tampando a visão do jogo. Em
qualquer um destes casos, começaremos ocultando o cursor. Em Xlib isso
pode ser feito com o seguinte código:

@<Cabeçalhos Weaver@>=
void _Whide_cursor(void);
@

@<API Weaver: Definições@>=
#if W_TARGET == W_ELF
void _Whide_cursor(void){
  Colormap cmap;
  Cursor no_ptr;
  XColor black, dummy;
  static char bm_no_data[] = {0, 0, 0, 0, 0, 0, 0, 0};
  Pixmap bm_no;
  cmap = DefaultColormap(_dpy, DefaultScreen(_dpy));
  XAllocNamedColor(_dpy, cmap, "black", &black, &dummy);
  bm_no = XCreateBitmapFromData(_dpy, _window, bm_no_data, 8, 8);
  no_ptr = XCreatePixmapCursor(_dpy, bm_no, bm_no, &black, &black, 0, 0);
  XDefineCursor(_dpy, _window, no_ptr);
  XFreeCursor(_dpy, no_ptr);
  if (bm_no != None)
    XFreePixmap(_dpy, bm_no);
  XFreeColors(_dpy, cmap, &black.pixel, 1, 0);
}
#endif
@

O código Xlib é trabalhoso, pois diferentes dispositivos em que o X
pode funcionar podem tratar cores de forma diferente. Aliás, pode até
mesmo ser que existam somente duas cores diferentes, uma associada ao
preto e outra associada ao branco. Então, na tentativa de obter a cor
mais próxima da desejada precisamos pedir cada cor para o servidor. Na
prática, hoje em dia é bastante seguro simplesmente assumir uma
representação RGB, mas para escrever código realmente portável, é
necessário alocar cores com o |XAllocNamedColor| informando o nome da
cor, o dispositivo onde colocá-la e o mapa de cores (que no caso
escolhemos o padrão). A função guarda em |black| a cor mais próxima do
preto possível e pedimos para guardar a representação exata do preto
em RGB na variável |dummy| (não precisamos disso e jogamos fora). A
cor é usada porque queremos gerar uma imagem preta colorindo um bitmap
(no caso uma imagem $8\times 8$ formada só por bits 1 e 0). Pintá-la
de preto é só uma desculpa para gerarmos a imagem à partir do
bitmap. O bitmap $8\times 8$ só com bit 0 é usado tanto para definir
os pixels pintados de preto (nenhum) como as regiões onde a imagem não
é transparente (nenhuma). Fazendo isso e passando a imagem gerada para
ser um cursor, o nosso ponteiro de mouse vira um quadrado $8\times 8$
completamente transparente. E com este truque nós o escondemos.

Vamos agora contrastar a complexidade deste método com o modo de fazer
isso do SDL para Emscripten:

@<API Weaver: Definições@>=
#if W_TARGET == W_WEB
void _Whide_cursor(void){
  SDL_ShowCursor(0);
  emscripten_hide_mouse();
}
#endif
@

Independente da complexidade da função, ela irá para dentro da estrutura |W|:

@<Funções Weaver@>+=
void (*hide_cursor)(void);
@

@<API Weaver: Inicialização@>=
W.hide_cursor = &_Whide_cursor;
@

@*1 Sumário das Variáveis e Funções do Teclado e Mouse.

\macronome As seguintes 3 novas variáveis foram definidas:

\macrovalor|int W.fps|:A cada \italico{frame} esta variável armazena a
quantos \italico{frames} por segundo o jogo está rodando. Variável
somente para leitura, não a modifique.

\macrovalor|int W.keyboard[0xffff]|: Um vetor que contém informações
sobre cada tecla do teclado. Se ela foi recém-pressionada, a posição
relacionada à tecla conterá o valor 1. Se ela está sendo pressionada,
ela terá um valor positivo correspondente à quantos milissegundos ela
vem sendo pressionada. Se ela foi recém-solta, ela terá um número
negativo correspondente à quantos milissegundos ela ficou pressionada
antes de ser solta. Se ela não está sendo pressionada e nem acabou de
ser solta, ela terá o valor 0. Variável somente para leitura, não
modifique os valores.

\macrovalor|struct W.mouse{ int buttons[7]; int x, y, dx, dy, ddx, ddy; }|:
Contém todas as informações sobre o \italico{mouse}. Em |buttons| pode-se
encontrar informações sobre os botões usando a mesma lógica da
apresentada acima para o teclado. Há a posição $x$ e $y$ do mouse, bem
como as componentes de sua velocidade em pixels por segundo em |dx| e
|dy|. As variáveis |ddx| e |ddy| contém os componentes de sua aceleração.

\macronome Também definimos as  5 novas funções:

\macrovalor|int W.key_translate(unsigned old_code, unsigned new_code)|:
Faz com que um determinado símbolo de teclado que podia não ser
reconhecido antes passe a ser associado com um símbolo
reconhecido. Pode ser necessário pesquisar o valor do código de cada
símbolo na documentação do Xlib.

\macrovalor|void W.erase_key_translations(void)|: Remove todas as
associações de um símbolo à outro feitas pela função acima.

\macrovalor|void W.hide_cursor(void)|: Esconde  a exibição do cursor
na janela.

\macrovalor|void W.flush_input(void)|: Limpa todos os dados de
|W.keyboard| e |W.mouse|, incluindo quais teclas estão sendo
 pressionadas.

\macrovalor|void Wloop(void (*f)(void))|: Inicia um \italico{loop}
 principal, executando em um \italico{loop} infinito a função passada
 como argumento.
