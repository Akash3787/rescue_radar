import 'package:flutter/material.dart';
import 'mapping_interface.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rescue Radar',
      theme: ThemeData.dark(),
      home: MappingInterface(),  // <-- THIS SHOWS YOUR RADAR
    );
  }
}