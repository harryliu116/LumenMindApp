import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'light_chaser.dart';

const _ink = Color(0xFF192B27);
const _muted = Color(0xFF6F7D77);
const _green = Color(0xFFF2C94C);
const _lime = Color(0xFFFFE79A);
const _paper = Color(0xFFF8F6EF);
const _line = Color(0xFFEAE3D0);

class LumenMindApp extends StatelessWidget {
  const LumenMindApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LumenMind',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _paper,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE2B528),
            brightness: Brightness.light,
            surface: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF7F9F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD2A700), width: 1.5),
            ),
          ),
        ),
        home: const _LumenMindShell(),
      );
}

class _LumenMindShell extends StatefulWidget {
  const _LumenMindShell();

  @override
  State<_LumenMindShell> createState() => _LumenMindShellState();
}

class _LumenMindShellState extends State<_LumenMindShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _selectedIndex == 0
            ? const TynsAiSession()
            : const LightChaserSession(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          indicatorColor: const Color(0xFFFFE79A),
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: 'TynsAI',
            ),
            NavigationDestination(
              icon: Icon(Icons.light_mode_outlined),
              selectedIcon: Icon(Icons.light_mode),
              label: 'Light Chaser',
            ),
          ],
        ),
      );
}

class TynsAiSession extends StatefulWidget {
  const TynsAiSession({super.key});

  @override
  State<TynsAiSession> createState() => _TynsAiSessionState();
}

class _TynsAiSessionState extends State<TynsAiSession> {
  final _blankController = TextEditingController(text: '0');
  final _standardIndexController = TextEditingController();
  final _standardConcentrationController = TextEditingController(text: '10');
  Uint8List? _imageBytes;
  String? _imageName;
  OpticalAnalysis? _analysis;
  bool _isAir = false;
  bool _isPicking = false;
  String? _error;

  String get _unit => _isAir ? 'mg/m³' : 'mg/L';

  double? get _estimate {
    final result = _analysis;
    final blank = double.tryParse(_blankController.text);
    final standardIndex = double.tryParse(_standardIndexController.text);
    final standardConcentration = double.tryParse(_standardConcentrationController.text);
    if (result == null || blank == null || standardIndex == null ||
        standardConcentration == null) {
      return null;
    }
    return estimateConcentration(
      currentIndex: result.scatterIndex,
      blankIndex: blank,
      standardIndex: standardIndex,
      standardConcentration: standardConcentration,
    );
  }

