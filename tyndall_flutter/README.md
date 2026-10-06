# LumenMind

LumenMind contains two field sessions:

- **TynsAI** uploads an image to the existing `tyndall_detector.cpp` and displays
	the original detector output without another calculation.
- **Light Chaser** maps nearby weather-condition anchors and tracks a visit to a
	selected anchor.

## Run

Build the embedded TynsAI WebAssembly module once, then launch Flutter:

```sh
cd "/Users/harryliu/Desktop/LumenMind App/tyndall_flutter"
sh tool/build_tynsai_wasm.sh
sh run_lumenmind.sh
```

The WASM build needs Emscripten, CMake, Git, and network access to fetch OpenCV
4.12. It compiles the original `tyndall_detector.cpp` with OpenCV's `core`,
`imgproc`, `imgcodecs`, and `ml` modules and packages the workspace-root
`my_model.xml` into the browser module. The `tyndall_detector.cpp` `predict()`
implementation is unchanged; only its GUI and command-line entry points are
excluded from the Web build. After the build, predictions run locally in the
browser with no detector API or CORS configuration.

The app can also be run as a macOS desktop app with `flutter run -d macos` when
Xcode and CocoaPods are installed. Android and iOS targets are included. Web
geolocation requires a secure context (HTTPS or localhost) and browser permission.

TynsAI passes uploaded image bytes directly to the WASM detector, which uses
OpenCV `imdecode`, the existing 800-pixel resize behavior, and the original
image-only `predict()` method. It returns the original prediction text format.

The original detector's model and prediction behavior are unchanged. Its
accuracy and limitations are those of the existing model.

## Publish to Vercel

Build WASM before building Flutter Web. The generated
`web/wasm/tyndall_detector.js`, `.wasm`, and `.data` files are static assets and
must be included in the Vercel deployment. Build them locally and include those
three files in the repository; Vercel only needs to run the Flutter Web build.
No API URL, server process, or CORS allowlist is needed for TynsAI.

```sh
sh tool/build_tynsai_wasm.sh
flutter build web --release
```

Deploy `build/web` to Vercel. The prebuilt WASM assets are served with the Flutter
site and execute inside each visitor's browser.

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
