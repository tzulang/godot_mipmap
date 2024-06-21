extends Sprite2D
 
var _bind_counter: int = 0;

func _init_heightmap():
	
	var heightmap := Image.new()
	heightmap.copy_from( texture.get_image())
	heightmap.convert(Image.FORMAT_L8)
	
	return heightmap
	

func _init_output_texture(rd: RenderingDevice, factor = 1.0):
	var fmt := RDTextureFormat.new()
	
	@warning_ignore("integer_division")
	fmt.width = int(ceil(texture.get_width() / factor))
	
	@warning_ignore("integer_division")
	fmt.height = int(ceil(texture.get_height()/ factor))
	
	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	#var image := Image.create(texture.get_width(), texture.get_height(), false, Image.FORMAT_L8)
	#var data_texture : ImageTexture	 = ImageTexture.create_from_image(image)	
	var output_data_texture: RID = rd.texture_create(fmt, RDTextureView.new())
	
	var output_data_uniform := RDUniform.new()
	output_data_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_data_uniform.binding = _bind_counter
	output_data_uniform.add_id(output_data_texture)
	
	_bind_counter+=1
	
	return {'texture': output_data_texture, 'uniform': output_data_uniform}
	
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
 	
	var factor := 4. / 3.;
	
	var output_data = _init_output_texture(rd, factor)
	var output_data_texture = output_data['texture']
	var output_data_uniform = output_data['uniform']
	
	var height_map = _init_heightmap()	
	var input_data = _init_output_texture(rd)
	rd.texture_update(input_data['texture'], 0, height_map.get_data())
	
	var uniforms := [output_data_uniform, input_data['uniform']]	

 
	
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
	
	var img : Image = (Image.create_from_data(int(ceil(texture.get_width()/factor)),  
											  int(ceil(texture.get_height()/factor)), 
											  false, Image.FORMAT_L8, data))
	var tex := ImageTexture.create_from_image(img)
	texture = tex
	
	rd.free_rid(output_data_texture) 
	rd.free_rid(input_data['texture']) 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
