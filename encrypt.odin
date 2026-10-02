package polyomino

import "core:crypto/legacy/sha1"
import "core:crypto"
import "core:fmt"

encrypt_password :: proc(plain: string, auth_data: [20]u8) -> (res: [sha1.DIGEST_SIZE]u8) {
	stage1: [sha1.DIGEST_SIZE]u8
	stage2: [sha1.DIGEST_SIZE]u8
	digest: [sha1.DIGEST_SIZE]u8
	ctx: sha1.Context

	sha1.init(&ctx)
	plain_bytes := transmute([]u8)plain
	sha1.update(&ctx, plain_bytes)
	sha1.final(&ctx, stage1[:])

	sha1.init(&ctx)
	sha1.update(&ctx, stage1[:])
	sha1.final(&ctx, stage2[:])

	sha1.init(&ctx)
	auth_data_bytes := auth_data
	sha1.update(&ctx, auth_data_bytes[:20])
	sha1.update(&ctx, stage2[:])
	sha1.final(&ctx, digest[:])

	token: [sha1.DIGEST_SIZE]u8
	for i in 0 ..< sha1.DIGEST_SIZE {
		token[i] = stage1[i] ~ digest[i]
	}

	return token
}

auth_data :: proc() -> (res: [20]u8) {
	bytes : [20]u8
	crypto.rand_bytes(bytes[:])

	return bytes
}
