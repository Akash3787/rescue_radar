import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'mapping_interface.dart';
import 'camera_interface.dart';
import 'live_graph_interface.dart';
import 'victim_readings_page.dart';
import 'main.dart'; // for ThemeController
import 'dart:convert';
import 'dart:async';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<_NavItem> navItems = [
    _NavItem('Dashboard', Icons.dashboard),
    _NavItem('Data Logging', Icons.table_chart),
    _NavItem('Mapping', Icons.radar),
    _NavItem('Live Graphs', Icons.show_chart),
    _NavItem('Camera', Icons.camera_alt),
    _NavItem('Weather', Icons.cloud),  // ✅ NEW WEATHER NAV ITEM
  ];

  // Weather state variables
  String _weatherTemp = '--';
  String _weatherCondition = 'Loading...';
  String _weatherDescription = '';
  double _weatherWindSpeed = 0;
  int _weatherHumidity = 0;

  int selectedIndex = 0;
  bool isLightOn = false;

  final List<Widget> pages = [
    const VictimReadingsPage(),
    const MappingInterface(),
    const LiveGraphInterface(),
    CameraInterface(),
    // Weather page will be handled separately
  ];

  // Initialize weather
  @override
  void initState() {
    super.initState();
    _fetchWeather();
    Timer.periodic(const Duration(minutes: 5), (timer) => _fetchWeather());
  }

  // Fetch weather from Open-Meteo API
  Future<void> _fetchWeather() async {
    try {
      final lat = 10.9974;  // Mumbai rescue site coordinates - UPDATE TO YOUR LOCATION
      final lon = 76.9589;

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?'
              'latitude=$lat&longitude=$lon&'
              'current_weather=true&timezone=Asia/Kolkata'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current_weather'];

        setState(() {
          _weatherTemp = '${current['temperature'].toStringAsFixed(1)}°C';
          _weatherCondition = _getWeatherIcon(current['weathercode']);
          _weatherWindSpeed = (current['windspeed'] ?? 0).toDouble();
          _weatherHumidity = current['humidity'] ?? 0;
          _weatherDescription = _getWeatherDescription(current['weathercode']);
        });
      }
    } catch (e) {
      print('Weather fetch error: $e');
    }
  }

  // Convert WMO weather code to emoji
  String _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return '🌤️'; // Clear sky
      case 1:
      case 2:
      case 3:
        return '☁️'; // Cloudy
      case 45:
      case 48:
        return '🌫️'; // Foggy
      case 51:
      case 53:
      case 55:
        return '🌧️'; // Drizzle
      case 61:
      case 63:
      case 65:
        return '🌧️'; // Rain
      case 71:
      case 73:
      case 75:
        return '🌨️'; // Snow
      case 77:
        return '🌨️'; // Snow grains
      case 80:
      case 81:
      case 82:
        return '🌧️'; // Rain showers
      case 85:
      case 86:
        return '🌨️'; // Snow showers
      case 95:
      case 96:
      case 99:
        return '⛈️'; // Thunderstorm
      default:
        return '🌫️'; // Unknown
    }
  }

  // Get weather description from code
  String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
      case 2:
        return 'Mostly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rainy';
      case 71:
      case 73:
      case 75:
        return 'Snowy';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // ========== SIDEBAR ==========
          Container(
            width: 240,
            color: isDarkMode ? const Color(0xFF10131A) : Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Radar Rescue',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.cyanAccent : Colors.teal[800],
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final active = index == selectedIndex;
                      final activeColor =
                      isDarkMode ? Colors.cyanAccent : Colors.blue;
                      final inactiveColor =
                      isDarkMode ? Colors.white70 : Colors.black54;

                      return ListTile(
                        leading: Icon(
                          navItems[index].icon,
                          color: active ? activeColor : inactiveColor,
                        ),
                        title: Text(
                          navItems[index].title,
                          style: TextStyle(
                            color: active ? activeColor : inactiveColor,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        tileColor: active
                            ? (isDarkMode
                            ? Colors.blue.withAlpha(40)
                            : Colors.blue[50])
                            : Colors.transparent,
                        onTap: () => setState(() => selectedIndex = index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ========== MAIN CONTENT ==========
          Expanded(
            child: Column(
              children: [
                // ========== TOP BAR WITH WEATHER ==========
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color:
                    isDarkMode ? const Color(0xFF151922) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withAlpha(150)
                            : Colors.grey.withAlpha(100),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            navItems[selectedIndex].title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ✅ WEATHER DISPLAY IN TOP BAR
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey[800]?.withAlpha(100)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _weatherCondition,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _weatherTemp,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Theme Toggle Switch
                      Switch(
                        value:
                        ThemeController.of(context)?.isDark ?? false,
                        onChanged: (value) {
                          ThemeController.of(context)?.onToggle(value);
                        },
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.notifications,
                        color:
                        isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        backgroundColor: isDarkMode
                            ? Colors.cyanAccent
                            : Colors.teal[700],
                        child:
                        const Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // ========== BODY WITH GRID + ACTION BUTTONS ==========
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Stack(
                      children: [
                        // Main Content Grid
                        selectedIndex == 0
                            ? _buildDashboardGrid(isDarkMode)
                            : selectedIndex == 5
                            ? _buildWeatherPage(isDarkMode)
                            : pages[selectedIndex - 1],

                        // ========== ACTION BUTTONS (SOS + LED) ==========
                        Positioned(
                          bottom: 40,
                          right: 30,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // SOS Emergency Button
                              _ModernToggleSwitch(
                                isActive: true,
                                title: 'SOS',
                                activeColor: const Color(0xFFFF4757),
                                icon: Icons.warning_amber_rounded,
                                onTap: _sendSOSAlert,
                              ),
                              const SizedBox(height: 10),
                              // LED Light Control Button
                              _ModernToggleSwitch(
                                isActive: isLightOn,
                                title: 'LED',
                                activeColor: const Color(0xFF2ED573),
                                icon: isLightOn
                                    ? Icons.lightbulb
                                    : Icons.lightbulb_outline,
                                onTap: () {
                                  setState(() {
                                    isLightOn = !isLightOn;
                                  });
                                  _toggleLight(isLightOn);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== BUILD WEATHER PAGE ==========
  Widget _buildWeatherPage(bool isDarkMode) {
    final now = DateTime.now();
    final dateFormatter = '${now.day}/${now.month}/${now.year}';
    final timeFormatter =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large Weather Icon
            Text(
              _weatherCondition,
              style: const TextStyle(fontSize: 96),
            ),
            const SizedBox(height: 24),

            // Temperature Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1C212C)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.cyanAccent.withAlpha(100)
                      : Colors.blue.withAlpha(100),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Temperature',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _weatherTemp,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.cyanAccent
                          : Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _weatherDescription,
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Date & Time Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1C212C)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.cyanAccent.withAlpha(100)
                      : Colors.blue.withAlpha(100),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: isDarkMode
                                ? Colors.cyanAccent
                                : Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormatter,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: isDarkMode
                                ? Colors.cyanAccent
                                : Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeFormatter,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Additional Weather Details
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Wind Speed
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1C212C)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.cyanAccent.withAlpha(100)
                          : Colors.blue.withAlpha(100),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.air,
                        color: isDarkMode
                            ? Colors.cyanAccent
                            : Colors.blue,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wind Speed',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_weatherWindSpeed.toStringAsFixed(1)} km/h',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Humidity (Placeholder)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1C212C)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.cyanAccent.withAlpha(100)
                          : Colors.blue.withAlpha(100),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.opacity,
                        color: isDarkMode
                            ? Colors.cyanAccent
                            : Colors.blue,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Humidity',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_weatherHumidity%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== BUILD DASHBOARD GRID ==========
  Widget _buildDashboardGrid(bool isDarkMode) {
    final cardData = [
      // Data Logging Card
      _DashboardCardData(
        title: 'Data Logging',
        description: 'View logged sensor data',
        imageAsset: 'images/data logging.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const VictimReadingsPage()),
      ),
      // Mapping Interface Card
      _DashboardCardData(
        title: 'Mapping Interface',
        description: 'View and control radar mapping',
        imageAsset: 'images/map.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const MappingInterface()),
      ),
      // Live Graph Card
      _DashboardCardData(
        title: 'Live Heartbeat Graph',
        description: 'Monitor live vital signs',
        imageAsset: 'images/LiveGraph.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const LiveGraphInterface()),
      ),
      // Camera Interface Card
      _DashboardCardData(
        title: 'Camera Interface',
        description: 'Visual access via cameras',
        imageAsset: 'images/cam inter.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(CameraInterface()),
      ),
    ];

    return GridView.builder(
      itemCount: cardData.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 26,
        mainAxisSpacing: 26,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final card = cardData[index];
        return _DashboardNeatCard(
          data: card,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  // ========== SEND SOS ALERT TO FLASK/ESP ==========
  void _sendSOSAlert() async {
    final url = Uri.parse("http://your-flask-server-ip/send-sos");
    try {
      await http.post(url);
      print('SOS Alert Sent!');
    } catch (e) {
      print('SOS error: $e');
    }
  }

  // ========== TOGGLE LED LIGHT ==========
  void _toggleLight(bool status) async {
    final url = Uri.parse("http://your-flask-server-ip/toggle-light");
    try {
      await http.post(url, body: {"status": status ? "ON" : "OFF"});
      print('LED toggled: $status');
    } catch (e) {
      print('Light toggle error: $e');
    }
  }

  void _navigateTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

// ========== MODERN TOGGLE SWITCH WIDGET ==========
class _ModernToggleSwitch extends StatefulWidget {
  final bool isActive;
  final String title;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onTap;

  const _ModernToggleSwitch({
    required this.isActive,
    required this.title,
    required this.activeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  _ModernToggleSwitchState createState() => _ModernToggleSwitchState();
}

class _ModernToggleSwitchState extends State<_ModernToggleSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.2,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ModernToggleSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: widget.isActive
                      ? [
                    widget.activeColor,
                    widget.activeColor.withOpacity(0.8),
                  ]
                      : isDarkMode
                      ? [
                    const Color(0xFF2A2E3D),
                    const Color(0xFF1F2332),
                  ]
                      : [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.activeColor
                        .withOpacity(_glowAnimation.value),
                    blurRadius: 15,
                    spreadRadius: widget.isActive ? 1 : 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: widget.isActive
                      ? widget.activeColor.withOpacity(0.5)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ========== DASHBOARD CARD WIDGET ==========
class _DashboardNeatCard extends StatelessWidget {
  final _DashboardCardData data;
  final bool isDarkMode;

  const _DashboardNeatCard({
    required this.data,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDarkMode
        ? data.accent.withAlpha(140)
        : Colors.blueGrey.withAlpha(120);

    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDarkMode ? const Color(0xFF11141C) : Colors.white,
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            if (isDarkMode)
              BoxShadow(
                color: data.accent.withAlpha(40),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            else
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Title Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white60,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Card Image Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF0B0E15)
                        : const Color(0xFFF2F4F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withAlpha(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(data.imageAsset),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Card Description + Arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      data.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: data.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== DATA MODELS ==========
class _NavItem {
  final String title;
  final IconData icon;

  _NavItem(this.title, this.icon);
}

class _DashboardCardData {
  final String title;
  final String description;
  final String imageAsset;
  final Color accent;
  final VoidCallback onTap;

  _DashboardCardData({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.accent,
    required this.onTap,
  });
}
