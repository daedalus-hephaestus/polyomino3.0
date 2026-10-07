package polyomino

import "core:fmt"
import "core:mem"

Polyomino :: distinct [dynamic]u128
PolyominoType :: enum {
	FIXED,
	FREE,
}

Range :: struct {
	start: Polyomino,
	stop:  Polyomino,
}

destroy_range :: proc(range: ^Range, allocator: mem.Allocator = context.allocator) {
	destroy_polyomino(range.start, allocator)
	destroy_polyomino(range.stop, allocator)
}

print_range :: proc(range: Range) {
	print_polyomino(range.start)
	print_polyomino(range.stop)
}

encode_polyomino :: proc(poly: Polyomino) -> (res: [dynamic]u8) {
	len := len(poly)
	append_int(&res, u64(len))

	for i in 0 ..< len {
		append_u128(&res, poly[i])
	}

	return
}

print_polyomino :: proc(poly: Polyomino) {
	fmt.println("Polyomino binary:")
	for i in poly {
		for j in 0 ..< 128 {
			fmt.print(i & (u128(1) << u128(127 - j)) != 0 ? "1" : "0")
		}
		fmt.println()
	}
}

append_polyomino :: proc(array: ^[dynamic]u8, poly: Polyomino) {
	bytes := encode_polyomino(poly)
	defer delete(bytes)
	append(array, ..bytes[:])
}

// returns a polyomino from the buffer starting at i
// returns ok = false if i + polyomino length is outside of the buffer's range
decode_polyomino :: proc(i: int, buff: []u8) -> (res: Polyomino, ok: bool) {
	length, i := decode_int_inc(i, buff[:]) or_return

	if u64(len(buff[i:])) < length * 16 do return

	for j in 0 ..< length {
		segment := read_u128(i, buff) or_return
		append(&res, segment)
		i += 16
	}

	ok = true
	res = Polyomino(res)
	return
}

// returns a polyomino from the buffer starting at i
// returns i + the encoded length as index
// returns ok = false if i + polyomino length is outside of the buffer's range
decode_polyomino_inc :: proc(i: int, buff: []u8) -> (res: Polyomino, index: int, ok: bool) {
	length, start := decode_int_inc(i, buff[:]) or_return

	if u64(len(buff[start:])) < length * 16 do return

	for j in 0 ..< length {
		segment := read_u128(start, buff) or_return
		append(&res, segment)
		start += 16
	}

	index = i + start - 2
	ok = true
	return
}

destroy_polyomino :: proc(poly: Polyomino, allocator: mem.Allocator = context.allocator) {
	delete(poly)
}

min_polyomino :: proc(size: int) -> Polyomino {
	count := (size + 127) / 128
	res := make(Polyomino, count)

	for i in 0 ..< count {
		res[i] = ~u128(0)
	}

	if size % 128 != 0 {
		res[count - 1] = (u128(1) << u128(size % 128)) - 1
	}

	return res
}

max_polyomino :: proc(size: int) -> (Polyomino) {
	res := make(Polyomino, ((size * 3 - 1) + 127) / 128)

	for i in 0 ..< size {
		bit := 0
		if i == 1 {
			bit = 2
		} else if i >= 2 {
			bit = 2 + (i - 1) * 3
		}

		word := bit / 128
		offset := bit % 128

		res[word] |= u128(1) << u128(offset)
	}

	return res
}


dec_polyomino :: proc(poly: ^Polyomino) -> bool {
	i := 0
	for {
		new_val := poly[i] - 1
		if new_val > poly[i] {
			if len(poly) - 1 == i {
				return true
			} else {
				poly[i] = new_val
				i += 1
			}
		} else {
			poly[i] = new_val 
			return false
		}
	}
}

inc_polyomino :: proc(poly: ^Polyomino) {
	i := 1
	move_ones := 1
	// Get the first 1 that is followed by a 0, and shift it to the left
	// e.g. 101101 -> 110101 (first one is ignored)
	for {
		cur_carry := (i) / 128
		next_carry := (i + 1) / 128
		if len(poly) == next_carry do append(poly, 0)

		cur := poly[cur_carry] >> uint(i - 128 * cur_carry) & 1
		next := poly[next_carry] >> uint((i - 128 * next_carry) + 1) & 1

		if cur == 1 {
			if next == 0 {
				poly[next_carry] |= u128(1) << uint((i - 128 * next_carry) + 1)
				break
			}
			move_ones += 1
		}

		i += 1
	}
	max_index := i / 128 + 1
	// Shifts all of the ones to the right which are before the previously moved 1
	// e.g. 110101 -> 110011
	for cur in 0..<max_index {
		if cur != max_index - 1 {
			poly[cur] = 0
		} else {
			shift := uint(i - 128 * cur) + 1
			poly[cur] = poly[cur] >> shift << shift
		}

		if move_ones >= 128 {
			poly[cur] = max(u128)
			move_ones -= 128
		} else {
			poly[cur] |= max(u128) >> uint(128 - move_ones)
		}
	}
}

clone_polyomino :: proc(poly: Polyomino) -> Polyomino {
	res : Polyomino
	for i in poly do append(&res, i)
	return res
}

// if the first is greater than the second, return 0
// if the first is less than the second, return 1
compare_polyomino :: proc(poly0: Polyomino, poly1: Polyomino) -> int {
	l0 := len(poly0)
	l1 := len(poly1)

	if l0 < l1 && poly1[l1 - 1] > 0 {
		return 0
	} else if l0 > l1 && poly0[l0 - 1] > 0 {
		return 1
	}

	smaller_len := l0 >= l1 ? l1 : l0
	s0 := poly0[:smaller_len]
	s1 := poly1[:smaller_len]

	for i := smaller_len - 1; i > -1; i -= 1 {
		if s0[i] == s1[i] {
	continue
		} else if s0[i] < s1[i] {
			return 0 
		} else if s0[i] > s1[i] {
			return 1 
		}
	}
	return -1
}
