#version 100

#if GL_FRAGMENT_PRECISION_HIGH == 1
precision highp float;
precision highp int;
#else
precision mediump float;
precision mediump int;
#endif
precision lowp sampler2D;
precision lowp samplerCube;

attribute vec3 vertex_position;
uniform vec4 object_color;
uniform mat4 model_view_matrix;
uniform float time;
uniform vec2 object_size;
uniform int integer;
varying mediump vec2 texture_coordinate;

#if defined(VERTEX_SHADER)
void main(){
  gl_Position = model_view_matrix * vec4(vertex_position, 1.0);
  texture_coordinate = vec2(vertex_position[0] + 0.5, 
			    vertex_position[1] + 0.5);
}
#endif

#if defined(FRAGMENT_SHADER)
void main(){
  vec4 texture = texture2D(texture1, texture_coordinate);
  float final_alpha = texture.a + object_color.a * (1.0 - texture.a);
  gl_FragData[0] = vec4((texture.a * texture.rgb + object_color.rgb *
			 object_color.a * (1.0 - texture.a)) /
			final_alpha, final_alpha);
}
#endif
