package polyomino_server

import poly ".."
import "core:flags"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:os"
import "core:sync"
import "core:thread"
import "core:time"

secret := "polyominosrock"


Options :: struct {
	size:     int `args:"required" usage:"The size of the polyominos being indexed"`,
	type:     poly.PolyominoType `usage:"The type of the polyominos being indexed"`,
	port:     int `args:"required" usage:"The port that tcp clients connect to"`,
	address:  string `args:"required" usage:"The ip address of the server"`,
	password: string `usage:"The server password"`,
}

Server :: struct {
	tcp_threads: [dynamic]^thread.Thread,
	endpoint:    net.Endpoint,
	running:     bool,
	queue:       ^Queue,
	console:     ^thread.Thread,
	manager:     ^thread.Thread,
	allocator:   mem.Allocator,
}

destroy_server :: proc(server: ^Server) {
	for a in server.queue.assignments {
		net.shutdown(a.socket, .Both)
	}

	for t in server.tcp_threads {
		thread.destroy(t)
	}

	delete(server.tcp_threads)

	thread.destroy(server.manager)
	thread.destroy(server.console)

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
	start_server(opt)

}

start_server :: proc(opt: Options) {
	ip, ok := net.parse_ip4_address(opt.address)
	if !ok do fmt.panicf("failed to parse ip")

	tcp_server, listen_err := net.listen_tcp({address = ip, port = opt.port})
	if listen_err != nil do fmt.panicf("listen failed: ", listen_err)

	queue: Queue = {
		size     = opt.size,
		password = opt.password,
	}

	append(&queue.unchecked_ranges, {
		poly.min_polyomino(opt.size),
		poly.max_polyomino(opt.size)
	})

	poly.print_range(queue.unchecked_ranges[0])

	defer destroy_queue(&queue)

	server: Server = {
		queue = &queue,
		running = true,
		endpoint = {address = ip, port = opt.port},
		allocator = context.allocator,
	}
	defer destroy_server(&server)

	// start server manager and console thread
	server.console = thread.create_and_start_with_poly_data(&server, console)
	server.manager = thread.create_and_start_with_poly_data(&server, manager)

	fmt.println("listening on port", opt.port)

	for server.running {
		client, endpoint, accept_err := net.accept_tcp(tcp_server)
		if accept_err != nil do break

		if !server.running {
			net.close(client)
			break
		}

		// create an assignment for each connection
		assignment := new(Assignment, server.allocator)
		assignment^ = {
			socket   = client,
			size     = opt.size,
			type     = opt.type,
			endpoint = endpoint,
			running  = &server.running,
			queue    = &queue,
		}
		append(&queue.assignments, assignment)

		thread := thread.create_and_start_with_poly_data(assignment, handle_assignment)
		append(&server.tcp_threads, thread)
	}
}

authenticate :: proc(assignment: ^Assignment) -> (success: bool) {
	packet : poly.Packet
	recv_err : poly.TCP_Err
	packet, assignment.tcp_id, recv_err = poly.recv_connection(assignment.socket)
	defer delete(packet.raw_payload)

	if recv_err != nil do return

	assignment.tcp_id = packet.header.id + 1

	#partial switch p in packet.payload {
	case poly.AuthRequest:
		if p.secret != secret do return
	case:
		return
	}

	auth_data := poly.auth_data()
	expected_hash := poly.encrypt_password(assignment.queue.password, auth_data)

	assignment.tcp_id, _ = poly.send_connection(
		assignment.socket,
		{
			header = {type = .AuthResponse, id = assignment.tcp_id},
			payload = {auth_data = auth_data},
		},
	)

	packet, assignment.tcp_id, recv_err = poly.recv_connection(assignment.socket)

	#partial switch p in packet.payload {
	case poly.AuthResponse:
		return p.auth_data == expected_hash
	case:
		return
	}

	return true
}

console :: proc(server: ^Server) {
	buf: [1024]u8

	for server.running {
		n, err := os.read(os.stdin, buf[:])
		if err != nil do break

		cmd := string(buf[:n - 1])
		switch cmd {
		case "exit", "close":
			sync.mutex_lock(&server.queue.mutex)
			server.running = false
			wake, dial_err := net.dial_tcp(server.endpoint)
			if dial_err == nil do net.close(wake)
			sync.mutex_unlock(&server.queue.mutex)
			return
		case "list", "ls":
			if len(server.queue.assignments) <= 0 {
				fmt.println("no active clients")
			} else {
				for a in server.queue.assignments do fmt.println(a)
			}
		}

	}
}

manager :: proc(server: ^Server) {
	for server.running {
		time.sleep(time.Second * 5)
		sync.mutex_lock(&server.queue.mutex)

		// loop through and cleanup timed out assignments
		for a in server.queue.assignments {


			if a.status == .DISCONNECTED || a.status == .TIMEOUT {
				remove_assignment(a, server.queue)
				destroy_assignment(a, server.allocator)

				fmt.println("removing disconnected client")
				continue
			}

			a.tcp_id, _ = poly.send_connection(
				a.socket,
				{
					header = {type = .TimeoutRequest, id = a.tcp_id},
					payload = poly.TimeoutRequest{timeout = 5000},
				},
			)
			a.status = .TIMEOUT

		}

		sync.mutex_unlock(&server.queue.mutex)
	}
}
