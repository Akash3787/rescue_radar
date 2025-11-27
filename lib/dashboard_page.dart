import 'package:flutter/material.dart';
import 'mapping_interface.dart';
import 'camera_interface.dart';
import 'live_graph_interface.dart';
import 'victim_readings_page.dart';

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

  final List<Widget> pages = [
    const VictimReadingsPage(),
    //const VictimReadingsPage(),
    const MappingInterface(),
    const LiveGraphInterface(),
    CameraInterface(),

  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDarkMode ? const Color(0xFF07090C) : const Color(0xFFF5F7FA),
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
                            ? Colors.blue.withValues(alpha: 0.15)
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
                // TOP BAR (updated)
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color:
                    isDarkMode ? const Color(0xFF151922) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Page title
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

                      // Search bar (responsive)
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 420,
                          minWidth: 120,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextField(
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDarkMode
                                  ? const Color(0xFF1C212C)
                                  : const Color(0xFFF0F2F5),
                              prefixIcon: Icon(
                                Icons.search,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black38,
                              ),
                              hintText: 'Search...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Icon(
                        Icons.notifications,
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                      ),
                      const SizedBox(width: 12),

                      CircleAvatar(
                        backgroundColor:
                        isDarkMode ? Colors.cyanAccent : Colors.teal[700],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // BODY
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: selectedIndex == 0
                        ? _buildDashboardGrid(isDarkMode)
                        : pages[selectedIndex - 1],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ========== DASHBOARD GRID ==========

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
        imageAsset: 'images/heart.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(const LiveGraphInterface()),
      ),
      _DashboardCardData(
        title: 'Camera Interface',
        description: 'Visual access via cameras',
        imageAsset: 'images/cam inter.png',
        accent: Colors.cyanAccent,
        onTap: () => _navigateTo(VictimReadingsPage()),
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
        ? data.accent.withValues(alpha: 0.55)
        : Colors.blueGrey.withValues(alpha: 0.45);

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
                color: data.accent.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.05),
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
                        color:
                        isDarkMode ? Colors.white70 : Colors.black54,
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