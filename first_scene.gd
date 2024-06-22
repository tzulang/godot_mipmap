extends Sprite2D
 
var _bind_counter: int = 0;

func _get_buffer_size(s: int)-> PackedInt32Array :
	
	var arr := PackedInt32Array()
	while s > 1:
		 
		arr.append(s)
		@warning_ignore("integer_division")
		s = int(s/2) + s%2
	arr.append(s)
	var res := PackedInt32Array([arr.size()])
	res.append_array(arr)
	return res 

func _array_sum(arr :Array[int])->int:
	return arr.reduce(func(a,b): return a + b, 0)

func _get_buffer_sizes(x: int,  y: int)	:	
	
	var x_size := _get_buffer_size(x)
	var y_size := _get_buffer_size(y)
	
	return [x_size, y_size]
	
	
func _init_stoarge_buffer(rd: RenderingDevice, array: PackedInt32Array):
	
	var input_bytes = array.to_byte_array()
	var buffer := rd.storage_buffer_create(input_bytes.size(), input_bytes)
	
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = _bind_counter 
	_bind_counter += 1
	uniform.add_id(buffer) 
	
	return {'buffer': buffer, 'uniform': uniform }

func _init_heightmap():
	
	var heightmap := Image.new()
	heightmap.copy_from( texture.get_image())
	heightmap.convert(Image.FORMAT_L8)
	
	return heightmap
	

func _init_output_texture(rd: RenderingDevice, factor = [1.0, 1.0]):
	var fmt := RDTextureFormat.new()
	
	@warning_ignore("integer_division")
	fmt.width = int(ceil(texture.get_width() / factor[0]))
	fmt.height = int(ceil(texture.get_width() / factor[1]))
	
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	var output_data_texture: RID = rd.texture_create(fmt, RDTextureView.new())
	
	var output_data_uniform := RDUniform.new()
	output_data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_data_uniform.binding = _bind_counter
	output_data_uniform.add_id(output_data_texture)
	
	_bind_counter+=1
	
	return {'buffer': output_data_texture, 'uniform': output_data_uniform}
	
# Called when the node enters the scene tree for the first time.
func _ready():
	await texture.changed
	# We will be using our own RenderingDevice to handle the compute commands
	var rd : RenderingDevice = RenderingServer.create_local_rendering_device()
	
	# Create shader and pipeline
	var shader_file = load("res://compute_example.glsl")
	var shader_spirv = shader_file.get_spirv()
	var shader = rd.shader_create_from_spirv(shader_spirv)
	var pipeline = rd.compute_pipeline_create(shader)
	 	
	var factor := [4. / 3., 2.] ;
	
	var output_data = _init_output_texture(rd, factor)
	var output_data_texture = output_data['buffer']
 	
	var height_map = _init_heightmap()	
	var input_data = _init_output_texture(rd)
	rd.texture_update(input_data['buffer'], 0, height_map.get_data())
	
	var size_data = _get_buffer_sizes(texture.get_width(), texture.get_height())
	var x_size_buf = _init_stoarge_buffer(rd, size_data[0])
	var y_size_buf = _init_stoarge_buffer(rd, size_data[1])
		
	var uniforms := [output_data['uniform'], 
					 input_data['uniform'],
					 x_size_buf['uniform'],
					 y_size_buf['uniform'],
					]	
	
	# Start compute list to start recording our compute commands
	var compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	var uniform_set := rd.uniform_set_create(uniforms, shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	
		
	@warning_ignore("integer_division")
	
	rd.compute_list_dispatch(compute_list, texture.get_width()/8, texture.get_height()/8, 1)
	#rd.compute_list_add_barrier(compute_list)
	# Tell the GPU we are done with this compute task
	rd.compute_list_end()
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()
	
	var data : PackedByteArray = rd.texture_get_data(output_data_texture, 0)
	
	@warning_ignore("integer_division")
	
	var img : Image = (Image.create_from_data(int(ceil(texture.get_width()/factor[0])),  
											  int(ceil(texture.get_height()/factor[1])), 
											  false, Image.FORMAT_L8, data))
	var tex := ImageTexture.create_from_image(img)
	texture = tex
	
	rd.free_rid(output_data['buffer']) 
	rd.free_rid(input_data['buffer']) 
	rd.free_rid(x_size_buf['buffer']) 
	rd.free_rid(y_size_buf['buffer']) 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
