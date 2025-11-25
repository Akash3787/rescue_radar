// import 'package:flutter/material.dart';
// import 'mapping_interface.dart';
// import 'live_graph_interface.dart';
// import 'home_page.dart';
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
//       title: 'Rescue Radar',
//       theme: ThemeData.dark(),
//
//       // CHANGE SCREEN HERE
//       //home: MappingInterface(),   // Radar screen
//       // home: CameraInterface(), // Camera screen (Uncomment to test)
//       //home: LiveGraphInterface(),
//       home: const HomePage(),
//     );
//   }
// }


// main.dart


// import 'package:flutter/material.dart';
// import 'dashboard_page.dart';
// import 'auth_page.dart';
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
//       // Start at auth (login/signup), NOT dashboard
//       home: const AuthPage(),
//     );
//   }
// }
//




import 'package:flutter/material.dart';
import 'dashboard_page.dart';

void main() {
  runApp(const MyApp());
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
