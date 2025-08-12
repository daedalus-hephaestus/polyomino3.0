let start_time = performance.now();

class Cell {
    constructor( u, v ) {
        this.u = u;
        this.v = v;
    }

    redelmeier_neighbors() { let neighbors = [];
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
function next_valid_string( binary_string, poly_size ) {
    let ones_count = 0; // ones found
    let next_to_test = binary_string; // the resulting next string
    let index_of_one = null; 


    for ( let count_from_end = 1; count_from_end < poly_size; count_from_end++ ) {
        for ( let i = next_to_test.length - 1; i > -1; i-- ) {
            if ( next_to_test[i] == "1" ) {
                ones_count++
            }
            if ( ones_count == count_from_end ) {
                index_of_one = i;
                break;
            }
        }
        next_to_test = next_to_test.substring(0, index_of_one) + "0" + "1".repeat(count_from_end);
				console.log(next_to_test)

        if ( is_valid_poly_string(next_to_test, poly_size) ) {
						console.log('\n')
            return next_to_test;
        } 
        ones_count = 0;
        next_to_test = binary_string;
    }
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

let poly_size = 6;
let string = "1".repeat(poly_size);
let poly_count = 0;
while ( string !== undefined ) {
    string = next_valid_string(string, poly_size);
    poly_count++
}
console.log(`Found ${poly_count} fixed ${poly_size}-ominoes in ${Math.round(performance.now() - start_time)} ms`);
