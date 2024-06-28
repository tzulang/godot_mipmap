#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(r8, binding = 0) restrict uniform image2D output_data;
layout(r8, binding = 1) restrict readonly uniform image2D input_data;
 

layout(set = 0, binding = 2, std430) restrict readonly buffer a { int x_sizes[];};
layout(set = 0, binding = 3, std430) restrict readonly buffer b { int x_offset[];};
layout(set = 0, binding = 4, std430) restrict readonly buffer c { int y_sizes[];};
layout(set = 0, binding = 5, std430) restrict readonly buffer d { int y_offset[];};




float get_max_value(float a, float b, float c, float d) {

 	float value = max( a, b);
  	value = max( value, c);
  	value = max( value, d);
 	return value;
}


void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

 	ivec2 uv_input = uv * 2;

 	int width = x_sizes[1];
 	int heigt = y_sizes[1];


 	float value=0;
	
	int n = int(x_sizes[0]);
 	
 	
 	for (int i=1; i < n ; i++){
 	 	float color = 1. - 1./float(n) * float(i-1);
 	 	float x_min = x_offset[i];
 	 	float x_max = x_offset[i] + x_sizes[i];
 	 	float y_min = y_offset[i];
 	 	float y_max = y_offset[i] + y_sizes[i];
 	 	if ((x_min <= uv.x && uv.x < x_max) && (y_min <= uv.y && uv.y < y_max)) {
 	 	  	value = color;
 	 	}


 	}
 	// float value = get_max_value(
 	// 		   	  	 imageLoad(input_data, uv_input).x,
 	//   	   			 imageLoad(input_data, uv_input + ivec2(1, 0)).x,
 	//   	   			 imageLoad(input_data, uv_input + ivec2(1, 1)).x,
 	//   	   			 imageLoad(input_data, uv_input + ivec2(0, 1)).x);
 	

	 
	vec4 pixel = vec4(vec3(value), 1.0);
	imageStore(output_data, uv, pixel);




}
