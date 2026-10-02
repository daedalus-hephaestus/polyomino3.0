package polyomino

import "core:fmt"

// encodes an integer as a length encoded integer
encode_int :: proc(val: u64) -> (res: [dynamic]u8) {
	switch {
	case val < 0xfb:
		append(&res, u8(val))
	case val <= 0xffff:
		append(&res, 0xfc)
		append_u16(&res, u16(val))
	case val <= 0xffffff:
		append(&res, 0xfd)
		append_u24(&res, u32(val))
	case:
		append(&res, 0xfe)
		append_u64(&res, val)
	}
	return
}

// appends a length encoded integer to the buffer
append_int :: proc(array: ^[dynamic]u8, val: u64) {
	bytes := encode_int(val)
	defer delete(bytes)
	append(array, ..bytes[:])
}

// returns a length encoded u64 from the buffer starting at i
// returns ok = false if i + the encoded length is outside of the buffer's range
decode_int :: proc(i: int, buff: []u8) -> (res: u64, ok: bool) {
	if i > len(buff) - 1 {
		return
	}

	switch {
	case buff[i] < 0xfb:
		res = u64(buff[i])
		ok = true
	case buff[i] == 0xfc:
		res = u64(read_u16(i + 1, buff) or_return)
		ok = true
	case buff[i] == 0xfd:
		res = u64(read_u24(i + 1, buff) or_return)
		ok = true
	case buff[i] == 0xfe:
		res = u64(read_u64(i + 1, buff) or_return)
		ok = true
	}

	return
}

// returns a length encoded u64 from the buffer starting at i
// returns i + the encoded length as index
// returns ok = false if i + the encoded length is outside of the buffer's range
decode_int_inc :: proc(i: int, buff: []u8) -> (res: u64, index: int, ok: bool) {
	if i > len(buff) - 1 {
		return
	}

	switch {
	case buff[i] < 0xfb:
		res = u64(buff[i])
		index = i + 1
		ok = true
	case buff[i] == 0xfc:
		res = u64(read_u16(i + 1, buff) or_return)
		index = i + 3
		ok = true
	case buff[i] == 0xfd:
		res = u64(read_u24(i + 1, buff) or_return)
		index = i + 4
		ok = true
	case buff[i] == 0xfe:
		res = u64(read_u64(i + 1, buff) or_return)
		index = i + 8
		ok = true
	}

	return
}

// encodes a string as a length encoded array of bytes
encode_str :: proc(str: string) -> (res: [dynamic]u8) {
	bytes := transmute([]byte)str

	len_bytes := encode_int(u64(len(bytes)))
	defer delete(len_bytes)

	append(&res, ..len_bytes[:])
	append(&res, ..bytes)

	return
}

// appends a length encoded string to the buffer
append_str :: proc(array: ^[dynamic]u8, str: string) {
	bytes := encode_str(str)
	defer delete(bytes)
	append(array, ..bytes[:])
}

// returns a length encoded string from the buffer starting at i
// returns ok = false if i + the encoded length is outside of the buffer's range
decode_str :: proc(i: int, buff: []u8) -> (res: string, ok: bool) {
	length, index := decode_int_inc(i, buff) or_return

	if index + int(length) > len(buff) {
		return
	}

	res = string(buff[index:index + int(length)])
	ok = true

	return
}

// returns a length encoded string from the buffer starting at i
// returns ok = false if i + the encoded length is outside of the buffer's range
decode_str_inc :: proc(i: int, buff: []u8) -> (res: string, index: int, ok: bool) {
	length, str_start := decode_int_inc(i, buff) or_return

	if index + int(length) > len(buff) {
		return
	}

	res = string(buff[str_start:str_start + int(length)])
	ok = true
	index = str_start + int(length)

	return
}

// appends a u16 to a byte array (Little Endian)
append_u16 :: proc(array: ^[dynamic]u8, val: u16) {
	bytes: []u8
	append(array, u8(val), u8(val >> 8) & 0xff)
}

// append a u24 to a byte array (Little Endian)
append_u24 :: proc(array: ^[dynamic]u8, val: u32) {
	append(array, u8(val), u8(val >> 8) & 0xff, u8(val >> 16) & 0xff)
}

// appends a u32 to a byte array (Little Endian)
append_u32 :: proc(array: ^[dynamic]u8, val: u32) {
	append(array, u8(val), u8(val >> 8) & 0xff, u8(val >> 16) & 0xff, u8(val >> 24) & 0xff)
}

// appends a u64 to a byte array (Little Endian)
append_u64 :: proc(array: ^[dynamic]u8, val: u64) {
	res: [8]u8
	for i: uint = 0; i < 8; i += 1 {
		res[i] = u8(val >> (i * 8)) & 0xff
	}

	append(array, ..res[:])
}

// appends a u128 to a byte array (Little Endian)
append_u128 :: proc(array: ^[dynamic]u8, val: u128) {
	res: [16]u8
	for i: uint = 0; i < 16; i += 1 {
		res[i] = u8(val >> (i * 8)) & 0xff
	}

	append(array, ..res[:])
}

// reads a u16 from a buffer (Little Endian) at i
read_u16 :: proc(i: int, buff: []u8) -> (res: u16, ok: bool) {
	if i + 1 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 2 {
		res |= u16(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u24 from a buffer (Little Endian) at i
read_u24 :: proc(i: int, buff: []u8) -> (res: u32, ok: bool) {
	if i + 2 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 3 {
		res |= u32(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u32 from a buffer (Little Endian) at i
read_u32 :: proc(i: int, buff: []u8) -> (res: u32, ok: bool) {
	if i + 3 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 4 {
		res |= u32(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u64 from a buffer (Little Endian) at i
read_u64 :: proc(i: int, buff: []u8) -> (res: u64, ok: bool) {
	if i + 7 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0 ..< 8 {
		res |= u64(buff[i + j]) << uint(8 * j)
	}
	return
}

// reads a u128 from a buffer (Little Endian) at i
read_u128 :: proc(i: int, buff: []u8) -> (res: u128, ok: bool) {
	if i + 15 > len(buff) - 1 {
		ok = false
		return
	} else {
		ok = true
	}

	for j in 0..<16 {
		res |= u128(buff[i + j]) << uint(8 *  j)
	}
	return
}
