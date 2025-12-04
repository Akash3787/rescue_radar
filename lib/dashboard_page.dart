import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'mapping_interface.dart';
import 'camera_interface.dart';
import 'live_graph_interface.dart';
import 'victim_readings_page.dart';
import 'main.dart'; // for ThemeController

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
  ];

  int selectedIndex = 0;
  bool isLightOn = false; // LED Toggle State

  final List<Widget> pages = [
    const VictimReadingsPage(),
    const MappingInterface(),
    const LiveGraphInterface(),
    CameraInterface(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // SIDEBAR
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
                            fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
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

          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                // TOP BAR
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
                              color:
                              isDarkMode ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // ConstrainedBox(
                      //   constraints: const BoxConstraints(
                      //     maxWidth: 420,
                      //     minWidth: 120,
                      //   ),
                      //   child: SizedBox(
                      //     width: double.infinity,
                      //     child: TextField(
                      //       style: TextStyle(
                      //         color:
                      //         isDarkMode ? Colors.white : Colors.black87,
                      //       ),
                      //       decoration: InputDecoration(
                      //         filled: true,
                      //         fillColor: isDarkMode
                      //             ? const Color(0xFF1C212C)
                      //             : const Color(0xFFF0F2F5),
                      //         prefixIcon: Icon(
                      //           Icons.search,
                      //           color: isDarkMode
                      //               ? Colors.white54
                      //               : Colors.black38,
                      //         ),
                      //         hintText: 'Search...',
                      //         border: OutlineInputBorder(
                      //           borderRadius: BorderRadius.circular(8),
                      //           borderSide: BorderSide.none,
                      //         ),
                      //         isDense: true,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(width: 12),
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

                // BODY WITH GRID + BUTTONS (STACK)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Stack(
                      children: [
                        // Original Grid
                        selectedIndex == 0
                            ? _buildDashboardGrid(isDarkMode)
                            : pages[selectedIndex - 1],

                        // Modern Toggle Switches (Virtual Box Position - Bottom Left)
                        Positioned(
                          bottom: 40,
                          right: 30,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // SOS Toggle Switch (No white circle)
                              _ModernToggleSwitch(
                                isActive: true,
                                title: 'SOS',
                                activeColor: const Color(0xFFFF4757),
                                icon: Icons.warning_amber_rounded,
                                onTap: _sendSOSAlert,
                              ),
                              const SizedBox(height: 10),
                              // Light Toggle Switch (No white circle)
                              _ModernToggleSwitch(
                                isActive: isLightOn,
                                title: 'LED',
                                activeColor: const Color(0xFF2ED573),
                                icon: isLightOn ? Icons.lightbulb : Icons.lightbulb_outline,
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

  // SEND SOS TO FLASK → ESP
  void _sendSOSAlert() async {
    final url = Uri.parse("http://your-flask-server-ip/send-sos");
    await http.post(url);
  }

  void _toggleLight(bool status) async {
    final url = Uri.parse("http://your-flask-server-ip/toggle-light");
    await http.post(url, body: {"status": status ? "ON" : "OFF"});
  }

  Widget _buildDashboardGrid(bool isDarkMode) {
    final cardData = [
      _DashboardCardData(
        title: 'Data Logging',
        description: 'View logged sensor data',
        imageAsset: 'images/data logging.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const VictimReadingsPage()),
      ),
      _DashboardCardData(
        title: 'Mapping Interface',
        description: 'View and control radar mapping',
        imageAsset: 'images/map.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const MappingInterface()),
      ),
      _DashboardCardData(
        title: 'Live Heartbeat Graph',
        description: 'Monitor live vital signs',
        imageAsset: 'images/LiveGraph.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const LiveGraphInterface()),
      ),
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

  void _navigateTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

// ========== MODERN TOGGLE SWITCH ==========
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
                    color: widget.activeColor.withOpacity(_glowAnimation.value),
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
                  // White circle COMPLETELY REMOVED from both switches
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ========== CARD WIDGET ==========
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
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.white60,
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

// ========== MODELS ==========
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