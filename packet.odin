package polyomino

import "core:encoding/endian"
import "core:fmt"
import "core:net"

PacketType :: enum u8 {
	Disconnect,
	AuthRequest,
	AuthResponse,
	AuthSuccess,
	AuthError,
	TaskRequest,
	TaskResponse,
	Result,
	TimeoutRequest,
	TimeoutResponse,
}

Header :: struct {
	type: PacketType,
	id:   u8,
	len:  u64,
}

Payload :: union {
	AuthRequest,
	AuthResponse,
	AuthSuccess,
	AuthError,
	TaskRequest,
	TaskResponse,
	Result,
	TimeoutRequest,
	TimeoutResponse,
}

Packet :: struct {
	header:      Header,
	payload:     Payload,
	raw_payload: []u8,
}

AuthRequest :: struct {
	secret: string,
}

AuthResponse :: struct {
	auth_data: [20]u8,
}

AuthSuccess :: struct {
	success: bool,
	message: string,
}

AuthError :: struct {
	success: bool,
	error:   string,
}

TaskRequest :: struct {
	amount: u64,
}

TaskResponse :: struct {
	amount: u64,
	size:   u64,
	start:  Polyomino,
	stop:   Polyomino,
}

Result :: struct {
	size:      u64,
	polyomino: Polyomino,
}

TimeoutRequest :: struct {
	timeout: u64,
}

TimeoutResponse :: struct {
	connected: bool,
}

decode_header :: proc(buff: []u8) -> (res: Header, ok: bool) {
	if len(buff) != 10 do return
	res.type = PacketType(buff[0])
	res.id = buff[1]
	res.len = read_u64(2, buff[:]) or_return

	ok = true
	return
}

encode_packet :: proc(packet: Packet) -> (res: [dynamic]u8) {
	append(&res, u8(packet.header.type))
	append(&res, packet.header.id)

	payload_bytes: []u8
	defer delete(payload_bytes)

	switch p in packet.payload {
	case AuthRequest:
		payload_bytes = encode_auth_request(p)[:]
	case AuthResponse:
		payload_bytes = encode_auth_response(p)[:]
	case AuthSuccess:
		payload_bytes = encode_auth_success(p)[:]
	case AuthError:
		payload_bytes = encode_auth_err(p)[:]
	case TaskRequest:
		payload_bytes = encode_task_request(p)[:]
	case TaskResponse:
		payload_bytes = encode_task_response(p)[:]
	case Result:
		payload_bytes = encode_result(p)[:]
	case TimeoutRequest:
		payload_bytes = encode_timeout_request(p)[:]
	case TimeoutResponse:
		payload_bytes = encode_timeout_response(p)[:]
	}

	append_u64(&res, u64(len(payload_bytes)))
	append(&res, ..payload_bytes)

	return
}

decode_payload :: proc(type: PacketType, buff: []u8) -> (res: Payload, ok: bool) {
	#partial switch type {
	case .AuthRequest:
		res = decode_auth_request(buff) or_return
	case .AuthResponse:
		res = decode_auth_response(buff) or_return
	case .AuthSuccess:
		res = decode_auth_success(buff) or_return
	case .AuthError:
		res = decode_auth_err(buff) or_return
	case .TaskRequest:
		res = decode_task_request(buff) or_return
	case .TaskResponse:
		res = decode_task_response(buff) or_return
	case .Result:
		res = decode_result(buff) or_return
	case .TimeoutRequest:
		res = decode_timeout_request(buff) or_return
	case .TimeoutResponse:
		res = decode_timeout_response(buff) or_return
	}

	ok = true
	return
}

encode_auth_request :: proc(packet: AuthRequest) -> (res: [dynamic]u8) {
	append_str(&res, packet.secret)
	return
}

decode_auth_request :: proc(buff: []u8) -> (res: AuthRequest, ok: bool) {
	res.secret = decode_str(0, buff[:]) or_return
	ok = true
	return
}

encode_auth_response :: proc(packet: AuthResponse) -> (res: [dynamic]u8) {
	for b in packet.auth_data {
		append(&res, b)
	}
	return
}

decode_auth_response :: proc(buff: []u8) -> (res: AuthResponse, ok: bool) {
	if len(buff) != 20 {
		ok = false
		return
	}
	copy(res.auth_data[:], buff[:20])

	ok = true
	return
}

encode_auth_success :: proc(packet: AuthSuccess) -> (res: [dynamic]u8) {
	append(&res, packet.success ? 1 : 0)
	append_str(&res, packet.message)
	return
}

