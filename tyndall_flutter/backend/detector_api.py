#!/usr/bin/env python3
import csv
import json
import os
import shutil
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
WORKSPACE_DIR = APP_DIR.parent
SOURCE_PATH = WORKSPACE_DIR / 'tyndall_detector.cpp'
MODEL_PATH = WORKSPACE_DIR / 'my_model.xml'
BUILD_DIR = APP_DIR / 'backend' / '.build'
DETECTOR_PATH = BUILD_DIR / 'tyndall_detector'
MAX_IMAGE_BYTES = 25 * 1024 * 1024


def opencv_prefix():
    configured = os.environ.get('OPENCV_PREFIX')
    candidates = [Path(configured)] if configured else []
    if shutil.which('brew'):
        for formula in ('opencv', 'opencv@4'):
            result = subprocess.run(
                ['brew', '--prefix', formula], capture_output=True, text=True
            )
            if result.returncode == 0:
                candidates.append(Path(result.stdout.strip()))
    for prefix in candidates:
        if (prefix / 'include' / 'opencv5' / 'opencv2' / 'opencv.hpp').exists():
            return prefix, prefix / 'include' / 'opencv5'
        if (prefix / 'include' / 'opencv4' / 'opencv2' / 'opencv.hpp').exists():
            return prefix, prefix / 'include' / 'opencv4'
    raise RuntimeError(
        'OpenCV development headers were not found. Install Homebrew OpenCV or set OPENCV_PREFIX.'
    )


def build_detector():
    if not SOURCE_PATH.exists() or not MODEL_PATH.exists():
        raise RuntimeError('tyndall_detector.cpp or my_model.xml is missing from the workspace root.')
    if DETECTOR_PATH.exists() and DETECTOR_PATH.stat().st_mtime >= SOURCE_PATH.stat().st_mtime:
        return
    compiler = shutil.which('clang++')
    if compiler is None:
        raise RuntimeError('clang++ is required to build the existing TynsAI detector.')
    prefix, include_dir = opencv_prefix()
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    command = [
        compiler,
        '-std=c++17',
        f'-I{include_dir}',
        f'-L{prefix / "lib"}',
        f'-Wl,-rpath,{prefix / "lib"}',
        str(SOURCE_PATH),
        '-lopencv_highgui',
        '-lopencv_imgcodecs',
        '-lopencv_imgproc',
        '-lopencv_ml',
        '-lopencv_core',
        '-o',
        str(DETECTOR_PATH),
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f'Could not build the existing detector:\n{result.stderr[-4000:]}')


class DetectorHandler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        data = json.dumps(payload).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, X-Filename')
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, X-Filename')
        self.send_header('Access-Control-Max-Age', '600')
        self.end_headers()

    def do_GET(self):
        if self.path == '/health':
            self._send_json(200, {'ready': DETECTOR_PATH.exists()})
            return
        self._send_json(404, {'error': 'Route not found.'})

    def do_POST(self):
        if self.path != '/predict':
            self._send_json(404, {'error': 'Route not found.'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if length <= 0 or length > MAX_IMAGE_BYTES:
                self._send_json(413, {'error': 'Choose an image smaller than 25 MB.'})
                return
            image_bytes = self.rfile.read(length)
            suffix = Path(self.headers.get('X-Filename', 'image.jpg')).suffix.lower()
            if suffix not in {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tif', '.tiff'}:
                suffix = '.jpg'
            with tempfile.TemporaryDirectory(prefix='lumenmind-tynsai-') as directory:
                temporary_dir = Path(directory)
                image_path = temporary_dir / f'upload{suffix}'
                input_csv = temporary_dir / 'input.csv'
                output_csv = temporary_dir / 'output.csv'
                image_path.write_bytes(image_bytes)
                with input_csv.open('w', newline='', encoding='utf-8') as csv_file:
                    writer = csv.writer(csv_file)
                    writer.writerow([
                        'image_path', 'original_percentage', 'concentration_percentage',
                        'sensor_lux', 'sensor_ir', 'sensor_visible', 'solution_type',
                    ])
                    writer.writerow([str(image_path), '0', '100', '0', '0', '0', 'uploaded'])
                result = subprocess.run(
                    [str(DETECTOR_PATH), 'predict_csv', str(input_csv), str(MODEL_PATH), str(output_csv)],
                    cwd=WORKSPACE_DIR,
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                if result.returncode != 0:
                    raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Detector failed.')
                with output_csv.open(newline='', encoding='utf-8') as csv_file:
                    rows = list(csv.DictReader(csv_file))
                if not rows or not rows[0].get('Predicted_Mass_Percentage'):
                    raise RuntimeError('The detector could not read or predict this image.')
                percentage = rows[0]['Predicted_Mass_Percentage']
                output = (
                    '\nPrediction Result\n'
                    f'Predicted Mass Percentage: {percentage}%\n'
                    'Image-only prediction (no sensor data)\n'
                )
            self._send_json(200, {'output': output})
        except subprocess.TimeoutExpired:
            self._send_json(504, {'error': 'The detector timed out while processing this image.'})
        except Exception as error:
            self._send_json(500, {'error': str(error)})

    def log_message(self, format_string, *args):
        print(f'[TynsAI API] {format_string % args}')


def main():
    build_detector()
    server = ThreadingHTTPServer(('127.0.0.1', int(os.environ.get('TYNSAI_PORT', '8765'))), DetectorHandler)
    print(f'TynsAI detector API is ready at http://127.0.0.1:{server.server_port}')
    print(f'Using source: {SOURCE_PATH}')
    print(f'Using model: {MODEL_PATH}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopping TynsAI detector API.')
    finally:
        server.server_close()


if __name__ == '__main__':
    main()