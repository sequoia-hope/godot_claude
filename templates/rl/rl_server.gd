extends Node
class_name RLServer
## TCP server for Python RL agent communication
##
## Implements Godot RL Agents compatible protocol:
## - 4-byte little-endian length prefix
## - JSON message body

signal client_connected
signal client_disconnected
signal message_received(message: Dictionary)

var server: TCPServer = null
var client: StreamPeerTCP = null
var port: int = 11008
var timeout_ms: int = 5000

var _read_buffer: PackedByteArray = PackedByteArray()
var _connected: bool = false

func _ready():
	server = TCPServer.new()

func start(listen_port: int = 11008) -> Error:
	port = listen_port
	var err = server.listen(port)
	if err == OK:
		print("RLServer: Listening on port ", port)
	else:
		push_error("RLServer: Failed to listen on port ", port, " error: ", err)
	return err

func stop():
	if client:
		client.disconnect_from_host()
		client = null
	if server:
		server.stop()
	_connected = false
	print("RLServer: Stopped")

func is_connected_to_client() -> bool:
	return _connected and client and client.get_status() == StreamPeerTCP.STATUS_CONNECTED

func _process(_delta):
	if not server.is_listening():
		return

	# Accept new connections
	if server.is_connection_available():
		var new_client = server.take_connection()
		if new_client:
			if client:
				client.disconnect_from_host()
			client = new_client
			client.set_no_delay(true)
			_connected = true
			_read_buffer.clear()
			print("RLServer: Client connected")
			client_connected.emit()

	# Check connection status
	if client:
		client.poll()
		var status = client.get_status()

		if status == StreamPeerTCP.STATUS_CONNECTED:
			_handle_incoming_data()
		elif status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			if _connected:
				_connected = false
				print("RLServer: Client disconnected")
				client_disconnected.emit()

func _handle_incoming_data():
	var available = client.get_available_bytes()
	if available <= 0:
		return

	# Read available data into buffer
	var data = client.get_data(available)
	if data[0] != OK:
		return

	_read_buffer.append_array(data[1])

	# Process complete messages
	while _try_parse_message():
		pass

func _try_parse_message() -> bool:
	# Need at least 4 bytes for length prefix
	if _read_buffer.size() < 4:
		return false

	# Read length (little-endian uint32)
	var length = _read_buffer.decode_u32(0)

	# Check if we have the complete message
	if _read_buffer.size() < 4 + length:
		return false

	# Extract JSON payload
	var json_bytes = _read_buffer.slice(4, 4 + length)
	var json_str = json_bytes.get_string_from_utf8()

	# Remove processed bytes from buffer
	_read_buffer = _read_buffer.slice(4 + length)

	# Parse JSON
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		push_error("RLServer: JSON parse error: ", json.get_error_message())
		return true  # Continue processing other messages

	var message = json.data
	if message is Dictionary:
		message_received.emit(message)

	return true

func send_message(message: Dictionary) -> Error:
	if not is_connected_to_client():
		return ERR_CONNECTION_ERROR

	var json_str = JSON.stringify(message)
	var json_bytes = json_str.to_utf8_buffer()
	var length = json_bytes.size()

	# Create length prefix (little-endian uint32)
	var length_bytes = PackedByteArray()
	length_bytes.resize(4)
	length_bytes.encode_u32(0, length)

	# Send length prefix + JSON
	var err = client.put_data(length_bytes)
	if err != OK:
		return err

	err = client.put_data(json_bytes)
	return err

func wait_for_message(timeout_ms: int = -1) -> Dictionary:
	"""Blocking wait for next message (use with caution)"""
	if timeout_ms < 0:
		timeout_ms = self.timeout_ms

	var start_time = Time.get_ticks_msec()

	while true:
		if client:
			client.poll()
			_handle_incoming_data()

		# Check for pending message (would need to queue messages)
		# For now, this is a simplified implementation

		if Time.get_ticks_msec() - start_time > timeout_ms:
			return {"error": "timeout"}

		# Yield to avoid blocking
		await get_tree().process_frame

	return {}
