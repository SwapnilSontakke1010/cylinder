import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
  }

  // Fetch the app version dynamically using package_info_plus
  Future<void> _fetchAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version; // Set app version dynamically
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Error fetching version'; // Handle error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight Monitor $_appVersion', // Dynamic version in title
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(appVersion: _appVersion), // Pass version to MainPage
    );
  }
}

class MainPage extends StatefulWidget {
  final String appVersion;

  const MainPage({required this.appVersion, Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    WeightPage(),
    WiFiConfigPage(),
    TarePage(),
    CalibrationPage(),
  ];

  final List<String> _titles = [
    'Weight Monitor',
    'Wi-Fi Configuration',
    'Tare Command',
    'Calibration Command',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_titles[_selectedIndex]} ${widget.appVersion}'), // Show dynamic version
      ),
      body: _pages[_selectedIndex],
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Weight Monitor App ${widget.appVersion}', // Show dynamic version
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.monitor_weight),
              title: Text('Weight Monitoring'),
              onTap: () {
                _onItemTapped(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.wifi),
              title: Text('Wi-Fi Configuration'),
              onTap: () {
                _onItemTapped(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.send),
              title: Text('Tare Command'),
              onTap: () {
                _onItemTapped(2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.tune),
              title: Text('Calibration Command'),
              onTap: () {
                _onItemTapped(3);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}


class WeightPage extends StatefulWidget {
  @override
  _WeightPageState createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  List<Map<String, dynamic>> _weightHistory = [];
  bool _isLoading = true;

  Future<void> fetchWeightData() async {
    final database = FirebaseDatabase.instance;
    final ref = database.ref("weight");

    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _weightHistory = data.entries.map((entry) {
            final value = Map<String, dynamic>.from(entry.value as Map);
            return {
              'weight': value['current_weight'] ?? 0,
              'time': value['timestamp'] ?? '',
            };
          }).toList();
          _weightHistory.sort((a, b) => b['time'].compareTo(a['time']));
          _isLoading = false;
        });
      } else {
        _showError('No data available');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Failed to load data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    fetchWeightData();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Weight Readings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _weightHistory.isEmpty
                    ? Center(child: Text('No weight data available.'))
                    : ListView.builder(
                        itemCount: _weightHistory.length,
                        itemBuilder: (context, index) {
                          final history = _weightHistory[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.monitor_weight),
                              title: Text('${history['weight']} gm'),
                              subtitle: Text('Time: ${history['time']}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Wi-Fi Config Page
class WiFiConfigPage extends StatelessWidget {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> sendWiFiCredentials(BuildContext context) async {
    final ssid = _ssidController.text;
    final password = _passwordController.text;

    if (ssid.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter both SSID and Password')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.4.1/wifi'),
        body: {'ssid': ssid, 'password': password},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wi-Fi credentials sent successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send Wi-Fi credentials')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _ssidController,
            decoration: InputDecoration(labelText: 'SSID'),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: () => sendWiFiCredentials(context),
            child: Text('Send Wi-Fi Credentials'),
          ),
        ],
      ),
    );
  }
}

// Tare Page
class TarePage extends StatelessWidget {
  Future<void> sendTareCommand(BuildContext context) async {
    final database = FirebaseDatabase.instance;
    final tareRef = database.ref("tare_command");

    try {
      await tareRef.set("tare");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tare command sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send tare command: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => sendTareCommand(context),
        child: Text('Send Tare Command'),
      ),
    );
  }
}

// Calibration Page
class CalibrationPage extends StatelessWidget {
  final TextEditingController _calibrationController = TextEditingController();

  Future<void> sendCalibrationCommand(BuildContext context) async {
    final database = FirebaseDatabase.instance;
    final calibrationRef = database.ref("calibration");

    try {
      final weight = double.tryParse(_calibrationController.text);
      if (weight == null || weight <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid weight for calibration.')),
        );
        return;
      }
      await calibrationRef.set({'known_weight': weight});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration command sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send calibration command: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _calibrationController,
            decoration: InputDecoration(labelText: 'Calibration Weight (gm)'),
          ),
          ElevatedButton(
            onPressed: () => sendCalibrationCommand(context),
            child: Text('Send Calibration Command'),
          ),
        ],
      ),
    );
  }
}