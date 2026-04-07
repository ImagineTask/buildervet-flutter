import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// Draw mode
// ─────────────────────────────────────────────
enum _DrawMode { freehand, line, curve, text }

// ─────────────────────────────────────────────
// Stroke model
// ─────────────────────────────────────────────
class _Stroke {
  final _DrawMode mode;
  final List<Offset> points;
  final Color color;
  final double width;

  _Stroke({
    required this.mode,
    required this.points,
    required this.color,
    required this.width,
  });
}

// ─────────────────────────────────────────────
// Text label model (committed)
// ─────────────────────────────────────────────
class _TextLabel {
  String text;
  Offset position;
  Color color;
  double fontSize;

  _TextLabel({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
  });
}

// ─────────────────────────────────────────────
// ImageAnnotatorPage
// ─────────────────────────────────────────────
class ImageAnnotatorPage extends StatefulWidget {
  final File imageFile;
  const ImageAnnotatorPage({super.key, required this.imageFile});

  @override
  State<ImageAnnotatorPage> createState() => _ImageAnnotatorPageState();
}

class _ImageAnnotatorPageState extends State<ImageAnnotatorPage> {
  // ── Data ─────────────────────────────────────────────────────────
  final List<_Stroke> _strokes = [];
  final List<_TextLabel> _labels = [];
  final List<Object> _undoStack = [];

  // ── Tool state ───────────────────────────────────────────────────
  _DrawMode _mode = _DrawMode.freehand;
  Color _color = const Color(0xFFFF3B30);
  double _strokeWidth = 4.0;
  double _fontSize = 22.0;

  // In-progress stroke
  List<Offset> _currentPoints = [];

  // ── Inline text editing ──────────────────────────────────────────
  // When non-null, an active inline TextField is shown at this position
  Offset? _activeTextPosition;
  // Index of label being edited (-1 = new label)
  int _editingLabelIndex = -1;
  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  // Export key wraps everything
  final _exportKey = GlobalKey();

  // Image
  ui.Image? _uiImage;
  bool _loading = true;
  bool _exporting = false;