decode_auth_success :: proc(buff: []u8) -> (res: AuthSuccess, ok: bool) {
	i := 0
	if len(buff) <= 0 do return

	res.success = buff[i] == 1
	i += 1

	res.message = decode_str(i, buff[:]) or_return
	ok = true

	return
}

encode_auth_err :: proc(packet: AuthError) -> (res: [dynamic]u8) {
	append(&res, packet.success ? 1 : 0)
	append_str(&res, packet.error)
	return
}

decode_auth_err :: proc(buff: []u8) -> (res: AuthError, ok: bool) {
	i := 0
	if len(buff) <= 0 do return

	res.success = buff[i] == 1
	i += 1

	res.error = decode_str(i, buff[:]) or_return
	ok = true

	return
}

encode_task_request :: proc(packet: TaskRequest) -> (res: [dynamic]u8) {
	append_int(&res, packet.amount)
	return
}

decode_task_request :: proc(buff: []u8) -> (res: TaskRequest, ok: bool) {
	res.amount = decode_int(0, buff[:]) or_return
	ok = true
	return
}

encode_task_response :: proc(packet: TaskResponse) -> (res: [dynamic]u8) {
	append_int(&res, packet.amount)
	append_int(&res, packet.size)
	append_polyomino(&res, packet.start)
	append_polyomino(&res, packet.stop)
	return
}

decode_task_response :: proc(buff: []u8) -> (res: TaskResponse, ok: bool) {
	i := 0
	res.amount, i = decode_int_inc(i, buff) or_return
	res.size, i = decode_int_inc(i, buff) or_return
	res.start, i = decode_polyomino_inc(i, buff) or_return
	res.stop, i = decode_polyomino_inc(i, buff) or_return

	ok = true
	return
}

encode_result :: proc(packet: Result) -> (res: [dynamic]u8) {
	append_int(&res, packet.size)
	append_polyomino(&res, packet.polyomino)
	return
}

decode_result :: proc(buff: []u8) -> (res: Result, ok: bool) {
	i := 0
	res.size, i = decode_int_inc(i, buff) or_return
	res.polyomino = decode_polyomino(i, buff) or_return

	ok = true
	return
}

encode_timeout_request :: proc(packet: TimeoutRequest) -> (res: [dynamic]u8) {
	append_int(&res, packet.timeout)
	return
}

decode_timeout_request :: proc(buff: []u8) -> (res: TimeoutRequest, ok: bool) {
	res.timeout = decode_int(0, buff) or_return

	ok = true
	return
}

encode_timeout_response :: proc(packet: TimeoutResponse) -> (res: [dynamic]u8) {
	append_int(&res, packet.connected ? 1 : 0)
	return
}

decode_timeout_response :: proc(buff: []u8) -> (res: TimeoutResponse, ok: bool) {
	timeout := decode_int(0, buff) or_return
	res.connected = timeout == 1

	ok = true
	return
}

Header_Err :: enum {
	HEADER_LENGTH,
	PAYLOAD_LENGTH,
}

TCP_Err :: union {
	Header_Err,
	net.TCP_Recv_Error,
}

// reads a packet from the tcp connection
recv_connection :: proc(socket: net.TCP_Socket) -> (packet: Packet, err: TCP_Err) {
	raw_payload: [dynamic]u8

	buff: [4096]u8

	// get the first 10 bytes (the header)
	n := net.recv_tcp(socket, buff[:10]) or_return

	// header malformed
	if n != 10 {
		err = .HEADER_LENGTH
		return
	}

	packet.header, _ = decode_header(buff[:n])

	// the number of bytes read
	total: u64 = 0
	for total < packet.header.len {
		// read_n is either 4096 or the remaining packet
		read_n := total + 4096 > packet.header.len ? total + packet.header.len : 4096
		n = net.recv_tcp(socket, buff[:read_n]) or_return

		if u64(n) != read_n {
			err = .PAYLOAD_LENGTH
			return
		}

		append(&raw_payload, ..buff[:n])
		total += 4096
	}

	payload_ok: bool
	packet.raw_payload = raw_payload[:]
	packet.payload, payload_ok = decode_payload(packet.header.type, raw_payload[:])
	if !payload_ok {
		err = .PAYLOAD_LENGTH
		return
	}

	return
}

send_connection :: proc(socket: net.TCP_Socket, packet: Packet) -> (err: net.TCP_Send_Error) {
	fmt.println(packet)
	bytes := encode_packet(packet)
	defer delete(bytes)

	_, err = net.send_tcp(socket, bytes[:])
	return
}
