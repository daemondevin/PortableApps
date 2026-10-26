// CityHash64, as in CityHash 1.0.x by Geoff Pike and Jyrki Alakuijala
// (Copyright (c) 2011 Google, Inc., MIT license). This is the version
// Firefox uses to name its per-install registry values and folders.
#include <stdint.h>
#include <string.h>
#include "city.h"

static const uint64_t k0 = 0xc3a5c85c97cb3127ULL;
static const uint64_t k1 = 0xb492b66fbe98f273ULL;
static const uint64_t k2 = 0x9ae16a3b2f90404fULL;
static const uint64_t k3 = 0xc949d7c7509e6557ULL;

static uint64_t Fetch64(const unsigned char *p) { uint64_t r; memcpy(&r, p, 8); return r; }
static uint32_t Fetch32(const unsigned char *p) { uint32_t r; memcpy(&r, p, 4); return r; }
static uint64_t Rotate(uint64_t v, int s) { return s == 0 ? v : ((v >> s) | (v << (64 - s))); }
static uint64_t RotateByAtLeast1(uint64_t v, int s) { return (v >> s) | (v << (64 - s)); }
static uint64_t ShiftMix(uint64_t v) { return v ^ (v >> 47); }

static uint64_t Hash128to64(uint64_t lo, uint64_t hi) {
	const uint64_t kMul = 0x9ddfea08eb382d69ULL;
	uint64_t a = (lo ^ hi) * kMul;
	a ^= (a >> 47);
	uint64_t b = (hi ^ a) * kMul;
	b ^= (b >> 47);
	b *= kMul;
	return b;
}
static uint64_t HashLen16(uint64_t u, uint64_t v) { return Hash128to64(u, v); }

static uint64_t HashLen0to16(const unsigned char *s, size_t len) {
	if (len > 8) {
		uint64_t a = Fetch64(s);
		uint64_t b = Fetch64(s + len - 8);
		return HashLen16(a, RotateByAtLeast1(b + len, (int)len)) ^ b;
	}
	if (len >= 4) {
		uint64_t a = Fetch32(s);
		return HashLen16(len + (a << 3), Fetch32(s + len - 4));
	}
	if (len > 0) {
		uint8_t a = s[0], b = s[len >> 1], c = s[len - 1];
		uint32_t y = (uint32_t)a + ((uint32_t)b << 8);
		uint32_t z = (uint32_t)len + ((uint32_t)c << 2);
		return ShiftMix(y * k2 ^ z * k3) * k2;
	}
	return k2;
}

static uint64_t HashLen17to32(const unsigned char *s, size_t len) {
	uint64_t a = Fetch64(s) * k1;
	uint64_t b = Fetch64(s + 8);
	uint64_t c = Fetch64(s + len - 8) * k2;
	uint64_t d = Fetch64(s + len - 16) * k0;
	return HashLen16(Rotate(a - b, 43) + Rotate(c, 30) + d, a + Rotate(b ^ k3, 20) - c + len);
}

typedef struct { uint64_t first, second; } pair64;

static pair64 WeakHashLen32WithSeedsV(uint64_t w, uint64_t x, uint64_t y, uint64_t z, uint64_t a, uint64_t b) {
	a += w;
	b = Rotate(b + a + z, 21);
	uint64_t c = a;
	a += x;
	a += y;
	b += Rotate(a, 44);
	pair64 r = { a + z, b + c };
	return r;
}
static pair64 WeakHashLen32WithSeeds(const unsigned char *s, uint64_t a, uint64_t b) {
	return WeakHashLen32WithSeedsV(Fetch64(s), Fetch64(s + 8), Fetch64(s + 16), Fetch64(s + 24), a, b);
}

static uint64_t HashLen33to64(const unsigned char *s, size_t len) {
	uint64_t z = Fetch64(s + 24);
	uint64_t a = Fetch64(s) + (len + Fetch64(s + len - 16)) * k0;
	uint64_t b = Rotate(a + z, 52);
	uint64_t c = Rotate(a, 37);
	a += Fetch64(s + 8);
	c += Rotate(a, 7);
	a += Fetch64(s + 16);
	uint64_t vf = a + z;
	uint64_t vs = b + Rotate(a, 31) + c;
	a = Fetch64(s + 16) + Fetch64(s + len - 32);
	z = Fetch64(s + len - 8);
	b = Rotate(a + z, 52);
	c = Rotate(a, 37);
	a += Fetch64(s + len - 24);
	c += Rotate(a, 7);
	a += Fetch64(s + len - 16);
	uint64_t wf = a + z;
	uint64_t ws = b + Rotate(a, 31) + c;
	uint64_t r = ShiftMix((vf + ws) * k2 + (wf + vs) * k0);
	return ShiftMix(r * k0 + vs) * k2;
}

uint64_t CityHash64(const void *data, size_t len) {
	const unsigned char *s = (const unsigned char *)data;
	if (len <= 32) {
		if (len <= 16) return HashLen0to16(s, len);
		return HashLen17to32(s, len);
	}
	if (len <= 64) return HashLen33to64(s, len);
	uint64_t x = Fetch64(s + len - 40);
	uint64_t y = Fetch64(s + len - 16) + Fetch64(s + len - 56);
	uint64_t z = HashLen16(Fetch64(s + len - 48) + len, Fetch64(s + len - 24));
	pair64 v = WeakHashLen32WithSeeds(s + len - 64, len, z);
	pair64 w = WeakHashLen32WithSeeds(s + len - 32, y + k1, x);
	x = x * k1 + Fetch64(s);
	len = (len - 1) & ~(size_t)63;
	do {
		x = Rotate(x + y + v.first + Fetch64(s + 8), 37) * k1;
		y = Rotate(y + v.second + Fetch64(s + 48), 42) * k1;
		x ^= w.second;
		y += v.first + Fetch64(s + 40);
		z = Rotate(z + w.first, 33) * k1;
		v = WeakHashLen32WithSeeds(s, v.second * k1, x + w.first);
		w = WeakHashLen32WithSeeds(s + 32, z + w.second, y + Fetch64(s + 16));
		uint64_t t = z; z = x; x = t;
		s += 64;
		len -= 64;
	} while (len != 0);
	return HashLen16(HashLen16(v.first, w.first) + ShiftMix(y) * k1 + z, HashLen16(v.second, w.second) + x);
}
