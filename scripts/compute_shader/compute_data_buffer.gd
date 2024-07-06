extends Object
class_name ComputeDataBuffer


var buffer: RID
var uniform: RDUniform 
var rd: RenderingDevice
 
 
func free():
	if (buffer.is_valid()):
		self.rd.free_rid(buffer)
	super.free()
	
