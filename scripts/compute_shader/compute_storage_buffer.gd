extends ComputeDataBuffer
class_name ComputeStoargeBuffer


func _init(_rd: RenderingDevice, data: PackedByteArray, binding: int):
	rd = _rd
	buffer = rd.storage_buffer_create(data.size(), data)

	uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer)


func update(data: PackedByteArray):
	rd.buffer_update(buffer, 0, data.size(), data)
