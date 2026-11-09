# QEMU for "Test in QEMU"

The app's "Test in QEMU" button boots a ISOrack drive in this copy of QEMU.
It is not kept in git (around 150 MB). Fill this folder before building the
installer:

    powershell -ExecutionPolicy Bypass -File tools\fetch-qemu.ps1

The script downloads Stefan Weil's QEMU for Windows build, checks it against
the published SHA-512, and keeps only what x86_64 test boots need. Without
it the app falls back to a QEMU installed in Program Files\qemu.

QEMU is GPLv2 licensed; its license files are copied here with it.
