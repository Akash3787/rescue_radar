import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
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

  // Get current location (works on mobile and macOS)
  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Fetch weather from Open-Meteo API
  Future<void> _fetchWeather() async {
    try {
      double lat;
      double lon;
      String timezone = 'auto'; // Auto-detect timezone

      // Try to get current location (works on Android, iOS, and macOS)
      Position? position = await _getCurrentLocation();

      if (position != null) {
        lat = position.latitude;
        lon = position.longitude;
        print('Using device location: $lat, $lon');
      } else {
        // Fallback to default coordinates (Mumbai)
        lat = 19.0760;
        lon = 72.8777;
        timezone = 'Asia/Kolkata';
        print('Using fallback location: $lat, $lon');
      }

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?'
              'latitude=$lat&longitude=$lon&'
              'current_weather=true&hourly=relativehumidity_2m&'
              'timezone=$timezone'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['current_weather'] == null) {
          print('ERROR: current_weather not found in API response');
          setState(() {
            _weatherDescription = 'Weather data unavailable';
          });
          return;
        }

        final current = data['current_weather'];
        final code = current['weathercode'] as int? ?? 0;
        final temp = current['temperature'] as num? ?? 0.0;
        final windSpeed = current['windspeed'] as num? ?? 0.0;

        // Get humidity from hourly data
        int humidity = 0;
        if (data['hourly'] != null &&
            data['hourly']['relativehumidity_2m'] != null &&
            data['hourly']['time'] != null) {
          final humidityList = data['hourly']['relativehumidity_2m'] as List;
          final times = data['hourly']['time'] as List;
          final currentTime = current['time'] as String?;

          if (currentTime != null && times.isNotEmpty) {
            int index = times.indexOf(currentTime);
            if (index == -1 && times.isNotEmpty) {
              index = 0; // Use first available value if exact time not found
            }

            if (index >= 0 && index < humidityList.length) {
              humidity = humidityList[index] is int
                  ? humidityList[index]
                  : (humidityList[index] as num).round();
            }
          }
        }

        setState(() {
          _weatherTemp = '${temp.toStringAsFixed(1)}°C';
          _weatherCondition = _getWeatherIcon(code);
          _weatherWindSpeed = windSpeed.toDouble();
          _weatherHumidity = humidity;
          _weatherDescription = _getWeatherDescription(code);
        });
      } else {
        print('ERROR: API returned status code ${response.statusCode}');
        setState(() {
          _weatherDescription = 'Failed to fetch weather';
        });
      }
    } catch (e) {
      print('Weather fetch error: $e');
      setState(() {
        _weatherDescription = 'Error: ${e.toString()}';
        _weatherTemp = '--';
      });
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

  // Helper methods for responsive design
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1024;
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  double _getResponsivePadding(BuildContext context) {
    if (_isMobile(context)) return 12.0;
    if (_isTablet(context)) return 16.0;
    return 20.0;
  }

  double _getResponsiveSpacing(BuildContext context) {
    if (_isMobile(context)) return 12.0;
    if (_isTablet(context)) return 18.0;
    return 26.0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return baseSize * 0.85;
    if (width < 1024) return baseSize * 0.95;
    return baseSize;
  }

  int _getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1; // Mobile: 1 column
    if (width < 1024) return 2; // Tablet: 2 columns
    return 2; // Desktop: 2 columns (can be changed to 3 or 4 if needed)
  }

  double _getSidebarWidth(BuildContext context) {
    if (_isMobile(context)) return 0; // No sidebar on mobile
    if (_isTablet(context)) return 200;
    return 240;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isMobile = _isMobile(context);
    final double padding = _getResponsivePadding(context);
    final double spacing = _getResponsiveSpacing(context);


    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: isMobile ? _buildDrawer(context, isDarkMode) : null,
        body: Row(
          children: [
            // ========== SIDEBAR (Desktop/Tablet only) ==========
            if (!isMobile)
              Container(
                width: _getSidebarWidth(context),
                color: isDarkMode ? const Color(0xFF10131A) : Colors.white,
                child: _buildSidebarContent(context, isDarkMode),
              ),

            // ========== MAIN CONTENT ==========
            Expanded(
              child: Column(
                children: [
                  // ========== TOP BAR WITH WEATHER ==========
                  Container(
                    height: isMobile ? 56 : 60,
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: isMobile ? 8 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF151922) : Colors.white,
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
                        // Menu button for mobile
                        if (isMobile)
                          Builder(
                            // Use a fresh context so Scaffold is found when pressing the menu icon.
                            builder: (menuCtx) => IconButton(
                              icon: Icon(
                                Icons.menu,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              onPressed: () => Scaffold.of(menuCtx).openDrawer(),
                            ),
                          ),
                        Flexible(
                          flex: 0,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? double.infinity : 280,
                            ),
                            child: Text(
                              navItems[selectedIndex].title,
                              style: TextStyle(
                                fontSize: _getResponsiveFontSize(context, 20),
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
                        if (!isMobile)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing * 0.5,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey[800]?.withAlpha(100)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _weatherCondition,
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(context, 16),
                                  ),
                                ),
                                SizedBox(width: spacing * 0.25),
                                Text(
                                  _weatherTemp,
                                  style: TextStyle(
                                    fontSize: _getResponsiveFontSize(context, 14),
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isMobile) SizedBox(width: spacing * 0.5),
                        // Theme Toggle Switch
                        if (!isMobile)
                          Switch(
                            value: ThemeController.of(context)?.isDark ?? false,
                            onChanged: (value) {
                              ThemeController.of(context)?.onToggle(value);
                            },
                          ),
                        if (!isMobile) SizedBox(width: spacing * 0.5),
                        if (!isMobile)
                          Icon(
                            Icons.notifications,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        if (!isMobile) SizedBox(width: spacing * 0.5),
                        if (!isMobile)
                          CircleAvatar(
                            radius: isMobile ? 16 : 18,
                            backgroundColor: isDarkMode
                                ? Colors.cyanAccent
                                : Colors.teal[700],
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: isMobile ? 18 : 20,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ========== BODY WITH GRID + ACTION BUTTONS ==========
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Stack(
                        children: [
                          // Main Content Grid
                          selectedIndex == 0
                              ? _buildDashboardGrid(context, isDarkMode)
                              : selectedIndex == 5
                              ? _buildWeatherPage(context, isDarkMode)
                              : pages[selectedIndex - 1],

                          // ========== ACTION BUTTONS (SOS + LED) ==========
                          Positioned(
                            bottom: padding * 2,
                            right: padding * 1.5,
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
                                  isMobile: isMobile,
                                ),
                                SizedBox(height: spacing * 0.4),
                                // LED Light Control Button
                                // _ModernToggleSwitch(
                                //   isActive: isLightOn,
                                //   title: 'LED',
                                //   activeColor: const Color(0xFF2ED573),
                                //   icon: isLightOn
                                //       ? Icons.lightbulb
                                //       : Icons.lightbulb_outline,
                                //   onTap: () {
                                //     setState(() {
                                //       isLightOn = !isLightOn;
                                //     });
                                //     _toggleLight(isLightOn);
                                //   },
                                //   isMobile: isMobile,
                                // ),
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
      ),
    );
  }

  // Build sidebar content (reusable for drawer and sidebar)
  Widget _buildSidebarContent(BuildContext context, bool isDarkMode) {
    return Column(
      children: [
        SizedBox(height: _getResponsivePadding(context) * 2),
        Text(
          'Radar Rescue',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 28),
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.cyanAccent : Colors.teal[800],
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: _getResponsivePadding(context) * 0.67),
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
                dense: _isMobile(context),
                leading: Icon(
                  navItems[index].icon,
                  color: active ? activeColor : inactiveColor,
                ),
                title: Text(
                  navItems[index].title,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
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
                onTap: () {
                  setState(() => selectedIndex = index);
                  if (_isMobile(context)) {
                    Navigator.of(context).pop(); // Close drawer
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Build drawer for mobile
  Widget _buildDrawer(BuildContext context, bool isDarkMode) {
    return Drawer(
      backgroundColor: isDarkMode ? const Color(0xFF10131A) : Colors.white,
      child: _buildSidebarContent(context, isDarkMode),
    );
  }

  // ========== BUILD WEATHER PAGE ==========
  Widget _buildWeatherPage(BuildContext context, bool isDarkMode) {
    final now = DateTime.now();
    final dateFormatter = '${now.day}/${now.month}/${now.year}';
    final timeFormatter =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final padding = _getResponsivePadding(context);
    final isMobile = _isMobile(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large Weather Icon
            Text(
              _weatherCondition,
              style: TextStyle(
                fontSize: isMobile ? 64 : 96,
              ),
            ),
            SizedBox(height: padding * 2),

            // Temperature Card
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
              padding: EdgeInsets.all(padding * 2),
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
                      fontSize: _getResponsiveFontSize(context, 14),
                      color: isDarkMode
                          ? Colors.white70
                          : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: padding * 0.67),
                  Text(
                    _weatherTemp,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 48),
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? Colors.cyanAccent
                          : Colors.blue[700],
                    ),
                  ),
                  SizedBox(height: padding * 0.67),
                  Text(
                    _weatherDescription,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 18),
                      color: isDarkMode
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: padding * 2.67),

            // Date & Time Section
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
              padding: EdgeInsets.all(padding * 1.67),
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
                            size: isMobile ? 28 : 32,
                          ),
                          SizedBox(height: padding * 0.67),
                          Text(
                            'Date',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            dateFormatter,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 16),
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
                            size: isMobile ? 28 : 32,
                          ),
                          SizedBox(height: padding * 0.67),
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 12),
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            timeFormatter,
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(context, 16),
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
            // Additional Weather Details
            Wrap(
              spacing: padding,
              runSpacing: padding,
              alignment: WrapAlignment.center,
              children: [
                // Wind Speed
                Container(
                  padding: EdgeInsets.all(padding * 1.33),
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
                        size: isMobile ? 24 : 28,
                      ),
                      SizedBox(height: padding * 0.67),
                      Text(
                        'Wind Speed',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 11),
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_weatherWindSpeed.toStringAsFixed(1)} km/h',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Humidity
                Container(
                  padding: EdgeInsets.all(padding * 1.33),
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
                        size: isMobile ? 24 : 28,
                      ),
                      SizedBox(height: padding * 0.67),
                      Text(
                        'Humidity',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 11),
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$_weatherHumidity%',
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 14),
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
  Widget _buildDashboardGrid(BuildContext context, bool isDarkMode) {
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
        title: 'Live Graph',
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

    final crossAxisCount = _getGridCrossAxisCount(context);
    final spacing = _getResponsiveSpacing(context);
    final isMobile = _isMobile(context);

    return GridView.builder(
      itemCount: cardData.length,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: isMobile ? 1.2 : 1.1,
      ),
      itemBuilder: (context, index) {
        final card = cardData[index];
        return _DashboardNeatCard(
          data: card,
          isDarkMode: isDarkMode,
          parentContext: context,
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
  final bool isMobile;

  const _ModernToggleSwitch({
    required this.isActive,
    required this.title,
    required this.activeColor,
    required this.icon,
    required this.onTap,
    this.isMobile = false,
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
              width: widget.isMobile ? 80 : 100,
              padding: EdgeInsets.symmetric(
                vertical: widget.isMobile ? 8 : 10,
                horizontal: widget.isMobile ? 10 : 14,
              ),
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
  final BuildContext parentContext;

  const _DashboardNeatCard({
    required this.data,
    required this.isDarkMode,
    required this.parentContext,
  });

  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return baseSize * 0.85;
    if (width < 1024) return baseSize * 0.95;
    return baseSize;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    final padding = isMobile ? 12.0 : 16.0;
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
          padding: EdgeInsets.all(padding),
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
                        fontSize: _getResponsiveFontSize(context, 18),
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: isMobile ? 16 : 18,
                    color: Colors.white60,
                  ),
                ],
              ),
              SizedBox(height: padding * 0.5),
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
                  padding: EdgeInsets.all(padding * 0.375),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(data.imageAsset),
                  ),
                ),
              ),
              SizedBox(height: padding * 0.625),
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
                        fontSize: _getResponsiveFontSize(context, 13),
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ),
                  SizedBox(width: padding * 0.5),
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
