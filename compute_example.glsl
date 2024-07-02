#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(r8, binding = 0) restrict uniform image2D output_data;
layout(r8, binding = 1) restrict readonly uniform image2D input_data;


layout(set = 0, binding = 2, std430) restrict readonly buffer a { int x_sizes[];};
layout(set = 0, binding = 3, std430) restrict readonly buffer b { int x_offset[];};
layout(set = 0, binding = 4, std430) restrict readonly buffer c { int y_sizes[];};
layout(set = 0, binding = 5, std430) restrict readonly buffer d { int y_offset[];};
layout(set = 0, binding = 6, std430) restrict readonly buffer e { int iteration[];};


float get_max_value(float a, float b, float c, float d) {
 	float value = max( a, b);
  	value = max( value, c);
  	value = max( value, d);
 	return value;
}

// calculate the previous mipmap uv coord
// and calculate the max value between the 4 pixels
float get_prev_value(int index, ivec2 mip_local_uv) {

	ivec2 prev_mip_offset = ivec2(x_offset[index-1], y_offset[index-1]);
	ivec2 prev_mip_local_uv = mip_local_uv * 2;
	ivec2 prev_mip_end = prev_mip_offset + ivec2(x_sizes[index-1]-1, y_sizes[index-1]-1);

	// prev mipmap uv coords with respect to mipmap boundaries
	ivec2 uv0 = prev_mip_offset + prev_mip_local_uv;
	ivec2 uv1 = min(uv0 + ivec2(1, 0), prev_mip_end);
	ivec2 uv2 = min(uv0 + ivec2(1, 1), prev_mip_end);
	ivec2 uv3 = min(uv0 + ivec2(0, 1), prev_mip_end);
	// max pixel value
	float value = get_max_value(
						imageLoad(output_data, uv0).x,
						imageLoad(output_data, uv1).x,
						imageLoad(output_data, uv2).x,
						imageLoad(output_data, uv3).x);
	return value;
}


bool is_in_boundaries(int index, ivec2 uv){

	float x_min = x_offset[index];
	float x_max = x_offset[index] + x_sizes[index];
	float y_min = y_offset[index];
	float y_max = y_offset[index] + y_sizes[index];
	return ((x_min <= uv.x && uv.x < x_max) && (y_min <= uv.y && uv.y < y_max));
}


void main() {
	// shader is called M times to create each level of the mipmap
	// startig with n = 1 to M
	int n = iteration[0];

	// the  uv coord range is from 0,0 to the mipmap width, height
	ivec2 local_uv = ivec2(gl_GlobalInvocationID.xy);
	// uv coord in relation to the whole mipmap image
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy) + ivec2(x_offset[n], y_offset[n]);

	if (n == 1) // original image
	{
		if (is_in_boundaries(1, uv)) {
			float value = imageLoad(input_data, uv).x;
			vec4 pixel = vec4(vec3(value), 1.0);
			imageStore(output_data, uv, pixel);
		}
	} else { //other mip levels
		if (is_in_boundaries(n, uv)) {
			float value = get_prev_value(n, local_uv);
			vec4 pixel = vec4(vec3(value), 1.0);
			imageStore(output_data, uv, pixel);
		}
	}
}
