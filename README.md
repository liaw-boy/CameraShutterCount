# Camera Shutter Count for macOS

A native macOS application designed to inspect and read camera shutter actuation counts across major camera brands (Canon, Nikon, Sony, Fujifilm, and more), built with Swift, SwiftUI, and ImageCaptureCore.

---

## Key Features

1. Multi-Brand Lineup Support:
   - Canon DSLRs & Mirrorless: Native MPU Monitor vendor channel (0x9052 / 0x9053) for modern bodies (5D4, 80D, 90D, 1DX2/3), PTP property 0xD1AC for legacy bodies (5D2, 5D3, 6D, 7D), and CR3 RAW file inspection for EOS R series.
   - Nikon DSLRs & Mirrorless: PTP property 0xD100 support and universal EXIF MakerNotes parsing (NEF / JPG).
   - Sony Alpha Series: Direct EXIF MakerNotes parsing (ARW / JPG) and PTP identification.
   - Universal RAW & JPEG: Drag-and-drop inspection for CR3, CR2, NEF, ARW, RAF, DNG, and JPG.

2. Hardware Safety Guardrails:
   - Hardcoded read-only whitelist refusing all firmware/EEPROM writing commands (MonWrite, FA_SetProperty, etc.).
   - Guaranteed MonClose teardown using Swift defer to prevent camera Err 70 lockouts.

3. Native macOS Experience:
   - Built on Apple's ImageCaptureCore framework with zero third-party drivers or kernel conflicts.
   - Real-time actuation gauge, rated shutter durability percentage, mirror actuation counters, and live PTP protocol logs.
   - Zero emojis in the user interface; built strictly with native Apple SF Symbols and typography.

---

## Build and Run

### Run the App Bundle
You can launch the pre-packaged application directly:
```bash
open CameraShutterCount.app
```
Or move it to `/Applications` for system-wide access.

### Compile from Source
```bash
cd /Users/boywei/project_code/CameraShutterCount
./package_app.sh
```

### Run Unit Tests
```bash
swift test
```
