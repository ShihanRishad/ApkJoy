// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_html/flutter_html.dart';
import 'color_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:file_picker/file_picker.dart';
import 'settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Override the default error widget builder to show errors in the UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Text(
          'Something went wrong:\n${details.exception}',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  };

  await PreferenceUtils.init();
  final SharedPreferences prefs = PreferenceUtils.prefs;
  runApp(
    ChangeNotifierProvider(
      create:
          (_) => ColorProvider(
            initialColor: Color(PreferenceUtils.getPrimaryColorValue()),
          ),
      child: ApkJoyApp(prefs: prefs),
    ),
  );
}

class ApkJoyApp extends StatefulWidget {
  final SharedPreferences prefs;
  const ApkJoyApp({super.key, required this.prefs});

  @override
  _ApkJoyAppState createState() => _ApkJoyAppState();
}

class _ApkJoyAppState extends State<ApkJoyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showSystemApps = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Listen to changes in ColorProvider to save any color updates.
    Provider.of<ColorProvider>(context, listen: false).addListener(() {
      final currentColor =
          Provider.of<ColorProvider>(context, listen: false).primaryColor;
      PreferenceUtils.setPrimaryColorValue(currentColor.value);
    });
  }

  void _loadSettings() {
    // from shared prefs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final themeString = widget.prefs.getString('themeMode');
        final showSystemApps = widget.prefs.getBool('showSystemApps') ?? false;
        final colorValue =
            widget.prefs.getInt('primaryColor') ?? Colors.blue.value;

        if (!mounted) return;
        setState(() {
          _themeMode = themeString == 'dark' ? ThemeMode.dark : ThemeMode.light;
          _showSystemApps = showSystemApps;
        });
        Provider.of<ColorProvider>(
          context,
          listen: false,
        ).updatePrimaryColor(Color(colorValue));
      } catch (e) {
        debugPrint('Error loading settings: $e');
      }
    });
  }

  Future<void> _saveSettings() async {
    try {
      await PreferenceUtils.setThemeMode(
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
      await PreferenceUtils.setShowSystemApps(_showSystemApps);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _saveSettings();
  }

  void _toggleSystemApps(bool value) {
    setState(() {
      _showSystemApps = value;
    });
    _saveSettings();
  }

  Future<void> _resetSettings() async {
    try {
      await PreferenceUtils.resetSettings();
      if (!mounted) return;
      setState(() {
        _themeMode = ThemeMode.light;
        _showSystemApps = false;
      });
      Provider.of<ColorProvider>(
        context,
        listen: false,
      ).updatePrimaryColor(Colors.blue);
      _saveSettings();
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Provider.of<ColorProvider>(context).primaryColor;
    return MaterialApp(
      title: 'ApkJoy',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      home: AppListPage(
        onToggleTheme: _toggleTheme,
        currentThemeMode: _themeMode,
        showSystemApps: _showSystemApps,
        onToggleSystemApps: _toggleSystemApps,
        onResetSettings: _resetSettings,
      ),
    );
  }
}

class AppListPage extends StatefulWidget {
  final Function(bool) onToggleTheme;
  final ThemeMode currentThemeMode;
  final bool showSystemApps;
  final Function(bool) onToggleSystemApps;
  final Future<void> Function() onResetSettings;

  const AppListPage({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
    required this.showSystemApps,
    required this.onToggleSystemApps,
    required this.onResetSettings,
  });

  @override
  _AppListPageState createState() => _AppListPageState();
}

class _AppListPageState extends State<AppListPage> {
  late Future<List<Application>> _appsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _loadApps() {
    try {
      _appsFuture = DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: widget.showSystemApps,
      );
    } catch (e) {
      debugPrint('Error loading apps: $e');
      _appsFuture = Future.value([]);
    }
  }

  @override
  void didUpdateWidget(covariant AppListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSystemApps != widget.showSystemApps) {
      _loadApps();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ApkJoy'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => SettingsPage(
                        isDark: widget.currentThemeMode == ThemeMode.dark,
                        onToggleTheme: widget.onToggleTheme,
                        showSystemApps: widget.showSystemApps,
                        onToggleSystemApps: widget.onToggleSystemApps,
                        onResetSettings: widget.onResetSettings,
                      ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Application>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final apps = snapshot.data ?? [];
          final filteredApps =
              apps
                  .where(
                    (app) => app.appName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList();
          return ListView.builder(
            itemCount: filteredApps.length,
            itemBuilder: (context, index) {
              final app = filteredApps[index];
              return ListTile(
                leading:
                    app is ApplicationWithIcon
                        ? Image.memory(app.icon, width: 40, height: 40)
                        : null,
                title: Text(app.appName),
                subtitle: Text(app.packageName),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AppDetailPage(app: app)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Page to display details of a selected app, extract its APK, and share it.
class AppDetailPage extends StatefulWidget {
  final Application app;
  const AppDetailPage({super.key, required this.app});

  @override
  _AppDetailPageState createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  static const platform = MethodChannel('apkjoy');
  String _status = '';
  String? _apkPath;
  String? _apkPathUser;

  Future<void> extractApk() async {
    // Show the progress dialog.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildProgressDialog(),
    );

    // Delay extraction slightly to allow the dialog to render.
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Get the APK path from the platform channel
      final String apkPath = await platform.invokeMethod('extractApk', {
        'packageName': widget.app.packageName,
      });
      if (!mounted) return;
      setState(() {
        // Directly assign apkPath instead of using a separate destination
        _apkPath = apkPath;
        _apkPathUser = _apkPath?.substring(19);
        _status = 'APK extracted to:\n$_apkPathUser';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Unexpected error: $e';
      });
    } finally {
      Navigator.of(context).pop();
    }
  }

  Widget _buildProgressDialog() {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              "Extracting...",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> shareApk() async {
    if (_apkPath == null) {
      setState(() {
        _status = 'No APK file available to share. Please extract it first.';
      });
      return;
    }
    try {
      await Share.shareXFiles([XFile(_apkPath!)], text: 'Check out this APK!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error sharing APK: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.app.appName)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.app is ApplicationWithIcon)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: MemoryImage(
                        (widget.app as ApplicationWithIcon).icon,
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  const SizedBox(height: 20),
                  SelectableText(
                    widget.app.appName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.app.packageName,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Extract APK'),
                    onPressed: extractApk,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text('Share APK'),
                    onPressed: _apkPath != null ? shareApk : null,
                  ),
                  const SizedBox(height: 24),
                  if (_status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _status,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final String htmlData = """
<style>
.more {
padding: 20px;
background-color: #333333;
color: white;
border-radius: 200px;
}
</style>
<h1 style="text-align:center;">About ApkJoy</h1>
<p><strong>ApkJoy</strong> is an app for extracting, saving, and sharing APK files seamlessly.</p>
<p><strong>Features:</strong></p>
<ul>
  <li><strong>Extraction:</strong> Quickly extract APK files from installed apps.</li>
  <li><strong>Storage:</strong> Save your APKs in a apps' location.</li>
  <li><strong>Sharing:</strong> Share APKs effortlessly with your friends.</li>
  <li><strong>Theme:</strong> Switch your theme to dark/light mode.</li>
  <li><strong>Your color:</strong> Set the apps' color to any color of your choice.</li>
  <li><strong>Adaptive:</strong> Uses modern design, adaptive icon and themes.</li>
  <li><strong>Fast:</strong>  Works fast, quickly get the apk of the app you want.</li>
  <li><strong>Search</strong> Never get lost looking for the app you want.</li>


</ul>
<p><strong>Version:</strong> 1.0.0<br>
<strong>License:</strong> MIT</p>
<br>
<div class="more">
<strong>ApkJoy</strong> is only for android, made with flutter.<br>
This project uses: 
<ul><li>Flutter</li><li>Dart</li><li>Kotlin</li><li>And more!</li></ul>
<br>
<div class="warning" style="background-color:#97463c; padding: 15px; border-radius: 20px;">
<h3 style="text-align:center;">Warning</h3>
<p>Since this app allows you to extract any apps, including system apps and lets you share them, be aware of compatibility. Some apps are made device-specific, those might not work on other devices. Some apps also might not work on older devices.
</div>
</div>
<p>For more details, visit our <a href="https://github.com/ShihanRishad/ApkJoy">GitHub repository</a>.</p>
<br>
<h3 style="text-align:center;">Made by Shihan</h3>
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About ApkJoy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        //  child: Html(data: htmlData),
        child: Html(
          data: htmlData,
          style: {
            ".more": Style(
              //  color: const Color.fromARGB(255, 61, 61, 61),
            ),
          },
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final bool isDark;
  final Function(bool) onToggleTheme;
  final bool showSystemApps;
  final Function(bool) onToggleSystemApps;
  final Future<void> Function() onResetSettings;

  const SettingsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.showSystemApps,
    required this.onToggleSystemApps,
    required this.onResetSettings,
  });

  Future<void> _confirmReset(BuildContext context) async {
    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Settings'),
            content: const Text(
              'Are you sure you want to reset all settings to default?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (shouldReset == true) {
      await onResetSettings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to default.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text("Dark Theme"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  trailing: Switch(value: isDark, onChanged: onToggleTheme),
                  onTap: () => onToggleTheme(!isDark),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text("Show System Apps"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  trailing: Switch(
                    value: showSystemApps,
                    onChanged: onToggleSystemApps,
                  ),
                  onTap: () => onToggleSystemApps(!showSystemApps),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text("Change App Theme Color"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  trailing: CircleAvatar(
                    backgroundColor: colorProvider.primaryColor,
                  ),
                  onTap: () => colorProvider.showColorPicker(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("About APKJoy"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text("Reset Settings"),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  onTap: () => _confirmReset(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
