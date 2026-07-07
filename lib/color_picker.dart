import 'package:flutter/material.dart';

/// Shows a simple custom color picker and resolves to the chosen [Color],
/// or null if the user cancels. Built from plain Flutter sliders (no
/// packages) around [HSVColor] — hue, saturation and brightness.
Future<Color?> showColorPickerDialog(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  // HSV is friendlier than RGB for a person picking a color: hue is the
  // "which color", saturation is "how vivid", value is "how bright".
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live preview + hex readout.
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: TextStyle(
                  color: _hsv.value > 0.6 ? Colors.black : Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _labeledSlider(
              label: 'Hue',
              value: _hsv.hue,
              max: 360,
              // A rainbow track so the slider shows what it controls.
              activeColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _labeledSlider(
              label: 'Saturation',
              value: _hsv.saturation,
              max: 1,
              activeColor: _color,
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _labeledSlider(
              label: 'Brightness',
              value: _hsv.value,
              max: 1,
              activeColor: _color,
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Use color'),
        ),
      ],
    );
  }

  Widget _labeledSlider({
    required String label,
    required double value,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: max,
            value: value.clamp(0, max),
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
