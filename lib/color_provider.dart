import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorProvider with ChangeNotifier {
  Color _primaryColor;

  ColorProvider({required Color initialColor}) : _primaryColor = initialColor;

  Color get primaryColor => _primaryColor;

  /// Updates the primary color and notifies listeners.
  void updatePrimaryColor(Color color) {
    if (color != _primaryColor) {
      _primaryColor = color;
      notifyListeners();
    }
  }

  /// Displays a dialog with a color picker.
  void showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set app theme color:'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _primaryColor,
            onColorChanged: updatePrimaryColor,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Done'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
