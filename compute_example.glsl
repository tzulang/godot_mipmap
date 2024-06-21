#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(r8, binding = 0) restrict uniform image2D output_data;
layout(r8, binding = 1) restrict readonly uniform image2D input_data;
	
 


void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

 	ivec2 uv_input = uv * 2;


 	float value = 		   	  imageLoad(input_data , uv_input		 		).x;
 	  	  value = max( value, imageLoad(input_data , uv_input + ivec2(1, 0)	).x);
 	  	  value = max( value, imageLoad(input_data , uv_input + ivec2(1, 1)	).x);
 	  	  value = max( value, imageLoad(input_data , uv_input + ivec2(0, 1)	).x);
 	  
	vec4 pixel = vec4(vec3(value), 0.0);
	imageStore(output_data, uv, pixel);

}