  static const _palette = [
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  @override
  void initState() {
    super.initState();
    _textFocus.addListener(() {
      if (!_textFocus.hasFocus && _activeTextPosition != null) {
        _commitText();
      }
    });
    _loadImage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _uiImage = frame.image;
      _loading = false;
    });
  }

  // ── Canvas sizing ────────────────────────────────────────────────

  Size _computeCanvasSize(BoxConstraints constraints) {
    if (_uiImage == null) return constraints.biggest;
    final aspect = _uiImage!.width / _uiImage!.height;
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;
    return (maxW / aspect <= maxH)
        ? Size(maxW, maxW / aspect)
        : Size(maxH * aspect, maxH);
  }

  // ── Drawing gestures ─────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    if (_mode == _DrawMode.text) return;
    // Tapping canvas while typing — commit first
    if (_activeTextPosition != null) {
      _commitText();
      return;
    }
    _undoStack.clear();
    setState(() => _currentPoints = [d.localPosition]);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_mode == _DrawMode.text || _activeTextPosition != null) return;
    setState(() => _currentPoints = [..._currentPoints, d.localPosition]);
  }

  void _onPanEnd(DragEndDetails _) {
    if (_mode == _DrawMode.text || _activeTextPosition != null) return;
    if (_currentPoints.length < 2) {
      setState(() => _currentPoints = []);
      return;
    }
    final stroke = _Stroke(
      mode: _mode,
      points: List.from(_currentPoints),
      color: _color,
      width: _strokeWidth,
    );
    setState(() {
      _strokes.add(stroke);
      _currentPoints = [];
    });
  }

  // ── Text tap ─────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails d) {
    if (_mode != _DrawMode.text) {
      // Commit any active text when switching away
      if (_activeTextPosition != null) _commitText();
      return;
    }

    // Check if tapping an existing label to edit it
    for (int i = _labels.length - 1; i >= 0; i--) {
      final lbl = _labels[i];
      final approxW = lbl.text.length * lbl.fontSize * 0.62;
      final rect = Rect.fromLTWH(
          lbl.position.dx, lbl.position.dy, approxW, lbl.fontSize * 1.5);
      if (rect.contains(d.localPosition)) {
        // If already editing this label, do nothing
        if (_editingLabelIndex == i) return;
        // Commit current before starting a new edit
        if (_activeTextPosition != null) _commitText();
        _startEditing(d.localPosition, existingIndex: i);
        return;
      }
    }

    // Tapped empty space — commit existing then start new label
    if (_activeTextPosition != null) {
      _commitText();
    } else {
      _startEditing(d.localPosition, existingIndex: -1);
    }
  }

  void _startEditing(Offset position, {required int existingIndex}) {
    _editingLabelIndex = existingIndex;
    if (existingIndex >= 0) {
      // Editing existing label: prefill and remove from committed list
      final lbl = _labels[existingIndex];
      _textController.text = lbl.text;
      _textController.selection = TextSelection(
          baseOffset: 0, extentOffset: lbl.text.length);
      setState(() {
        _activeTextPosition = lbl.position;
        _labels.removeAt(existingIndex);
      });
    } else {
      _textController.clear();
      setState(() => _activeTextPosition = position);
    }
    // Show keyboard
    Future.microtask(() => _textFocus.requestFocus());
  }

  void _commitText() {
    final text = _textController.text.trim();
    final pos = _activeTextPosition;
    if (pos == null) return;

    setState(() {
      if (text.isNotEmpty) {
        _undoStack.clear();
        _labels.add(_TextLabel(
          text: text,
          position: pos,
          color: _color,
          fontSize: _fontSize,
        ));
      }
      _activeTextPosition = null;
      _editingLabelIndex = -1;
    });
    _textController.clear();
    _textFocus.unfocus();
  }

  void _cancelText() {
    // Restore label if we were editing an existing one
    if (_editingLabelIndex >= 0 && _activeTextPosition != null) {
      // The label was already removed; re-add with original text if needed
      // (user cancelled, so just discard changes)
    }
    setState(() {
      _activeTextPosition = null;
      _editingLabelIndex = -1;
    });
    _textController.clear();
    _textFocus.unfocus();
  }

  // ── Undo / Redo / Clear ──────────────────────────────────────────

  bool get _hasAnnotations => _strokes.isNotEmpty || _labels.isNotEmpty;

  void _undo() {
    if (_activeTextPosition != null) _cancelText();
    if (_strokes.isNotEmpty) {
      setState(() => _undoStack.add(_strokes.removeLast()));
    } else if (_labels.isNotEmpty) {
      setState(() => _undoStack.add(_labels.removeLast()));
    }
  }

  void _redo() {
    if (_undoStack.isEmpty) return;
    final item = _undoStack.last;
    setState(() {
      _undoStack.removeLast();
      if (item is _Stroke) _strokes.add(item);
      if (item is _TextLabel) _labels.add(item);
    });
  }

  void _clear() {
    if (_activeTextPosition != null) _cancelText();
    setState(() {
      _strokes.clear();
      _labels.clear();
      _undoStack.clear();
      _currentPoints = [];
    });
  }

  // ── Export ───────────────────────────────────────────────────────

  Future<void> _done() async {
    // Commit any active text first
    if (_activeTextPosition != null) _commitText();
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() => _exporting = true);
    try {
      final boundary = _exportKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Keep scaffold from resizing when keyboard appears —
      // we handle positioning ourselves
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (_activeTextPosition != null) _cancelText();
            Navigator.pop(context, null);
          },
        ),
        title: const Text('Annotate',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded, color: Colors.white),
            onPressed: _hasAnnotations ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded, color: Colors.white),
            onPressed: _undoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white),
            onPressed: _hasAnnotations ? _clear : null,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _exporting ? null : _done,
              child: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Send',
                      style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Column(
              children: [
                // ── Canvas ─────────────────────────────────
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final size = _computeCanvasSize(constraints);
                    return Center(
                      child: RepaintBoundary(
                        key: _exportKey,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            onTapDown: _onTapDown,
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                // ── Image + strokes ───────────
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _StrokePainter(
                                      image: _uiImage,
                                      strokes: _strokes,
                                      currentPoints: _currentPoints,
                                      currentMode: _mode,
                                      currentColor: _color,
                                      currentWidth: _strokeWidth,
                                    ),
                                  ),
                                ),

                                // ── Committed text labels ─────
                                for (int i = 0; i < _labels.length; i++)
                                  _DraggableLabel(
                                    label: _labels[i],
                                    isTextMode: _mode == _DrawMode.text,
                                    onDrag: (delta) => setState(() {
                                      _labels[i].position =
                                          _labels[i].position + delta;
                                    }),
                                  ),

                                // ── Active inline text input ──
                                if (_activeTextPosition != null)
                                  Positioned(
                                    left: _activeTextPosition!.dx,
                                    top: _activeTextPosition!.dy,
                                    child: _InlineTextField(
                                      controller: _textController,
                                      focusNode: _textFocus,
                                      color: _color,
                                      fontSize: _fontSize,
                                      maxWidth: size.width -
                                          _activeTextPosition!.dx - 8,
                                      onSubmit: _commitText,
                                      onCancel: _cancelText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                // ── Text mode hint ────────────────────────────
                if (_mode == _DrawMode.text)
                  Container(
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      _activeTextPosition != null
                          ? 'Type · ✓ to confirm · tap elsewhere to place'
                          : 'Tap anywhere to add text  ·  Drag label to move',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45)),
                    ),
                  ),

                // ── Toolbar ───────────────────────────────────
                _Toolbar(
                  mode: _mode,
                  color: _color,
                  strokeWidth: _strokeWidth,
                  fontSize: _fontSize,
                  palette: _palette,
                  onModeChanged: (m) {
                    if (_activeTextPosition != null) _commitText();
                    setState(() => _mode = m);
                  },
                  onColorChanged: (c) => setState(() => _color = c),
                  onWidthChanged: (w) => setState(() => _strokeWidth = w),
                  onFontSizeChanged: (s) => setState(() => _fontSize = s),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Inline text field — renders directly on canvas
// ─────────────────────────────────────────────
class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final double fontSize;
  final double maxWidth;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _InlineTextField({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.fontSize,
    required this.maxWidth,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Text input
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 40,
            maxWidth: maxWidth.clamp(80, 300),
          ),
          child: IntrinsicWidth(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.7),
                    offset: const Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              cursorColor: color,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                // Subtle underline so user knows it's editable
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: color.withOpacity(0.5), width: 1.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: color, width: 2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Confirm button
        GestureDetector(
          onTap: onSubmit,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 18, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Draggable committed label
// ─────────────────────────────────────────────
class _DraggableLabel extends StatelessWidget {
  final _TextLabel label;
  final bool isTextMode;
  final void Function(Offset delta) onDrag;

  const _DraggableLabel({
    required this.label,
    required this.isTextMode,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: label.position.dx,
      top: label.position.dy,
      child: GestureDetector(
        // Only draggable in text mode
        onPanUpdate: isTextMode ? (d) => onDrag(d.delta) : null,
        child: Text(
          label.text,
          style: TextStyle(
            color: label.color,
            fontSize: label.fontSize,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.65),
                offset: const Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stroke Painter
// ─────────────────────────────────────────────
class _StrokePainter extends CustomPainter {
  final ui.Image? image;
  final List<_Stroke> strokes;
  final List<Offset> currentPoints;
  final _DrawMode currentMode;
  final Color currentColor;
  final double currentWidth;

  _StrokePainter({
    required this.image,
    required this.strokes,
    required this.currentPoints,
    required this.currentMode,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      final src = Rect.fromLTWH(
          0, 0, image!.width.toDouble(), image!.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(image!, src, dst, Paint());
    }
    for (final s in strokes) {
      _paintStroke(canvas, s.points, s.mode, s.color, s.width);
    }
    if (currentPoints.length >= 2 && currentMode != _DrawMode.text) {
      _paintStroke(
          canvas, currentPoints, currentMode, currentColor, currentWidth);
    }
  }

  void _paintStroke(Canvas canvas, List<Offset> points, _DrawMode mode,
      Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (mode) {
      case _DrawMode.freehand:
        final path = Path()..moveTo(points[0].dx, points[0].dy);
        for (int i = 1; i < points.length - 1; i++) {
          final mid = Offset(
            (points[i].dx + points[i + 1].dx) / 2,
            (points[i].dy + points[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(
              points[i].dx, points[i].dy, mid.dx, mid.dy);
        }
        path.lineTo(points.last.dx, points.last.dy);
        canvas.drawPath(path, paint);
        break;
      case _DrawMode.line:
        canvas.drawLine(points.first, points.last, paint);
        _arrowHead(canvas, points.first, points.last, paint);
        break;
      case _DrawMode.curve:
        if (points.length < 3) {
          canvas.drawLine(points.first, points.last, paint);
        } else {
          final mid = points[points.length ~/ 2];
          final path = Path()
            ..moveTo(points.first.dx, points.first.dy)
            ..quadraticBezierTo(
                mid.dx, mid.dy, points.last.dx, points.last.dy);
          canvas.drawPath(path, paint);
        }
        break;
      case _DrawMode.text:
        break;
    }
  }

  void _arrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const s = 14.0;
    final a = math.atan2(to.dy - from.dy, to.dx - from.dx);
    canvas.drawLine(to,
        Offset(to.dx - s * math.cos(a - 0.4), to.dy - s * math.sin(a - 0.4)),
        paint);
    canvas.drawLine(to,
        Offset(to.dx - s * math.cos(a + 0.4), to.dy - s * math.sin(a + 0.4)),
        paint);
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}

// ─────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────
class _Toolbar extends StatelessWidget {
  final _DrawMode mode;
  final Color color;
  final double strokeWidth;
  final double fontSize;
  final List<Color> palette;
  final ValueChanged<_DrawMode> onModeChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onFontSizeChanged;

  const _Toolbar({
    required this.mode,
    required this.color,
    required this.strokeWidth,
    required this.fontSize,
    required this.palette,
    required this.onModeChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onFontSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isText = mode == _DrawMode.text;
    return Container(
      color: const Color(0xFF1C1C1E),
      padding: EdgeInsets.fromLTRB(
          12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _ModeBtn(Icons.edit_rounded, 'Draw', mode == _DrawMode.freehand,
                  () => onModeChanged(_DrawMode.freehand)),
              const SizedBox(width: 8),
              _ModeBtn(Icons.arrow_forward_rounded, 'Line',
                  mode == _DrawMode.line, () => onModeChanged(_DrawMode.line)),
              const SizedBox(width: 8),
              _ModeBtn(Icons.show_chart_rounded, 'Curve',
                  mode == _DrawMode.curve,
                  () => onModeChanged(_DrawMode.curve)),
              const SizedBox(width: 8),
              _ModeBtn(Icons.text_fields_rounded, 'Text',
                  mode == _DrawMode.text, () => onModeChanged(_DrawMode.text)),
            ]),
          ),
          const SizedBox(height: 14),
          // Palette
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: palette.map((c) {
              final sel = color == c;
              return GestureDetector(
                onTap: () => onColorChanged(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: sel ? 30 : 26,
                  height: sel ? 30 : 26,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? Colors.white : Colors.white.withOpacity(0.25),
                      width: sel ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Size slider
          Row(children: [
            Icon(isText ? Icons.text_decrease : Icons.remove,
                color: Colors.white54, size: 16),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: color.withOpacity(0.2),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackHeight: 3,
                ),
                child: isText
                    ? Slider(
                        value: fontSize,
                        min: 12,
                        max: 52,
                        onChanged: onFontSizeChanged)
                    : Slider(
                        value: strokeWidth,
                        min: 2,
                        max: 16,
                        onChanged: onWidthChanged),
              ),
            ),
            Icon(isText ? Icons.text_increase : Icons.add,
                color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            isText
                ? Text('Aa',
                    style: TextStyle(
                        color: color,
                        fontSize: (fontSize * 0.55).clamp(10, 24),
                        fontWeight: FontWeight.w700))
                : Container(
                    width: strokeWidth + 4,
                    height: strokeWidth + 4,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
            const SizedBox(width: 8),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mode Button helper
// ─────────────────────────────────────────────
class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeBtn(this.icon, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF007AFF)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.white54)),
        ]),
      ),
    );
  }
}