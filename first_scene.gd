extends Sprite2D

var _bind_counter: int = 0;


func _get_buffer_size(s: int)-> PackedInt32Array:

	var arr := PackedInt32Array()
	arr.append(0)
	while s > 1:

		arr.append(s)
		@warning_ignore("integer_division")
		s = int(s / 2) + (s % 2)
	arr.append(s)
	arr[0] = arr.size()
	return arr


func calc_offset_buffer(buff: PackedInt32Array, b: int)->PackedInt32Array:

	var res     := PackedInt32Array(buff)
	var _offset =  0
	for i in range(1, buff.size()):
		res[i] = _offset
		_offset+= buff[i] * ((i+b) % 2)
	res[0] = res.size()

	return res


func _array_sum(arr: Array[int])->int:
	return arr.reduce(func(a, b): return a + b, 0)


func _pad_buffers(buff_x : PackedInt32Array, buff_y: PackedInt32Array):
	var n : int = max(buff_x.size(), buff_y.size())	
	while (buff_x.size() < n):
		buff_x.append(1)
	while (buff_y.size() < n):
		buff_y.append(1)
	buff_x[0] = buff_x.size()
	buff_y[0] = buff_y.size()
	
		
func _get_size_and_offsets_buffers(x: int, y: int):
	
	var x_size: = _get_buffer_size(x)
	var y_size    := _get_buffer_size(y)
	_pad_buffers(x_size, y_size)
	
	var x_offsets := calc_offset_buffer(x_size, 0)
	var y_offsets := calc_offset_buffer(y_size, 1)
	print(x_size)
	print(x_offsets)
	print(y_size)
	print(y_offsets)
	return [x_size, x_offsets, y_size, y_offsets]


func _init_storage_buffer(rd: RenderingDevice, array: PackedByteArray, update_counter :bool = true):

	var buffer := rd.storage_buffer_create(array.size(), array)

	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = _bind_counter
	if update_counter: 
		_bind_counter += 1
	uniform.add_id(buffer)
	
	return {'buffer': buffer, 'uniform': uniform }


func _init_heightmap():

	var heightmap := Image.new()
	heightmap.copy_from( texture.get_image())
	heightmap.convert(Image.FORMAT_L8)

	return heightmap


func _init_output_texture(rd: RenderingDevice, width: int, height: int):
	var fmt := RDTextureFormat.new()

	fmt.width = width
	fmt.height = height

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
	var rd: RenderingDevice = RenderingServer.create_local_rendering_device()

	# Create shader and pipeline
	var shader_file  = load("res://compute_example.glsl")
	var shader_spirv = shader_file.get_spirv()
	var shader       = rd.shader_create_from_spirv(shader_spirv)
	var pipeline     = rd.compute_pipeline_create(shader)
 
	@warning_ignore("integer_division")
	var size_data  = _get_size_and_offsets_buffers(texture.get_width(), texture.get_height())
	
	var out_width = size_data[0][1] + size_data[0][2] 
	var out_height =size_data[2][1]
	var output_data = _init_output_texture(rd, out_width, out_height)
	var output_data_texture = output_data['buffer']

	var height_map = _init_heightmap()
	var input_data = _init_output_texture(rd, texture.width, texture.height)
	var index_buff = PackedInt32Array([0]);

	var x_size_buf = _init_storage_buffer(rd, size_data[0].to_byte_array())
	var x_size_off = _init_storage_buffer(rd, size_data[1].to_byte_array())
	var y_size_buf = _init_storage_buffer(rd, size_data[2].to_byte_array())
	var y_size_off = _init_storage_buffer(rd, size_data[3].to_byte_array())
	var iteration = _init_storage_buffer(rd, index_buff.to_byte_array())
	
 
	var uniforms := [output_data['uniform'],
					input_data['uniform'],
					x_size_buf['uniform'],
					x_size_off['uniform'],
					y_size_buf['uniform'],
					y_size_off['uniform'],
					iteration['uniform']
					]

	
	rd.texture_update(input_data['buffer'], 0, height_map.get_data())
	
	
	
	for i in range(1, size_data[0][0]):
		index_buff[0] = i

		var b_index_buff = index_buff.to_byte_array()
		rd.buffer_update(iteration['buffer'], 0, b_index_buff.size(), b_index_buff )
		# Start compute list to start recording our compute commands
		var compute_list = rd.compute_list_begin()
		# Bind the pipeline, this tells the GPU what shader to use
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		# Binds the uniform set with the data we want to give our shader
		var uniform_set := rd.uniform_set_create(uniforms, shader, 0)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
		@warning_ignore("integer_division")	
		var x_groups = int(ceil(float(out_width)/8.))
		var y_groups = int(ceil(float(out_height)/8.))
		
		#rd.compute_list_add_barrier(compute_list)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)

		# Tell the GPU we are done with this compute task
		rd.compute_list_end( )
		# Force the GPU to start our commands
		rd.submit()
		# Force the CPU to wait for the GPU to finish with the recorded commands
		rd.sync()
		print ("done ", i )
				 
	var data: PackedByteArray = rd.texture_get_data(output_data_texture, 0)
	var img :=  (Image.create_from_data(out_width, out_height, false, Image.FORMAT_L8, data))
		
	var tex := ImageTexture.create_from_image(img)
	texture = tex

		 

	rd.free_rid(output_data['buffer'])
	rd.free_rid(input_data['buffer'])
	rd.free_rid(x_size_buf['buffer'])
	rd.free_rid(x_size_off['buffer'])
	rd.free_rid(y_size_buf['buffer'])
	rd.free_rid(y_size_off['buffer'])
	rd.free_rid(iteration['buffer'])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
