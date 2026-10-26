// FoxHash: an NSIS plugin (x86-unicode) for the Firefox Portable launcher.
//
//   FoxHash::InstallHash "C:\path\to\firefox folder"
//   Pop $0   ; the install hash, for example 308046B0AF4A39CB
//
// Firefox names its per-install registry values and folders after this
// hash: CityHash64 of the install folder's path in UTF-16, as upper case
// hexadecimal without leading zeros. Build:
//   i686-w64-mingw32-gcc -O2 -shared -o FoxHash.dll foxhash.c city.c
//       -Wl,--kill-at -static-libgcc
#include <windows.h>
#include "city.h"

typedef struct _stack_t {
	struct _stack_t *next;
	WCHAR text[1];
} stack_t;

static int popstring(stack_t **stacktop, WCHAR *out, int size) {
	stack_t *th;
	if (!stacktop || !*stacktop) return 1;
	th = *stacktop;
	lstrcpynW(out, th->text, size);
	*stacktop = th->next;
	GlobalFree((HGLOBAL)th);
	return 0;
}

static void pushstring(stack_t **stacktop, const WCHAR *str, int size) {
	stack_t *th;
	if (!stacktop) return;
	th = (stack_t *)GlobalAlloc(GPTR, sizeof(stack_t) + size * sizeof(WCHAR));
	lstrcpynW(th->text, str, size);
	th->next = *stacktop;
	*stacktop = th;
}

__declspec(dllexport) void __cdecl InstallHash(HWND hwnd, int string_size, WCHAR *variables, stack_t **stacktop, void *extra) {
	WCHAR *path = (WCHAR *)GlobalAlloc(GPTR, (string_size + 1) * sizeof(WCHAR));
	WCHAR out[32];
	out[0] = 0;
	if (path && popstring(stacktop, path, string_size) == 0) {
		unsigned long long h = CityHash64(path, (size_t)lstrlenW(path) * sizeof(WCHAR));
		WCHAR digits[] = L"0123456789ABCDEF";
		WCHAR tmp[17];
		int n = 0;
		do { tmp[n++] = digits[h & 0xF]; h >>= 4; } while (h && n < 16);
		for (int i = 0; i < n; i++) out[i] = tmp[n - 1 - i];
		out[n] = 0;
	}
	if (path) GlobalFree((HGLOBAL)path);
	pushstring(stacktop, out, string_size);
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
	return TRUE;
}
