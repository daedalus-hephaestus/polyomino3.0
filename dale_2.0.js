let start_time = performance.now();

class Cell {
    constructor( u, v ) {
        this.u = u;
        this.v = v;
    }

    redelmeier_neighbors() {
        let neighbors = [];
        // down
        if ( this.v > 1 || this.v == 1 && this.u > -1 ) {
            neighbors.push(new Cell(this.u, this.v - 1));
        }
        // left
        if ( this.u != 0 || this.v != 0 ) {
            neighbors.push(new Cell(this.u - 1, this.v));
        }
        // right
        neighbors.push(new Cell(this.u + 1, this.v));
        // up
        neighbors.push(new Cell(this.u, this.v + 1));
        return neighbors;
    }
}

// poly_size could be derived from string but passing it in as parameter for tiny speed increase
function next_possible_string( binary_string, poly_size ) {

	one_zero = binary_string.indexOf('10', 1)
	if (one_zero < 0) {
		cur_length = binary_string.length
		if (cur_length + 1 > (poly_size - 1) * 3) return undefined
		binary_string = '1'.repeat(poly_size - 1).padEnd(cur_length, '0') + '1'
	} else {
	
		first_seg = binary_string.substr(0, one_zero)
		ones = (first_seg.match(/1/g) || []).length
		first_seg = '1'.repeat(ones).padEnd(first_seg.length, '0')

		binary_string = first_seg + '01' + binary_string.substr(one_zero + 2, binary_string.length - 1)
	}

	return binary_string
}

function next_valid_string( binary_string, poly_size ) {
	next_possible = next_possible_string(binary_string, poly_size)
	while (!is_valid_poly_string(next_possible)) {
		next_possible = next_possible_string(next_possible, poly_size)
		if (next_possible == undefined) return undefined
	}
	return next_possible
}

// poly_size could be derived from string but passing it in as parameter for tiny speed increase
function is_valid_poly_string( binary_string, poly_size ) {
    let checked = [new Cell(0,0)];
    let border = checked[0].redelmeier_neighbors();
    let cell_count = 1;
    for ( let i = 1; i < binary_string.length; i++ ) {
            let check_me = border[0]
            checked.push(border[0]);
            border.shift();
            if ( binary_string[i] == "1" ) {
                cell_count++
                let next_neighbors = check_me.redelmeier_neighbors();
                for ( let neighbor of next_neighbors ) {
                    if ( !includes_cell(neighbor, checked) && !includes_cell(neighbor, border) ) {
                        border.push(neighbor);
                    }
                }
            }
        if ( border.length == 0 ) {
            if ( cell_count == poly_size ) {
                return true;
            }
            else {
                return false;
            }
        }
    }
    return true;
}

function includes_cell( cell, array ) {
    return array.some(item => item.u == cell.u && item.v == cell.v);
}

function randomInt( min, max ) { 
    return Math.floor(Math.random() * (max - min + 1) + min);
}

let poly_size = 14;
let string = "1".repeat(poly_size);
let poly_count = 0;

// while (true) {
// 	string = next_possible_string(string, poly_size)
// 	if (string == undefined) {
// 		console.log(poly_count)
// 		break
// 	}
// 	poly_count++
// 	console.log(string)
// }

while ( string !== undefined) {
     string = next_valid_string(string, poly_size);
     poly_count++
}
console.log(`Found ${poly_count} fixed ${poly_size}-ominoes in ${Math.round(performance.now() - start_time)} ms`);
