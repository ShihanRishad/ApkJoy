import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/services.dart';
import 'color_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ColorProvider(prefs: prefs), // Pass SharedPreferences instance to ColorProvider
      child: ApkJoyApp(prefs: prefs),
    ),
  );
}

/// Root widget that holds global theme settings and system apps toggle.
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
  }

  /// Load the settings from SharedPreferences
  void _loadSettings() {
    setState(() {
      _themeMode = widget.prefs.getString('themeMode') == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
      _showSystemApps = widget.prefs.getBool('showSystemApps') ?? false;
    });
  }

  /// Save settings to SharedPreferences.
  Future<void> _saveSettings() async {
    await widget.prefs.setString('themeMode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    await widget.prefs.setBool('showSystemApps', _showSystemApps);
  }

  /// Toggle between dark and light themes.
  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _saveSettings();
  }

  /// Toggle showing system apps.
  void _toggleSystemApps(bool value) {
    setState(() {
      _showSystemApps = value;
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);

    return MaterialApp(
      title: 'ApkJoy',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorProvider.primaryColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorProvider.primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      home: AppListPage(
        onToggleTheme: _toggleTheme,
        currentThemeMode: _themeMode,
        showSystemApps: _showSystemApps,
        onToggleSystemApps: _toggleSystemApps,
      ),
    );
  }
}

class AppListPage extends StatefulWidget {
  final Function(bool) onToggleTheme;
  final ThemeMode currentThemeMode;
  final bool showSystemApps;
  final Function(bool) onToggleSystemApps;

  const AppListPage({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
    required this.showSystemApps,
    required this.onToggleSystemApps,
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
    _appsFuture = DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: widget.showSystemApps,
    );
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
                  builder: (_) => SettingsPage(
                    isDark: widget.currentThemeMode == ThemeMode.dark,
                    onToggleTheme: widget.onToggleTheme,
                    showSystemApps: widget.showSystemApps,
                    onToggleSystemApps: widget.onToggleSystemApps,
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
                  borderRadius: BorderRadius.circular(12),
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
          final apps = snapshot.data!;
          final filteredApps = apps.where((app) {
            return app.appName.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
          return ListView.builder(
            itemCount: filteredApps.length,
            itemBuilder: (context, index) {
              final app = filteredApps[index];
              return ListTile(
                leading: app is ApplicationWithIcon
                    ? Image.memory(app.icon, width: 40, height: 40)
                    : null,
                title: Text(app.appName),
                subtitle: Text(app.packageName),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppDetailPage(app: app),
                    ),
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

class AppDetailPage extends StatefulWidget {
  final Application app;
  const AppDetailPage({super.key, required this.app});

  @override
  _AppDetailPageState createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  static const platform = MethodChannel('apk_extractor');
  String _status = '';

  Future<void> extractApk() async {
    try {
      final String apkPath = await platform.invokeMethod('extractApk', {
        'packageName': widget.app.packageName,
      });
      setState(() {
        _status = 'APK extracted to:\n$apkPath';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.appName),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
                  Text(
                    widget.app.appName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.app.packageName,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Extract APK'),
                    onPressed: extractApk,
                  ),
                  const SizedBox(height: 24),
                  if (_status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
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

class SettingsPage extends StatelessWidget {
  final bool isDark;
  final Function(bool) onToggleTheme;
  final bool showSystemApps;
  final Function(bool) onToggleSystemApps;

  const SettingsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.showSystemApps,
    required this.onToggleSystemApps,
  });

  @override
  Widget build(BuildContext context) {
    final colorProvider = Provider.of<ColorProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Dark Theme",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Switch(
                      value: isDark,
                      onChanged: (value) {
                        onToggleTheme(value);
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Show System Apps",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Switch(
                      value: showSystemApps,
                      onChanged: (value) {
                        onToggleSystemApps(value);
                      },
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  title: const Text("Change App Theme Color"),
                  trailing: CircleAvatar(
                    backgroundColor: colorProvider.primaryColor,
                  ),
                  onTap: () {
                    colorProvider.showColorPicker(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
