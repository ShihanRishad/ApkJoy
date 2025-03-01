import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


class ColorProvider with ChangeNotifier {
  Color _primaryColor = Colors.blue;
  final SharedPreferences prefs;

  ColorProvider({required this.prefs}){
    _loadColor();
  }

  Color get primaryColor => _primaryColor;

  void updatePrimaryColor(Color newColor) {
    _primaryColor = newColor;
    _saveColor();
    notifyListeners();
  }

  void showColorPicker(BuildContext context) {
    Color currentColor = _primaryColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color!'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color){
                currentColor = color;
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Got it'),
              onPressed: () {
                updatePrimaryColor(currentColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _loadColor(){
    final colorValue = prefs.getInt('primaryColor');
    _primaryColor = colorValue != null ? Color(colorValue) : Colors.blue;
    notifyListeners();
  }

  void _saveColor() async {
    await prefs.setInt('primaryColor', _primaryColor.value);
  }
}