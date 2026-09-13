# RISC-V UART Downloader

This Windows utility uses the native file-selection dialog and serial API. Use
the raw `.bin` application image: `.mem` is text intended for SystemVerilog
`$readmemh` and may contain address records, so it is not suitable for this
byte-stream protocol.

Build with MinGW-w64:

```powershell
g++ -std=c++17 -O2 -Wall -Wextra util/downloader.cpp -o util/downloader.exe -lcomdlg32
```

Or build from a Visual Studio developer command prompt:

```powershell
cl /std:c++17 /EHsc util\downloader.cpp /Fe:util\downloader.exe comdlg32.lib
```

Build the user application, then provide the COM port and baud rate. When no
`--file` option is supplied, the downloader opens the file-selection window:

```powershell
make c PRGM=gpio
util\downloader.exe -p COM5 -b 115200
```

The `.bin` path can instead be provided directly:

```powershell
util\downloader.exe -p COM5 -b 115200 -f build\gpio.bin
```

Long options are also accepted:

```powershell
util\downloader.exe --port COM5 --baud 115200 --file build\gpio.bin
```

Running `downloader.exe` without the required arguments displays a Windows
message box containing this usage information. The utility sends `0xFF`, waits
for `0xFE`, then sends the four-byte little-endian image size, the four-byte
little-endian IEEE CRC-32, and the raw image. It rejects images larger than the
28 KiB application region at `0x00001000`.

After receiving the image, the bootloader returns `0xFD` on successful CRC
verification, `0xFC` on a CRC mismatch, or `0xFB` for an invalid image size.
