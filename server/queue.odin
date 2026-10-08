package polyomino_server

import poly ".."
import "core:fmt"
import "core:mem"
import "core:net"
import "core:sync"

Queue :: struct {
	size:             int,
	type:             poly.PolyominoType,
	highest:          poly.Polyomino,
	checked_ranges:   [dynamic]poly.Range,
	unchecked_ranges: [dynamic]poly.Range,
	assigned_ranges:  map[net.TCP_Socket]poly.Range,
	assignments:      [dynamic]^Assignment,
	password:         string,
	mutex:            sync.Mutex,
}


destroy_queue :: proc(queue: ^Queue) {
	poly.destroy_polyomino(queue.highest)
	for &r in queue.checked_ranges do poly.destroy_range(&r)
	for _, &r in queue.assigned_ranges do poly.destroy_range(&r)
	for &r in queue.unchecked_ranges do poly.destroy_range(&r)

	delete(queue.unchecked_ranges)
	delete(queue.assigned_ranges)
	delete(queue.checked_ranges)
	delete(queue.assignments)
}

AssignmentStatus :: enum {
	WORKING,
	TIMEOUT,
	DISCONNECTED,
	DONE,
}

Assignment :: struct {
	socket:   net.TCP_Socket,
	endpoint: net.Endpoint,
	queue:    ^Queue,
	status:   AssignmentStatus,
	size:     int,
	type:     poly.PolyominoType,
	range:    poly.Range,
	found:    [dynamic]poly.Polyomino,
	running:  ^bool,
	tcp_id:   u8,
	mutex:    sync.Mutex,
}

remove_assignment :: proc(assignment: ^Assignment, queue: ^Queue) {
	for a, i in queue.assignments {

		if a == assignment {
			range, ok := queue.assigned_ranges[a.socket]
			if ok {
				inject_at(&queue.unchecked_ranges, 0, poly.clone_range(range))
				poly.destroy_range(&range)
				delete_key(&queue.assigned_ranges, a.socket)
			}

			unordered_remove(&queue.assignments, i)
		}
	}
}

destroy_assignment :: proc(assignment: ^Assignment, allocator: mem.Allocator = context.allocator) {
	poly.destroy_range(&assignment.range, allocator)

	for p in assignment.found do poly.destroy_polyomino(p, allocator)
	delete(assignment.found)

	free(assignment, allocator)
}

handle_assignment :: proc(assignment: ^Assignment) {

	success := authenticate(assignment)
	if success {
		assignment.tcp_id, _ = poly.send_connection(
			assignment.socket,
			{
				header = {type = .AuthSuccess, id = assignment.tcp_id},
				payload = poly.AuthSuccess{success = true, message = "welcome to rome!"},
			},
		)
	} else {
		assignment.tcp_id, _ = poly.send_connection(
			assignment.socket,
			{
				header = {type = .AuthSuccess, id = assignment.tcp_id},
				payload = poly.AuthSuccess{success = false, message = "password does not match"},
			},
		)
		net.close(assignment.socket)
		return
	}

	for assignment.running^ {
		packet: poly.Packet
		recv_err: poly.TCP_Err
		packet, assignment.tcp_id, recv_err = poly.recv_connection(assignment.socket)
		defer delete(packet.raw_payload)

		if recv_err != nil do break

		if packet.header.type == .Disconnect do break

		#partial switch p in packet.payload {
		case poly.TimeoutResponse:
			if p.connected do assignment.status = .WORKING
		case poly.TaskRequest:
			amount := assign_range(p.amount, assignment)

			fmt.println("requested:", p.amount, "- given:", p.amount)
			poly.print_range(assignment.queue.assigned_ranges[assignment.socket])
			assignment.tcp_id, _ = poly.send_connection(
				assignment.socket,
				{
					header = {type = .TaskResponse, id = assignment.tcp_id},
					payload = poly.TaskResponse {
						amount = amount,
						size = u64(assignment.size),
						start = assignment.queue.assigned_ranges[assignment.socket].start,
						stop = assignment.queue.assigned_ranges[assignment.socket].stop,
					},
				},
			)
		}

	}

	sync.lock(&assignment.queue.mutex)
	assignment.status = .DISCONNECTED
	sync.unlock(&assignment.queue.mutex)
	return
}

assign_range :: proc(amount: u64, assignment: ^Assignment) -> (a: u64) {
	fmt.println("assigning range:", amount)

	poly.print_range(assignment.queue.unchecked_ranges[0])

	q := assignment.queue
	sync.lock(&q.mutex)

	if len(q.unchecked_ranges) <= 0 {
		fmt.println("no range found")
		sync.unlock(&q.mutex)
		return
	}

	cur_range := 0
	range: poly.Range

	range_length := poly.space_in_range(q.unchecked_ranges[cur_range], amount)
	if range_length <= amount {
		range = poly.clone_range(q.unchecked_ranges[cur_range])
		poly.destroy_range(&q.unchecked_ranges[cur_range])
		unordered_remove(&q.unchecked_ranges, cur_range)

		q.assigned_ranges[assignment.socket] = range

		sync.unlock(&q.mutex)
		return range_length
	}

	range.start = poly.clone_polyomino(q.unchecked_ranges[cur_range].start)

	outer: for i in 0 ..< amount {
		if cur_range >= len(q.unchecked_ranges) {
			fmt.println("no range found")

			sync.unlock(&q.mutex)
			return
		}

		a += 1

		poly.inc_polyomino(&q.unchecked_ranges[cur_range].start)
		comp := poly.compare_polyomino(
			q.unchecked_ranges[cur_range].start,
			q.unchecked_ranges[cur_range].stop,
		)

		if comp == -1 {
			range.stop = poly.clone_polyomino(q.unchecked_ranges[cur_range].start)
			poly.destroy_range(&q.unchecked_ranges[cur_range])
			unordered_remove(&q.unchecked_ranges, cur_range)

			q.assigned_ranges[assignment.socket] = range

			sync.unlock(&q.mutex)
			return
		}
	}

	range.stop = poly.clone_polyomino(q.unchecked_ranges[cur_range].start)
	poly.inc_polyomino(&q.unchecked_ranges[cur_range].start)

	q.assigned_ranges[assignment.socket] = range

	sync.unlock(&q.mutex)
	return
}
