package polyomino

import "core:fmt"
import "core:mem"

password := "polyominosrock"

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
	
	req := TimeoutResponse {
		connected = false
	}
	enc_req := encode_timeout_response(req)
	defer delete(enc_req)
	fmt.println(enc_req)

	
	decoded, ok := decode_timeout_response(enc_req[:])
	fmt.println(decoded, ok)

}
