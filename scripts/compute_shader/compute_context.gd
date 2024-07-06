extends Object
class_name ComputeContext


var rd: RenderingDevice
var shader_spirv : RDShaderSPIRV
var shader : RID 
var pipeline :  RID 
var uniforms : Array[RDUniform]
var buffers : Dictionary


func _init(compute_shader_file: String):
	 
	# We will be using our own RenderingDevice to handle the compute commands
	rd = RenderingServer.create_local_rendering_device()
	
	# Create shader and pipeline
	var shader_data := load(compute_shader_file)
	shader_spirv = shader_data.get_spirv()
	shader       = rd.shader_create_from_spirv(shader_spirv)
	pipeline     = rd.compute_pipeline_create(shader)
	buffers = {}

	
func add_storage_buffer(name: String, data: PackedByteArray) -> ComputeStoargeBuffer:
	var binding : int = buffers.size() 
	var buff =  ComputeStoargeBuffer.new(rd, data, binding)
	buffers[name] = buff
	uniforms.append(buff.uniform)
	return buff
	

func add_image_buffer(name: String, format:RDTextureFormat , img: Image= null) -> ComputeImageBuffer:
	var binding : int = buffers.size() 
	var buff =  ComputeImageBuffer.new(rd, format, binding, img)
	buffers[name] = buff
	uniforms.append(buff.uniform)
	return buff

func free_all():	
	for buf in buffers:
		buffers[buf].free()


func compute(x_groups : int, y_groups: int):
	 
	# Start compute list to start recording our compute commands
	var compute_list = rd.compute_list_begin()
	# Bind the pipeline, this tells the GPU what shader to use
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	# Binds the uniform set with the data we want to give our shader
	var uniform_set := rd.uniform_set_create(uniforms, shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	#rd.compute_list_add_barrier(compute_list)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)

	# Tell the GPU we are done with this compute task
	rd.compute_list_end( )
	# Force the GPU to start our commands
	rd.submit()
	# Force the CPU to wait for the GPU to finish with the recorded commands
	rd.sync()
	
