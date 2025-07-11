package polyomino

import "core:thread"
import "core:sync"
import "core:fmt"

State :: enum {
	UNCHECKED,
	VALID,
	INVALID
}

Item :: struct {
	poly: Polyomino,
	field: Field,
	is_valid: State
}

IndexQueue :: struct {
	items: [dynamic]Item,
	thread_count: int,
	wait: sync.Wait_Group,
	bar: sync.Barrier,
	mutex: sync.Mutex,
	size: int,
	type: Type,
	goto: u128,
	checked: u128,
	count: u128,
	print: u128,
	found: Polyomino,
}

destroy_queue :: proc(queue: IndexQueue) {
	for &i in queue.items {
		destroy_poly(i.poly)
		destroy_field(i.field)
	}
	destroy_poly(queue.found)
	delete(queue.items)
}

index_poly :: proc(size: int, type: Type, index: u128, print: u128, thread_count: int) -> (res: Polyomino, field: Field) {
	queue := IndexQueue{
		size = size,
		type = type,
		goto = index,
		print = print,
		thread_count = thread_count
	}
	defer destroy_queue(queue)

	threads : [dynamic]^thread.Thread

	sync.barrier_init(&queue.bar, thread_count + 1)
	sync.wait_group_add(&queue.wait, thread_count)

	init_poly := make_poly(size)
	defer destroy_poly(init_poly)

	for i in 0..<thread_count {
		append(&queue.items, Item{ poly = clone_poly(init_poly) })
		inc_poly(&init_poly)
	}	

	for i in 0..<thread_count {
		append(&threads, thread.create_and_start_with_poly_data2(
			&queue,
			i,
			index_poly_thread
		))
	}

	reader := thread.create_and_start_with_poly_data(&queue, index_poly_reader_thread)
	defer thread.destroy(reader)

	thread.join_multiple(..threads[:])
	thread.join(reader)

	for t in threads do thread.destroy(t)
	delete(threads)

	res = clone_poly(queue.found)
	return
}

index_poly_thread :: proc(queue: ^IndexQueue, id: int) {
	for queue.count <= queue.goto {
		cur := queue.items[id]

		err : PolyErr
		err, cur.field = valid_poly(cur.poly, queue.type, queue.size)

		queue.items[id].is_valid = err == .VALID ? .VALID : .INVALID
		
		sync.wait_group_done(&queue.wait)
		sync.barrier_wait(&queue.bar)

		if queue.count >= queue.goto do break
		for i in 0..<queue.thread_count do inc_poly(&queue.items[id].poly)
	}
}

index_poly_reader_thread :: proc(queue: ^IndexQueue) {
	outer: for queue.count <= queue.goto {
		sync.wait_group_wait(&queue.wait)

		for item in queue.items {
			queue.checked += 1

			if item.is_valid == .VALID {
				queue.count += 1

				if queue.count == queue.goto {
					queue.found = clone_poly(item.poly)
					fmt.printfln("checked: %v, found: %v", queue.checked, queue.count)
					print_field(item.field)
					sync.barrier_wait(&queue.bar)
					break outer
				}
			}
		}

		sync.wait_group_add(&queue.wait, queue.thread_count)
		sync.barrier_wait(&queue.bar)
	}
}
