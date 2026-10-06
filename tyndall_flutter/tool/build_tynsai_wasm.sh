#!/bin/sh
set -eu

APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKSPACE_DIR=$(dirname "$APP_DIR")
OPENCV_VERSION=4.12.0
OPENCV_SOURCE_DIR=${OPENCV_SOURCE_DIR:-"${TMPDIR:-/tmp}/lumenmind-opencv-$OPENCV_VERSION"}
OPENCV_BUILD_DIR=${OPENCV_BUILD_DIR:-"${TMPDIR:-/tmp}/lumenmind-opencv-wasm-$OPENCV_VERSION"}
WASM_DIR="$APP_DIR/web/wasm"

if ! command -v emcmake >/dev/null 2>&1 || ! command -v em++ >/dev/null 2>&1; then
  echo 'Emscripten is required. Install it with: brew install emscripten' >&2
  exit 1
fi

if [ ! -f "$OPENCV_SOURCE_DIR/CMakeLists.txt" ]; then
  git clone --depth 1 --branch "$OPENCV_VERSION" \
    https://github.com/opencv/opencv.git "$OPENCV_SOURCE_DIR"
fi

if [ ! -f "$OPENCV_BUILD_DIR/CMakeCache.txt" ]; then
  emcmake cmake -S "$OPENCV_SOURCE_DIR" -B "$OPENCV_BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DBUILD_LIST=core,imgproc,imgcodecs,ml \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_DOCS=OFF \
    -DBUILD_opencv_apps=OFF \
    -DBUILD_opencv_python3=OFF \
    -DBUILD_opencv_python2=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_ZLIB=ON \
    -DBUILD_JPEG=ON \
    -DBUILD_PNG=ON \
    -DWITH_JPEG=ON \
    -DWITH_PNG=ON \
    -DWITH_WEBP=OFF \
    -DWITH_TIFF=OFF \
    -DWITH_OPENJPEG=OFF \
    -DWITH_JASPER=OFF \
    -DWITH_OPENEXR=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_GTK=OFF \
    -DWITH_OPENGL=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_ITT=OFF \
    -DWITH_PROTOBUF=OFF \
    -DWITH_TBB=OFF \
    -DWITH_ADE=OFF \
    -DWITH_IPP=OFF \
    -DWITH_1394=OFF \
    -DWITH_V4L=OFF \
    -DCV_ENABLE_INTRINSICS=OFF \
    -DCPU_BASELINE= \
    -DCPU_DISPATCH=
fi

cmake --build "$OPENCV_BUILD_DIR" \
  --target opencv_ml opencv_imgcodecs \
  --parallel "${BUILD_JOBS:-4}"

mkdir -p "$WASM_DIR"

em++ -std=c++17 -O3 -DNDEBUG -fexceptions \
  -I"$OPENCV_SOURCE_DIR/modules/core/include" \
  -I"$OPENCV_SOURCE_DIR/modules/imgproc/include" \
  -I"$OPENCV_SOURCE_DIR/modules/imgcodecs/include" \
  -I"$OPENCV_SOURCE_DIR/modules/ml/include" \
  -I"$OPENCV_BUILD_DIR" \
  -I"$OPENCV_BUILD_DIR/modules/core" \
  -I"$OPENCV_BUILD_DIR/modules/imgproc" \
  -I"$OPENCV_BUILD_DIR/modules/imgcodecs" \
  -I"$OPENCV_BUILD_DIR/modules/ml" \
  -I"$OPENCV_SOURCE_DIR/3rdparty/libjpeg-turbo" \
  -I"$OPENCV_SOURCE_DIR/3rdparty/libpng" \
  -I"$OPENCV_SOURCE_DIR/3rdparty/zlib" \
  "$APP_DIR/wasm/tyndall_wasm_bridge.cpp" \
  "$OPENCV_BUILD_DIR/lib/libopencv_imgcodecs.a" \
  "$OPENCV_BUILD_DIR/lib/libopencv_imgproc.a" \
  "$OPENCV_BUILD_DIR/lib/libopencv_ml.a" \
  "$OPENCV_BUILD_DIR/lib/libopencv_core.a" \
  "$OPENCV_BUILD_DIR/3rdparty/lib/liblibjpeg-turbo.a" \
  "$OPENCV_BUILD_DIR/3rdparty/lib/liblibpng.a" \
  "$OPENCV_BUILD_DIR/3rdparty/lib/libzlib.a" \
  --no-entry \
  -sMODULARIZE=1 \
  -sEXPORT_ES6=1 \
  -sEXPORT_NAME=createTynsaiModule \
  -sENVIRONMENT=web \
  -sALLOW_MEMORY_GROWTH=1 \
  -sEXPORTED_FUNCTIONS=_malloc,_free,_tynsai_load_model,_tynsai_predict_image \
  -sEXPORTED_RUNTIME_METHODS=ccall \
  -sDISABLE_EXCEPTION_CATCHING=0 \
  --preload-file "$WORKSPACE_DIR/my_model.xml@/my_model.xml" \
  -o "$WASM_DIR/tyndall_detector.js"

echo "Built embedded TynsAI WASM files in $WASM_DIR"