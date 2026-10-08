package polyomino_client

import poly ".."
import "core:fmt"
import "core:math/bits"
import "core:sync"
import "core:thread"

State :: enum {
	UNCHECKED,
	VALID,
	INVALID,
}
FieldVal :: enum {
	OPEN,
	FULL,
	CHECKED,
}
PolyErr :: enum {
	VALID,
	WRONG_SIZE,
	ONE_OVERFLOW,
	ZERO_OVERFLOW,
}
Field :: distinct [dynamic][dynamic]FieldVal
Set :: distinct [8]poly.Polyomino
Bounds :: distinct [4]int
Cell :: distinct [2]int

// make_field creates a 2d field to store a polyomino of the given size
make_field :: proc(size: int) -> (res: Field) {
	for i in 0 ..< size {
		row := make([dynamic]FieldVal, size * 2 - 1)
		append(&res, row)
	}

	res[0][size - 1] = .FULL

	for i in 0 ..= size - 2 do res[0][i] = .CHECKED

	return res
}

// print_field prints a field into stdout
print_field :: proc(field: Field) {
	for row in field {
		for i in row {
			#partial switch i {
			case .OPEN:
				fmt.printf(".")
			case .CHECKED:
				fmt.printf("*")
			case .FULL:
				fmt.printf("#")
			}
		}
		fmt.printfln("")
	}
}

RangeItem :: struct {
	poly:     poly.Polyomino,
	field:    Field,
	is_valid: State,
	comp:     int,
}

RangeQueue :: struct {
	items:        [dynamic]RangeItem,
	range:        poly.Range,
	thread_count: int,
	wait:         sync.Wait_Group,
	bar:          sync.Barrier,
	mutex:        sync.Mutex,
	size:         int,
	type:         poly.PolyominoType,
	done:         bool,
}

destroy_range_queue :: proc(queue: ^RangeQueue) {

}

calc_range :: proc(size: int, type: poly.PolyominoType, range: poly.Range, thread_count: int) {
	queue := RangeQueue {
		size         = size,
		type         = type,
		range        = range,
		thread_count = thread_count,
	}
	defer destroy_range_queue(&queue)

	init_poly := poly.clone_polyomino(queue.range.start)
	defer poly.destroy_polyomino(init_poly)

	for i in 0 ..< thread_count {
		append(&queue.items, RangeItem{poly = poly.clone_polyomino(init_poly)})
		poly.inc_polyomino(&init_poly)
	}

	sync.barrier_init(&queue.bar, thread_count + 1)
	sync.wait_group_add(&queue.wait, thread_count)

	threads: [dynamic]^thread.Thread
	for i in 0 ..< thread_count {
		append(&threads, thread.create_and_start_with_poly_data2(&queue, i, range_poly_thread))
	}

	reader := thread.create_and_start_with_poly_data(&queue, range_reader_thread)
	defer thread.destroy(reader)

	thread.join_multiple(..threads[:])
	thread.join(reader)

	for t in threads do thread.destroy(t)
}

range_poly_thread :: proc(queue: ^RangeQueue, id: int) {
	for {
		cur := queue.items[id]
		queue.items[id].comp = poly.compare_polyomino(cur.poly, queue.range.stop)

		err: PolyErr
		err, cur.field = valid_poly(cur.poly, queue.type, queue.size)

		state: State = err == .VALID ? .VALID : .INVALID

		queue.items[id].is_valid = state
		// if state == .VALID {
		// 	queue.items[id].field = cur.field
		// 	print_field(cur.field)
		// }

		sync.wait_group_done(&queue.wait)
		sync.barrier_wait(&queue.bar)

		if queue.done do break

		for i in 0 ..< queue.thread_count do poly.inc_polyomino(&queue.items[id].poly)
	}
	fmt.println(id, "closed")
}

