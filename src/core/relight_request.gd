class_name RelightRequest
extends RefCounted


var light: LightSource
var requester: Node
var position: Vector3


static func create(source: LightSource, requestor: Node) -> RelightRequest:
	var request := RelightRequest.new()
	request.light = source
	request.requester = requestor
	request.position = source.global_position if source != null else Vector3.ZERO
	return request
