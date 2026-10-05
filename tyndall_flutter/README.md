# LumenMind

LumenMind contains two field sessions:

- **TynsAI** analyzes uploaded Tyndall or light-beam images and estimates mass
	concentration from a user-provided calibration.
- **Light Chaser** maps nearby weather-condition anchors and tracks a visit to a
	selected anchor.

## Run

```sh
flutter pub get
flutter run -d chrome
```

The app can also be run as a macOS desktop app with `flutter run -d macos` when
Xcode and CocoaPods are installed. Android and iOS targets are included. Web
geolocation requires a secure context (HTTPS or localhost) and browser permission.

## Calibration

Choose water or air, then load an image of the blank sample and use its optical
index as the blank. Load an image of a known standard and use its index as the
standard index. Enter that standard's mass concentration in mg/L for water or
mg/m³ for air, then load the unknown sample image. Each image can be selected
from the local device; analysis is performed locally.

The displayed 0–100 optical index is a normalized image proxy calculated from
grayscale contrast, local luminance gradients, and highlight-pixel ratio. The
concentration result is a two-point linear estimate, not a validated universal
measurement. Calibrate separately for each material and fixed camera, lighting,
container, exposure, and distance setup. Results outside the calibration range
are extrapolations; do not use this app as a substitute for laboratory testing.

The existing C++ SVM model is not used: its training features include the target
concentration, while image-only inference supplies placeholder values, so it
cannot provide a defensible arbitrary-image concentration estimate.

## Light Chaser data

The map uses OpenStreetMap tiles. Open-Meteo supplies current temperature,
relative humidity, dew point, and visibility for a small grid around the device.
The app ranks those grid points as exploration anchors and can track arrival
within 100 m of a selected anchor. No API key is required. Map and weather data
are subject to their providers' terms and availability.

Weather conditions do not measure aerosol concentration or confirm that a
Tyndall effect is present. Anchor scores are an exploratory heuristic only;
users should look for a visible beam in a safe, public place and should not
enter restricted or hazardous areas.
