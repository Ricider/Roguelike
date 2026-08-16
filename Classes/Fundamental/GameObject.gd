extends RefCounted
class_name GameObject

static var _next_uid: int = 1
var UID: int

func _init():
	UID = _next_uid
	_next_uid += 1
