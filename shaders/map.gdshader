shader_type canvas_item;

uniform sampler2D mipmap;
uniform int[64] x_sizes; 
uniform int[64] x_offsets;
uniform int[64] y_sizes;
uniform int[64] y_offsets;	


uniform float sea_level: hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float coast_margin: hint_range(0.0, .05, 0.005) = 0.1;
 
uniform vec3 sea_color: source_color; 
uniform vec3 deep_sea_color: source_color; 

uniform vec3 coast_color: source_color;
uniform vec3 ground_color: source_color;
 
vec2 get_mip_level_uv(vec2 uv, int n, ivec2 mip_size){
	vec2 p_size = vec2( float(x_sizes[n]), float(y_sizes[n]));
	ivec2 xy = ivec2(int(uv.x * p_size.x), int(uv.y * p_size.y));
	xy += ivec2(x_offsets[n], y_offsets[n]);
	vec2 res = vec2(xy) / vec2(mip_size);
	return res;
}
	
	
float getPointHeight(sampler2D text, vec2 p){
	
	vec2 centerd = 1.- abs(p *2. -1.);
	float factor = (centerd.x * centerd.y);
	return factor * texture(text, p).r;
}

float getHeight(sampler2D text, vec2 psize, vec2 p){
	
	float D = getPointHeight(text,  p + vec2(0., psize.y)); 
	float U = getPointHeight(text,  p - vec2(0., psize.y));
	float L = getPointHeight(text,  p - vec2(psize.x, 0.));
	float R = getPointHeight(text,  p + vec2(psize.x, 0.));
	float C =  getPointHeight(text, p);
	
	float a = .5;
	return C * a + (D + U + L + R) * 0.2 * (1.-a);
}

vec4 get_color(vec2 uv) {
	ivec2 mip_size = textureSize(mipmap, 0);
	vec2 xy = get_mip_level_uv(uv, 1, mip_size);
	float height = getPointHeight(mipmap ,uv);
	
	vec4 color = vec4(ground_color, 1.0);
	if (height <sea_level) {
		float depth = height/sea_level;
		
		color += vec4(sea_color, 1.0 - depth);
	}
	return color;
}

void fragment() {
	//vec2 uv = UV.xy;
	ivec2 mip_size = textureSize(mipmap, 0);
	vec2 xy = get_mip_level_uv(UV.xy, 4, mip_size);
	
	 
	COLOR = get_color(UV);
	
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