  @override
  void dispose() {
    _blankController.dispose();
    _standardIndexController.dispose();
    _standardConcentrationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _isPicking = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
        final bytes = file.bytes ??
          (file.path == null ? null : await XFile(file.path!).readAsBytes());
      if (bytes == null) throw const FormatException('The selected image could not be read.');
      final analysis = OpticalAnalysis.fromBytes(bytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _analysis = analysis;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not analyze this image: $error');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _useCurrentIndex(TextEditingController controller) {
    final score = _analysis?.scatterIndex;
    if (score == null) return;
    controller.text = score.toStringAsFixed(2);
    setState(() {});
  }

  void _setSampleType(bool isAir) {
    if (_isAir == isAir) return;
    setState(() {
      _isAir = isAir;
      _blankController.text = '0';
      _standardIndexController.clear();
      _standardConcentrationController.text = '10';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 20, wide ? 32 : 18, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 30),
                      _title(),
                      const SizedBox(height: 22),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 11, child: _imagePanel()),
                            const SizedBox(width: 20),
                            Expanded(flex: 9, child: _analysisPanel()),
                          ],
                        )
                      else ...[
                        _imagePanel(),
                        const SizedBox(height: 16),
                        _analysisPanel(),
                      ],
                      const SizedBox(height: 18),
                      _footer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.blur_on, color: _ink, size: 24),
          ),
          const SizedBox(width: 11),
          const Text(
            'LUMENMIND',
            style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
          const Spacer(),
          const Icon(Icons.circle, color: _green, size: 8),
          const SizedBox(width: 7),
          const Text(
            'LOCAL IMAGE ANALYSIS',
            style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      );

  Widget _title() => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TYNSAI / CONCENTRATION', style: TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                SizedBox(height: 7),
                Text('TynsAI', style: TextStyle(color: _ink, fontFamily: 'Georgia', fontSize: 38, height: 1.05)),
              ],
            ),
          ),
          if (_analysis != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _imageBytes = null;
                _imageName = null;
                _analysis = null;
                _error = null;
              }),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Reset'),
              style: TextButton.styleFrom(foregroundColor: _muted),
            ),
        ],
      );

  Widget _imagePanel() => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(number: '01', title: 'Image input', trailing: 'IMAGE SOURCE'),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 330,
                color: const Color(0xFF172521),
                child: _imageBytes == null ? _emptyImageState() : _imagePreview(),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _imageBytes == null ? 'JPG · PNG · WEBP' : '${_analysis!.width} × ${_analysis!.height} px',
                    style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isPicking ? null : _pickImage,
                  icon: _isPicking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file, size: 18),
                  label: Text(_imageBytes == null ? 'Choose image' : 'Change image'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: _ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB23D32))),
            ],
          ],
        ),
      );

  Widget _imagePreview() => Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Center(
              child: Text('Image preview unavailable', style: TextStyle(color: Colors.white)),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _imageName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      );

  Widget _emptyImageState() => InkWell(
        onTap: _isPicking ? null : _pickImage,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, color: _lime, size: 28),
              ),
              const SizedBox(height: 14),
              const Text('Add a Tyndall or light-beam image', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text('Images are processed on this device', style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _analysisPanel() => Column(
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeading(number: '02', title: 'Sample medium', trailing: 'SAMPLE'),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.water_drop_outlined),
                      label: Text('Water', maxLines: 1, softWrap: false),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.air),
                      label: Text('Air', maxLines: 1, softWrap: false),
                    ),
                  ],
                  selected: {_isAir},
                  onSelectionChanged: (selection) => _setSampleType(selection.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.comfortable,
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
                  ),
                ),
                const SizedBox(height: 20),
                _metrics(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _calibrationPanel(),
        ],
      );

  Widget _metrics() {
    final analysis = _analysis;
    if (analysis == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 23, horizontal: 14),
        decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(8)),
        child: const Row(
          children: [
            Icon(Icons.insights_outlined, color: _green),
            SizedBox(width: 11),
            Expanded(child: Text('Add an image to calculate its optical index.', style: TextStyle(color: _muted, fontSize: 13))),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Optical scatter index', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Normalized image proxy', style: TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            Text(
              analysis.scatterIndex.toStringAsFixed(1),
              style: const TextStyle(color: _green, fontFamily: 'Georgia', fontSize: 38, height: 1),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 5, bottom: 4),
              child: Text('/ 100', style: TextStyle(color: _muted, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 13),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: analysis.scatterIndex / 100,
            minHeight: 7,
            backgroundColor: const Color(0xFFE7ECE6),
            color: _green,
          ),
        ),
        const SizedBox(height: 17),
        _MetricRow(label: 'Mean brightness', value: '${analysis.meanBrightness.toStringAsFixed(1)} / 255'),
        _MetricRow(label: 'Highlight pixels', value: '${(analysis.highlightRatio * 100).toStringAsFixed(1)}%'),
        _MetricRow(label: 'Local gradient', value: analysis.edgeStrength.toStringAsFixed(3)),
      ],
    );
  }

  Widget _calibrationPanel() {
    final estimate = _estimate;
    final ready = estimate != null;
    final outOfRange = ready && _analysis != null && !_insideCalibrationRange(_analysis!.scatterIndex);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            number: '03',
            title: 'Concentration calibration',
            trailing: ready ? 'CALIBRATED' : 'NOT CALIBRATED',
            active: ready,
          ),
          const SizedBox(height: 7),
          const Text(
            'Use blank and known-standard images captured with the same setup.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CalibrationField(
                  label: 'Blank index',
                  controller: _blankController,
                  onChanged: (_) => setState(() {}),
                  suffix: _analysis == null ? null : _UsePhotoButton(onPressed: () => _useCurrentIndex(_blankController)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CalibrationField(
                  label: 'Standard index',
                  controller: _standardIndexController,
                  onChanged: (_) => setState(() {}),
                  suffix: _analysis == null ? null : _UsePhotoButton(onPressed: () => _useCurrentIndex(_standardIndexController)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CalibrationField(
            label: 'Standard mass concentration ($_unit)',
            controller: _standardConcentrationController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ready ? const Color(0xFFEAF3DF) : _paper,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ready
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated mass concentration', style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              _formatConcentration(estimate),
                              style: const TextStyle(color: _ink, fontFamily: 'Georgia', fontSize: 34, height: 1.1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(_unit, style: const TextStyle(color: _green, fontSize: 12)),
                          ),
                        ],
                      ),
                      if (outOfRange) ...[
                        const SizedBox(height: 7),
                        const Text(
                          'Outside the calibration range; this is a linear extrapolation.',
                          style: TextStyle(color: Color(0xFF8B5A18), fontSize: 11),
                        ),
                      ],
                    ],
                  )
                : const Row(
                    children: [
                      Icon(Icons.info_outline, color: _muted, size: 18),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Enter distinct blank and standard indices and a positive concentration to calculate an estimate.',
                          style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _insideCalibrationRange(double current) {
    final blank = double.tryParse(_blankController.text);
    final standard = double.tryParse(_standardIndexController.text);
    if (blank == null || standard == null) return false;
    return current >= math.min(blank, standard) && current <= math.max(blank, standard);
  }

  String _formatConcentration(double? value) {
    if (value == null) return '--';
    if (value >= 1000) return value.toStringAsFixed(0);
    if (value >= 100) return value.toStringAsFixed(1);
    if (value >= 10) return value.toStringAsFixed(2);
    return value.toStringAsFixed(3);
  }

  Widget _footer() => Container(
        padding: const EdgeInsets.only(top: 15),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, color: _green, size: 17),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Concentration is a two-point linear estimate. Recalibrate for each material and fixed lighting, exposure, container, and distance. This is not a substitute for laboratory testing.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
              ),
            ),
          ],
        ),
      );
}

