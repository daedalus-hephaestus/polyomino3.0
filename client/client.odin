package polyomino_client

import poly ".."
import "core:flags"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"

password := "polyominosrock"

Options :: struct {
	address:  string `args:"required" usage:"The ip address of the server"`,
	password: string `usage:"The server password"`,
	amount:   string `args:"required" usage:"The amount of polyominos you are willing to calculate"`,
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			if len(track.bad_free_array) > 0 {
				for entry in track.bad_free_array {
					fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)
	connect(opt)

}

connect :: proc(opt: Options) {
	id: u8

	ip, parse_err := net.resolve_ip4(opt.address)
	if parse_err != nil do return

	socket, dial_err := net.dial_tcp(ip)
	if dial_err != nil do fmt.panicf("unable to dial server")

	poly.send_connection(
		socket,
		{header = {type = .AuthRequest, id = id}, payload = poly.AuthRequest{secret = password}},
	)

	auth_response, auth_res_err := poly.recv_connection(socket)
	defer delete(auth_response.raw_payload)

	id = auth_response.header.id + 1

	hash: [20]u8
	#partial switch p in auth_response.payload {
	case poly.AuthResponse:
		hash = poly.encrypt_password(opt.password, p.auth_data)
	case:
		return
	}

	poly.send_connection(
		socket,
		{header = {type = .AuthResponse, id = id}, payload = poly.AuthResponse{auth_data = hash}},
	)

	for {
		packet, err := poly.recv_connection(socket)
		if packet.header.type == .Disconnect do break
		defer delete(packet.raw_payload)

		id = packet.header.id + 1

		#partial switch p in packet.payload {
		case poly.TimeoutRequest:
			poly.send_connection(
				socket,
				{header = {type = .TimeoutResponse, id = id}, payload = {connected = true}},
			)
		}
	}


}
