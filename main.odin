#+feature dynamic-literals

package polyomino

import "core:fmt"
import "core:mem"
import "core:time"

stopwatch : time.Stopwatch
Time :: [3]int

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

	time.stopwatch_start(&stopwatch)
	poly, field := index_poly(20, .FIXED, 1000000, 0, 32)
	defer destroy_poly(poly)
	defer destroy_field(field)


	time.stopwatch_stop(&stopwatch)
	t := get_time(stopwatch)
	print_time(t)

} 

get_time :: proc(watch: time.Stopwatch) -> Time {
	h, m, s := time.clock_from_stopwatch(watch)
	return {h, m, s}
}

print_time :: proc(t: Time) {
	fmt.printfln("%vh %vm %vs", t[0], t[1], t[2])
}
