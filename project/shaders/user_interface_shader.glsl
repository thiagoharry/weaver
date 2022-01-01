/* LIST OF PREDEFINED VARIABLES: */
/*
   attribute vec3 vertex_position;
   attribute vec2 vertex_texture_coordinate;
   uniform vec4 foreground_color, background_color;
   uniform mat4 model_view_matrix;
   uniform float time; // In seconds, modulus 1 hour
   uniform int integer;
   uniform sampler2D texture1;
   uniform vec2 interface_size; // In pixels
   uniform vec2 mouse_coordinate; // Origin: interface lower left corner
   varying mediump vec2 texture_coordinate;
*/


#if defined(VERTEX_SHADER)
void main(){
  gl_Position = model_view_matrix * vec4(vertex_position, 1.0);
  texture_coordinate = vertex_texture_coordinate;
}
#endif


#if defined(FRAGMENT_SHADER)
void main(){
  vec4 texture = texture2D(texture1, texture_coordinate);
  gl_FragData[0] = texture;
}
#endif
