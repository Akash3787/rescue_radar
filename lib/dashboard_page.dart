import 'package:flutter/material.dart';
import 'mapping_interface.dart';
import 'live_graph_interface.dart';

// Uncomment and create these pages if available:
// import 'camera_interface.dart';
// import 'data_logging_interface.dart';

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
    const Center(child: Text('Dashboard Overview', style: TextStyle(fontSize: 24))),
    // Uncomment once created:
    // const DataLoggingInterface(),
    const MappingInterface(),
    const LiveGraphInterface(),
    // const CameraInterface(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1D23) : const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: isDarkMode ? const Color(0xFF121620) : Colors.white,
            child: Column(
              children: [
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  child: Text(
                    'RRRS',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.cyanAccent : Colors.teal[800],
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      bool active = index == selectedIndex;
                      return ListTile(
                        leading: Icon(
                          navItems[index].icon,
                          color: active
                              ? (isDarkMode ? Colors.cyanAccent : Colors.blue)
                              : (isDarkMode ? Colors.white70 : Colors.black54),
                        ),
                        title: Text(
                          navItems[index].title,
                          style: TextStyle(
                            color: active
                                ? (isDarkMode ? Colors.cyanAccent : Colors.blue)
                                : (isDarkMode ? Colors.white70 : Colors.black54),
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        tileColor: active
                            ? (isDarkMode ? Colors.blue.withOpacity(0.15) : Colors.blue[50])
                            : Colors.transparent,
                        onTap: () => setState(() => selectedIndex = index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF252932) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.black54 : Colors.grey.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          navItems[selectedIndex].title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  color: isDarkMode ? Colors.white70 : Colors.black45),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Search...',
                                    hintStyle: TextStyle(
                                      color: isDarkMode ? Colors.white54 : Colors.black38,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.notifications,
                          color: isDarkMode ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        backgroundColor: isDarkMode ? Colors.cyanAccent : Colors.teal[700],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child:
                    selectedIndex == 0 ? _buildDashboardGrid(isDarkMode) : pages[selectedIndex - 1],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid(bool isDarkMode) {
    final cardData = [
      _DashboardCardData(
        title: 'Data Logging',
        icon: Icons.table_chart,
        description: 'View logged sensor data',
        onTap: () {
          // Add navigation once implemented
        },
      ),
      _DashboardCardData(
        title: 'Mapping Interface',
        icon: Icons.radar,
        description: 'View and control radar mapping',
        onTap: () => _navigateTo(const MappingInterface()),
      ),
      _DashboardCardData(
        title: 'Live Heartbeat Graph',
        icon: Icons.show_chart,
        description: 'Monitor live vital signs',
        onTap: () => _navigateTo(const LiveGraphInterface()),
      ),
      _DashboardCardData(
        title: 'Camera Interface',
        icon: Icons.camera_alt,
        description: 'Visual access via cameras',
        onTap: () {
          // Add navigation once implemented
        },
      ),
    ];

    return GridView.builder(
      itemCount: cardData.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 30,
        mainAxisSpacing: 30,
        childAspectRatio: 4 / 3,
      ),
      itemBuilder: (context, index) {
        final card = cardData[index];
        return GestureDetector(
          onTap: card.onTap,
          child: Card(
            color: isDarkMode ? const Color(0xFF252932) : Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: isDarkMode ? Colors.cyanAccent.withOpacity(0.7) : Colors.grey.shade300,
                  width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: isDarkMode ? Colors.cyanAccent.withOpacity(0.4) : Colors.grey[300],
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(card.icon, size: 48, color: isDarkMode ? Colors.cyanAccent : Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    card.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: isDarkMode ? Colors.cyanAccent : Colors.blue,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  _NavItem(this.title, this.icon);
}

class _DashboardCardData {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;
  _DashboardCardData({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });
}
