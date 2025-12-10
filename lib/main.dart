import 'package:flutter/material.dart';

import 'dashboard_page.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }
void main() {
  debugPrint('🔥 RESCUE RADAR BUILD #3 STARTED');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Default: LIGHT mode
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    // Softer light theme, not pure white
    final ThemeData softLightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
        background: const Color(0xFFF1F3F7),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F3F7),
    );

    // Slightly tweaked dark theme
    final ThemeData softDarkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.tealAccent,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF07090C),
    );

    return ThemeController(
      isDark: _themeMode == ThemeMode.dark,
      onToggle: (isDark) {
        setState(() {
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        });
      },
      //
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RRRS Rescue Radar',
        theme: softLightTheme,
        darkTheme: softDarkTheme,
        themeMode: _themeMode,
        home: const DashboardPage(),
      ),
    );
  }
}

// Inherited widget to provide theme toggle to all pages
class ThemeController extends InheritedWidget {
  final bool isDark;
  final ValueChanged<bool> onToggle;

  const ThemeController({
    super.key,
    required Widget child,
    required this.isDark,
    required this.onToggle,
  }) : super(child: child);

  static ThemeController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeController>();
  }

  @override
  bool updateShouldNotify(covariant ThemeController oldWidget) {
    return isDark != oldWidget.isDark;
  }
}




// import 'dart:io'; // FIXED
// import 'package:flutter/foundation.dart'; // kIsWeb
// import 'package:flutter/material.dart';
// import 'dashboard_page.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // if (!kIsWeb && Platform.isMacOS) {
//   //   if (!await _checkSingleInstance()) {
//   //     print("Rescue Radar already running");
//   //     //return; // NO EXIT
//   //     exit(0);
//   //   }
//   // }
//
//   runApp(const MyApp());
// }
//
// Future<bool> _checkSingleInstance() async {
//   try {
//     final server = await ServerSocket.bind('127.0.0.1', 0);
//     server.close();
//     return true;
//   } catch (e) {
//     return false;
//   }
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'RRRS Rescue Radar',
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       home: const DashboardPage(),
//     );
//   }
// }







// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dashboard_page.dart'; // Update this import path
//
// void main() async {
//   // ✅ SINGLE INSTANCE CHECK - Prevents split windows
//   if (await _checkSingleInstance()) {
//     WidgetsFlutterBinding.ensureInitialized();
//
//     // ✅ Force single window behavior
//     LicenseRegistry.addLicense(() async* {
//       // Empty license to prevent duplicate launches
//     });
//
//     runApp(const MyApp());
//   } else {
//     print("Rescue Radar already running - focusing existing window");
//     exit(0);
//   }
// }
//
// // ✅ SINGLE INSTANCE DETECTOR
// Future<bool> _checkSingleInstance() async {
//   try {
//     // Try to bind to localhost port - fails if app already running
//     final server = await ServerSocket.bind('127.0.0.1', 0);
//     server.close();
//     return true; // Port available = first instance
//   } catch (e) {
//     return false; // Port busy = duplicate instance
//   }
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'RRRS Rescue Radar',
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       // ✅ SINGLE WINDOW ONLY
//       builder: (context, child) {
//         return MediaQuery(
//           data: MediaQuery.of(context).copyWith(
//             gestureSettings: const DeviceGestureSettings(
//               touchSlop: 8.0,
//             ),
//           ),
//           child: child!,
//         );
//       },
//       home: const DashboardPage(),
//     );
//   }
// }









//
// import 'package:flutter/material.dart';
// import 'dashboard_page.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'RRRS Rescue Radar',
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       home: const DashboardPage(),
//     );
//   }
// }

