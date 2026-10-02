package polyomino

import "core:fmt"

Polyomino :: distinct []u128
PolyominoType :: enum {
	FIXED,
	FREE
}

Range :: struct {
	start: Polyomino,
	stop: Polyomino
}

destroy_range :: proc(range: ^Range) {
	destroy_polyomino(range.start)
	destroy_polyomino(range.stop)
}

encode_polyomino :: proc(poly: Polyomino) -> (res: [dynamic]u8) {
	len := len(poly)
	append_int(&res, u64(len))

	for i in 0 ..< len {
		append_u128(&res, poly[i])
	}

	return
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
	tmp : [dynamic]u128

	if u64(len(buff[i:])) < length * 16 do return
	
	for j in 0..<length {
		segment := read_u128(i, buff) or_return
		append(&tmp, segment)
		i += 16
	}

	ok = true
	res = Polyomino(tmp[:])
	return
}

// returns a polyomino from the buffer starting at i
// returns i + the encoded length as index
// returns ok = false if i + polyomino length is outside of the buffer's range
decode_polyomino_inc :: proc(i: int, buff: []u8) -> (res: Polyomino, index: int, ok: bool) {
	length, start := decode_int_inc(i, buff[:]) or_return
	tmp : [dynamic]u128

	if u64(len(buff[start:])) < length * 16 do return
	
	for j in 0..<length {
		segment := read_u128(start, buff) or_return
		append(&tmp, segment)
		start += 16
	}

	index = i + start - 2
	ok = true
	res = Polyomino(tmp[:])
	return
}

destroy_polyomino :: proc(poly: Polyomino) {
	delete(poly)
}
