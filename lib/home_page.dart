import 'package:flutter/material.dart';
import 'mapping_interface.dart';
import 'live_graph_interface.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Rescue Radar — Control Center"),
        backgroundColor: Colors.teal[800],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(context, "Radar Mapping Interface", const MappingInterface()),
            const SizedBox(height: 20),
            _btn(context, "Live Heartbeat Graph", const LiveGraphInterface()),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, String label, Widget page) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
      ),
      onPressed: () => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => page),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}