class OpticalAnalysis {
  const OpticalAnalysis({
    required this.width,
    required this.height,
    required this.scatterIndex,
    required this.meanBrightness,
    required this.highlightRatio,
    required this.edgeStrength,
  });

  final int width;
  final int height;
  final double scatterIndex;
  final double meanBrightness;
  final double highlightRatio;
  final double edgeStrength;

  static OpticalAnalysis fromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Unsupported image format.');
    final width = decoded.width;
    final height = decoded.height;
    final scale = math.min(512 / math.max(width, height), 1.0);
    final resized = scale < 1
        ? img.copyResize(
            decoded,
            width: math.max(1, (width * scale).round()).toInt(),
            height: math.max(1, (height * scale).round()).toInt(),
          )
        : decoded;
    final pixelCount = resized.width * resized.height;
    final brightness = List<double>.filled(pixelCount, 0);
    var sum = 0.0;
    var sumSquares = 0.0;
    var highlights = 0;
    var gradientSum = 0.0;
    var gradientCount = 0;

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        final luminance = (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b).toDouble();
        final index = y * resized.width + x;
        brightness[index] = luminance;
        sum += luminance;
        sumSquares += luminance * luminance;
        if (luminance >= 220) highlights++;
        if (x > 0) {
          gradientSum += (luminance - brightness[index - 1]).abs();
          gradientCount++;
        }
        if (y > 0) {
          gradientSum += (luminance - brightness[index - resized.width]).abs();
          gradientCount++;
        }
      }
    }

    final mean = sum / pixelCount;
    final deviation = math.sqrt(math.max(0, sumSquares / pixelCount - mean * mean));
    final highlightRatio = highlights / pixelCount;
    final edgeStrength = gradientCount == 0 ? 0.0 : gradientSum / gradientCount / 255;
    final contrast = (deviation / 90).clamp(0.0, 1.0);
    final score = (contrast * 0.35 + edgeStrength * 0.40 + highlightRatio * 0.25) * 100;

    return OpticalAnalysis(
      width: width,
      height: height,
      scatterIndex: score.clamp(0.0, 100.0).toDouble(),
      meanBrightness: mean,
      highlightRatio: highlightRatio,
      edgeStrength: edgeStrength,
    );
  }
}

double? estimateConcentration({
  required double currentIndex,
  required double blankIndex,
  required double standardIndex,
  required double standardConcentration,
}) {
  final span = standardIndex - blankIndex;
  if (!currentIndex.isFinite ||
      !blankIndex.isFinite ||
      !standardIndex.isFinite ||
      !standardConcentration.isFinite ||
      span.abs() < 0.000001 ||
      standardConcentration <= 0) {
    return null;
  }
  return math.max(0, (currentIndex - blankIndex) / span * standardConcentration).toDouble();
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _line),
        ),
        child: child,
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.number,
    required this.title,
    required this.trailing,
    this.active = false,
  });

  final String number;
  final String title;
  final String trailing;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(number, style: const TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? _green : _muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

class _CalibrationField extends StatelessWidget {
  const _CalibrationField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(minWidth: 35, minHeight: 35),
        ),
        style: const TextStyle(fontSize: 13, color: _ink),
      );
}

class _UsePhotoButton extends StatelessWidget {
  const _UsePhotoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Use the current image index',
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.center_focus_strong, size: 17),
      );
}