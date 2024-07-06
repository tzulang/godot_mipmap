extends ComputeDataBuffer
class_name ComputeImageBuffer

 
var format : RDTextureFormat


func _init(_rd: RenderingDevice, _format : RDTextureFormat, binding: int, img: Image = null):
	rd = _rd
	format = _format

	buffer  = rd.texture_create(format, RDTextureView.new())

	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(buffer)
 	
	if img != null:
		update(img)


func update(img :Image):
	
	if img == null:
		printerr("img is null")
		return 
	elif img.get_width() != format.width or img.get_height() != format.height:
			printerr("img size is wrong") 
			return 
	rd.texture_update(buffer, 0, img.get_data())
	
	
func get_image() -> Image:
	var data: PackedByteArray = rd.texture_get_data(buffer, 0)
	var img :=  (Image.create_from_data(format.width, format.height, false, Image.FORMAT_L8, data))	
	return img


func get_texture() ->ImageTexture:
	var tex := ImageTexture.create_from_image(get_image())
	return tex
