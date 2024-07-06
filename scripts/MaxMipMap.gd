extends Sprite2D
class_name MaxMipMap

 
var computeContext : ComputeContext
			
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


func _init_heightmap():

	var heightmap := Image.new()
	heightmap.copy_from( texture.get_image())
	heightmap.convert(Image.FORMAT_L8)

	return heightmap


func _get_image_format(width: int, height: int):
	var fmt := RDTextureFormat.new()

	fmt.width = width
	fmt.height = height

	fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
					 RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	return fmt
 		
 
func _ready():
	await texture.changed
 
	computeContext = ComputeContext.new("res://shaders/compute_example.glsl")

	var size_data  = _get_size_and_offsets_buffers(texture.get_width(), texture.get_height())
	
	var x_size = size_data[0]
	var x_offsets = size_data[1]
	var y_size = size_data[2]
	var y_offsets = size_data[3]
	var index_buff = PackedInt32Array([0]);

	var out_width = x_size[1] + x_size[2]
	var out_height = y_size[1]
 
	var fmt = _get_image_format(out_width, out_height)
	var output_img_buffer = computeContext.add_image_buffer('output_img', fmt)

	var height_map = _init_heightmap()
	var input_fmt = _get_image_format(texture.get_width(), texture.get_height())
	computeContext.add_image_buffer('input_img', input_fmt, height_map)
 
	computeContext.add_storage_buffer('x_size_buf', x_size.to_byte_array())
	computeContext.add_storage_buffer('x_size_off', x_offsets.to_byte_array())
	computeContext.add_storage_buffer('y_size_buf', y_size.to_byte_array())
	computeContext.add_storage_buffer('y_size_off', y_offsets.to_byte_array())
	var iteration_buff := computeContext.add_storage_buffer('iteration', index_buff.to_byte_array())
 

	for i in range(1, x_size[0]):
		index_buff[0] = i
		iteration_buff.update(index_buff.to_byte_array())
		@warning_ignore("integer_division")	
		var x_groups = int(ceil(float(x_size[i])/8.))
		var y_groups = int(ceil(float(y_size[i])/8.))
		
		computeContext.compute(x_groups, y_groups)
 
	var tex := output_img_buffer.get_texture()
	#mipmap = tex
	texture = tex
 	
	computeContext.free_all()
	
	#material.set_shader_parameter("mipmap", mipmap)
	#material.set_shader_parameter("x_sizes", x_size)
	#material.set_shader_parameter("x_offsets", x_offsets)
	#material.set_shader_parameter("y_sizes", y_size)
	#material.set_shader_parameter("y_offsets", y_offsets)
	#
	
 
