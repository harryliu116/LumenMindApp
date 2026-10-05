import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'light_chaser.dart';
import 'tyndall_detector_client.dart';

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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
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
          label: 'LightChaser',
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
  Uint8List? _imageBytes;
  String? _imageName;
  String? _prediction;
  bool _isWorking = false;
  String? _error;

  Future<void> _pickImage() async {
    setState(() {
      _isWorking = true;
      _error = null;
      _prediction = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes =
          file.bytes ??
          (file.path == null ? null : await XFile(file.path!).readAsBytes());
      if (bytes == null) {
        throw const FormatException('The selected image could not be read.');
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
      });
      final output = await TyndallDetectorClient.predict(bytes, file.name);
      if (!mounted) return;
      setState(() => _prediction = output);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is DetectorApiException
            ? error.message
          : 'Prediction failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
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
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 18,
                    20,
                    wide ? 32 : 18,
                    36,
                  ),
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

  Widget _header() => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.blur_on, color: _ink, size: 24),
        ),
        const SizedBox(width: 11),
        const Text(
          'LUMENMIND',
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        if (constraints.maxWidth >= 420) ...[
          const Spacer(),
          const Icon(Icons.circle, color: _green, size: 8),
          const SizedBox(width: 7),
          const Text(
            'LOCAL IMAGE ANALYSIS',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _title() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detecting mass concentration from water and air through Tyndall Effect.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'TynsAI',
              style: TextStyle(
                color: _ink,
                fontFamily: 'Georgia',
                fontSize: 38,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
      if (_imageBytes != null)
        TextButton.icon(
          onPressed: () => setState(() {
            _imageBytes = null;
            _imageName = null;
            _prediction = null;
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
        const _SectionHeading(
          number: '01',
          title: 'Image input',
          trailing: 'IMAGE SOURCE',
        ),
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
                _imageBytes == null ? 'JPG · PNG · WEBP' : _imageName ?? '',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _isWorking ? null : _pickImage,
              icon: _isWorking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(
                _isWorking
                    ? 'Running detector...'
                    : _imageBytes == null
                    ? 'Choose image'
                    : 'Change image',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: _ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
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
          child: Text(
            'Image preview unavailable',
            style: TextStyle(color: Colors.white),
          ),
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
    onTap: _isWorking ? null : _pickImage,
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
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              color: _lime,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Upload a Tyndall or light-beam image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Upload a photo to see its predicted mass percentage',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _analysisPanel() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          number: '02',
          title: 'Detector output',
          trailing: 'RESULT',
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isWorking
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? SelectableText(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB23D32), height: 1.5),
                )
              : _prediction == null
              ? const Text(
                  'Upload an image to run the original tyndall_detector and show its output.',
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
                )
              : SelectableText(
                  _prediction!,
                  style: const TextStyle(
                    color: _ink,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _footer() => Container(
    padding: const EdgeInsets.only(top: 15),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: _line)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, color: _green, size: 17),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Detector estimates may not be accurate. Use results as a reference only; confirm important measurements with a laboratory test.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );
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
  });

  final String number;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        number,
        style: const TextStyle(
          color: _green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 9),
      Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          trailing,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ),
    ],
  );
}
