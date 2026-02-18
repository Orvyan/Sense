# Sense (macOS)

Native SwiftUI app for macOS to:
- use the trackpad as an interactive scale (Force Touch pressure as input)
- display live screen tilt in degrees (when hinge data is available on the Mac)

## Run

```bash
swift build
swift run Sense
```

Or open in Xcode:

```bash
open Package.swift
```

## Usage

1. Start the app.
2. Click once in the lower `Trackpad Input Surface` area to focus input.
3. Press with Force Touch to see live weight updates.
4. Use `Tare` to zero and `Reset` to clear calibration.
5. Switch units between `g` and `N`.

## Notes

- The trackpad scale is qualitative (pressure signal), not a calibrated lab scale.
- Screen tilt uses hinge sensor data when exposed by your model.
- If hinge data is unavailable, the app shows this clearly in the UI.
