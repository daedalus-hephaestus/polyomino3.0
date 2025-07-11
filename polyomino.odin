package polyomino

import "core:fmt"
import "core:math/bits"

Polyomino :: [dynamic]u128
Field :: [dynamic][dynamic]FieldVal
Set :: [8]Polyomino
Bounds :: [4]int
Cell :: [2]int

Type :: enum {
	FIXED,
	FREE
}

PolyErr :: enum {
	VALID,
	WRONG_SIZE,
	ONE_OVERFLOW,
	ZERO_OVERFLOW
}

FieldVal :: enum {
	OPEN,
	FULL,
	CHECKED
}

// destroy_poly frees the memory occupied by a polyomino
destroy_poly :: proc(poly: Polyomino) {
	delete(poly)	
}

// make_poly generates a (size)-omino string of a specified length and format:
// 1. there must be as many ones as squares in the polyomino
// 2. the string must begin and end with a 1
// 3. all 1s (except the last) must be as far to the right as possible
// e.g. 1001111111 not 1010111111
make_poly :: proc(size: int, length: int=-1) -> (res: Polyomino) {
	append(&res, 0)

	seg := 0 // the current segment being edited
	write_i := uint(0) // the current index within the segment being edited

	if length <= size { // if starting from the smallest string length
		for i in 0..<size {
			if write_i > 127 {
				write_i = 0
				seg += 1
				append(&res, 1)
			}
			res[seg] |= u128(1) << write_i
			write_i += 1
		}
	} else { // if starting at a specific string length
		for i in 0..<size - 1 {
			if write_i > 127 {
				write_i = 0
				seg += 1
				append(&res, 1)
			}
			res[seg] |= u128(1) << write_i
			write_i += 1
		}
		last_carry := (length - 1) / 128
		last_write := length - (last_carry * 128) - 1

		for len(res) - 1 < last_carry do append(&res, 0)
		res[last_carry] |= u128(1) << uint(last_write)
	}
	return res
}

// inc_poly increments a polyomino to the next possible polyomino string
inc_poly :: proc(poly: ^Polyomino) {
	i := 1
	move_ones := 1

	// get the first 1 that is followed by a 0, and shift it to the left
	// e.g. 101101 -> 110101 (first one is ignored)
	for {
		seg := i / 128
		next_seg := (i + 1) / 128
		if len(poly) == next_seg do append(poly, 0)

		cur := poly[seg] >> uint(i - 128 * seg) & 1
		next := poly[next_seg] >> uint((i - 128 * next_seg) + 1) & 1

		if cur == 1 {
			if next == 0 {
				poly[next_seg] |= u128(1) << uint((i - 128 * next_seg) + 1)
				break
			}
			move_ones += 1
		}
		i += 1
	}
	max_index := i / 128 + 1

	// shifts all 1s to the right which are before the previously moved 1
	// e.g. 110101 -> 110011
	for seg in 0..<max_index {
		if seg != max_index - 1 {
			poly[seg] = 0
		} else {
			shift := uint(i - 128 * seg) + 1
			poly[seg] = poly[seg] >> shift << shift
		}
		
		if move_ones >= 128 {
			poly[seg] = max(u128)
			move_ones -= 128
		} else {
			poly[seg] |= max(u128) >> uint(128 - move_ones)
		}
	}
}

// clone_poly returns a copy of the given polyomino
clone_poly :: proc(poly: Polyomino) -> (res: Polyomino) {
	for i in poly do append(&res, i)
	return res	
}

// valid_poly returns if a polyomino of certain size and type is valid
valid_poly :: proc(poly: Polyomino, type: Type=.FIXED, s: int=-1) -> (err: PolyErr, field: Field) {
	size := poly_size(poly)
	if s >= 0 && size != s {
		err = .WRONG_SIZE
		return
	}

	field = make_field(size)

	open : [dynamic]Cell
	defer delete(open)

	bounds := Bounds{ size - 2, 0, size, 1 }
	field_open(field, bounds, &open)

	for seg, i in poly {
		seg_len := 128 - bits.count_leading_zeros(seg)

		for j : uint = 0; j < 128; j += 1 {
			if i == 0 && j == 0 do continue // skip first bit (intialized with field)
			if i == len(poly) - 1 && j == uint(seg_len) do break // ignore leading zeros on last segment
			if poly[len(poly) - 1] == 0 && j == uint(seg_len) && i + 2 == len(poly) do break // ignore leading zeros in second-to-last if last is 0

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

// bit_at returns the value of the bit at i of a unsigned 128-bit integer (b) as an integer
bit_at :: proc(i: uint, b: u128) -> int {
	shift := (b >> i) & 0b1
	return shift == 1 ? 1 : 0
}

// poly_size returns the number of squares (number of ones in the binary) in a polyomino string
poly_size :: proc(poly: Polyomino) -> (size: int) {
	for i in poly {
		size += int(bits.count_ones(i))
	}
	return size	
}

// destroy_set frees the memory occupied by a set of polyominos
destroy_set :: proc(set: ^Set) {
	for poly in set do destroy_poly(poly)
}

// make_field creates a 2d field to store a polyomino of the given size
make_field :: proc(size: int) -> ( res: Field ) {
	for i in 0..<size {
		row := make([dynamic]FieldVal, size * 2 - 1)
		append(&res, row)
	}

	res[0][size - 1] = .FULL

	for i in 0..=size - 2 do res[0][i] = .CHECKED

	return res
}

// destroy_field frees the memory occupied by a 2d polyomino field
destroy_field :: proc(field: Field) {
	for i in field do delete(i) 
	delete(field)
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
	field[cell.y][cell.x]= val

	// extends the bounds depending on where the value was written
	if val == .FULL {
		if cell.x == bounds[0] && bounds[0] - 1 >= 0 do bounds[0] -= 1
		if cell.x == bounds[2] && bounds[2] + 1 < len(field[0]) do bounds[2] += 1
		if cell.y == bounds[3] && bounds[3] + 1 < len(field) do bounds[3] += 1
	}

	// re-calculates open spaces in the field
	field_open(field^, bounds^, open)
}
