import 'dart:io'; // FIXED
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // if (!kIsWeb && Platform.isMacOS) {
  //   if (!await _checkSingleInstance()) {
  //     print("Rescue Radar already running");
  //     //return; // NO EXIT
  //     exit(0);
  //   }
  // }

  runApp(const MyApp());
}

Future<bool> _checkSingleInstance() async {
  try {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    server.close();
    return true;
  } catch (e) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RRRS Rescue Radar',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const DashboardPage(),
    );
  }
}







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

