# LumenMind

LumenMind contains two field sessions:

- **TynsAI** uploads an image to the existing `tyndall_detector.cpp` and displays
	the original detector output without another calculation.
- **Light Chaser** maps nearby weather-condition anchors and tracks a visit to a
	selected anchor.

## Run

Run the bridge and Flutter together:

```sh
cd "/Users/harryliu/Desktop/LumenMind App/tyndall_flutter"
sh run_lumenmind.sh
```

The bridge compiles the workspace-root `tyndall_detector.cpp` against the
installed Homebrew OpenCV, uses the workspace-root `my_model.xml`, and listens
on `127.0.0.1:8765`. Stop both processes with `Ctrl+C`.

The app can also be run as a macOS desktop app with `flutter run -d macos` when
Xcode and CocoaPods are installed. Android and iOS targets are included. Web
geolocation requires a secure context (HTTPS or localhost) and browser permission.

TynsAI passes the uploaded image through the existing `predict_csv` command,
which calls the same C++ `predict()` method with zero sensor readings as the
image-only CLI path. This avoids the original GUI window while preserving the
model, features, and `Prediction Result` text. The generated native executable
is stored in `backend/.build/`; the existing `tyndall` binary is not modified.

The original detector's model and prediction behavior are unchanged. Its
accuracy and limitations are those of the existing model.

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