range_reader_thread :: proc(queue: ^RangeQueue) {
	outer: for {
		sync.wait_group_wait(&queue.wait)


		for item in queue.items {
			if item.comp == -1 {
				queue.done = true
				sync.barrier_wait(&queue.bar)

				fmt.println("goto:")
				poly.print_polyomino(queue.range.stop)

				fmt.println("current poly:")
				poly.print_polyomino(item.poly)

				break outer
			}
		}

		if queue.done {
			sync.barrier_wait(&queue.bar)
			break
		}


		sync.wait_group_add(&queue.wait, queue.thread_count)
		sync.barrier_wait(&queue.bar)

	}

	fmt.println("queue done")
}

// valid_poly returns if a polyomino of certain size and type is valid
valid_poly :: proc(
	polyomino: poly.Polyomino,
	type: poly.PolyominoType = .FIXED,
	s: int = -1,
) -> (
	err: PolyErr,
	field: Field,
) {
	field = make_field(s)

	open: [dynamic]Cell
	defer delete(open)

	bounds := Bounds{s - 2, 0, s, 1}
	field_open(field, bounds, &open)

	for seg, i in polyomino {
		seg_len := 128 - bits.count_leading_zeros(seg)

		for j: uint = 0; j < 128; j += 1 {
			if i == 0 && j == 0 do continue // skip first bit (intialized with field)
			if i == len(polyomino) - 1 && j == uint(seg_len) do break // ignore leading zeros on last segment
			if polyomino[len(polyomino) - 1] == 0 && j == uint(seg_len) && i + 2 == len(polyomino) do break // ignore leading zeros in second-to-last if last is 0

			bit := bit_at(j, seg)
			if bit == 1 {
				if len(open) == 0 {
					err = .ONE_OVERFLOW
					return
				}
				write_field(&field, &bounds, &open, .FULL)
			} else if bit == 0 {
				if len(open) == 0 {
					err = .ZERO_OVERFLOW
					return
				}
				write_field(&field, &bounds, &open, .CHECKED)
			}
		}
	}

	return
}

// field_open writes the open spaces of a field within the bounds to an array
field_open :: proc(field: Field, bounds: Bounds, open: ^[dynamic]Cell) {
	// clears the open array
	clear(open)

	// loops through the field from top to bottom
	for y := bounds[1]; y <= bounds[3]; y += 1 {
		// loops through the field from left to right
		for x := bounds[0]; x <= bounds[2]; x += 1 {
			// the value of the cell being targeted
			i := field[y][x]

			// if the cell is not open, skip to the next
			if i != .OPEN do continue

			// checks if the targeted cell has a full cell adjacent to it
			if y - 1 >= 0 && field[y - 1][x] == .FULL {
				append(open, Cell{x, y})
				continue
			} else if y + 1 < len(field) && field[y + 1][x] == .FULL {
				append(open, Cell{x, y})
				continue
			} else if x - 1 >= 0 && field[y][x - 1] == .FULL {
				append(open, Cell{x, y})
				continue
			} else if x + 1 < len(field[0]) && field[y][x + 1] == .FULL {
				append(open, Cell{x, y})
				continue
			}
		}
	}
}

// write_field writes a value to the first cell in an open array
// and resizes the bounds to match the new field
write_field :: proc(field: ^Field, bounds: ^Bounds, open: ^[dynamic]Cell, val: FieldVal) {
	cell := open[0]
	field[cell.y][cell.x] = val

	// extends the bounds depending on where the value was written
	if val == .FULL {
		if cell.x == bounds[0] && bounds[0] - 1 >= 0 do bounds[0] -= 1
		if cell.x == bounds[2] && bounds[2] + 1 < len(field[0]) do bounds[2] += 1
		if cell.y == bounds[3] && bounds[3] + 1 < len(field) do bounds[3] += 1
	}

	// re-calculates open spaces in the field
	field_open(field^, bounds^, open)
}

// bit_at returns the value of the bit at i of a unsigned 128-bit integer (b) as an integer
bit_at :: proc(i: uint, b: u128) -> int {
	shift := (b >> i) & 0b1
	return shift == 1 ? 1 : 0
}
