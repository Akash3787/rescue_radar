import 'package:flutter/material.dart';

class DataLoggingScreen extends StatefulWidget {
  @override
  _DataLoggingScreenState createState() => _DataLoggingScreenState();
}

class _DataLoggingScreenState extends State<DataLoggingScreen> {
  final List<Map<String, dynamic>> _logData = List.generate(10, (index) => {
    "time": "14:${23 + index}:${45 + index}",
    "movement": index % 2 == 0 ? "Yes" : "No",
    "distance": (2.5 + index * 0.4).toStringAsFixed(1) + "m",
    "breathingRate": 15 + index % 8,
    "status": ["Active", "Analyzing", "Clear"][index % 3],
  });

  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Data Logging"),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            tooltip: "Export Logs",
            onPressed: () {
              // Export functionality placeholder
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search & filter row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search logs...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                    onChanged: (value) {
                      // Implement filter logic here
                    },
                  ),
                ),
                SizedBox(width: 12),
                DropdownButton<String>(
                  items: ["All", "Active", "Analyzing", "Clear"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    // Implement status filter logic here
                  },
                  hint: Text("Filter Status"),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Data table with dummy values
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text("Time")),
                    DataColumn(label: Text("Movement Detected")),
                    DataColumn(label: Text("Distance (m)")),
                    DataColumn(label: Text("Breathing Rate (bpm)")),
                    DataColumn(label: Text("Status")),
                  ],
                  rows: _logData.map((log) {
                    final movementColor = log["movement"] == "Yes" ? Colors.green : Colors.red;
                    final breathingRate = log["breathingRate"];
                    final breathingColor = breathingRate >= 20
                        ? Colors.red
                        : breathingRate >= 16
                        ? Colors.orange
                        : Colors.green;

                    final statusColor = {
                      "Active": Colors.blue,
                      "Analyzing": Colors.orange,
                      "Clear": Colors.green,
                    }[log["status"]]!;

                    return DataRow(
                      cells: [
                        DataCell(Text(log["time"])),
                        DataCell(Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: movementColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            log["movement"],
                            style: TextStyle(color: movementColor, fontWeight: FontWeight.bold),
                          ),
                        )),
                        DataCell(Text(log["distance"])),
                        DataCell(Text(
                          breathingRate.toString(),
                          style: TextStyle(color: breathingColor, fontWeight: FontWeight.bold),
                        )),
                        DataCell(Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            log["status"],
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            // Pagination controls & total entries
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Showing 1-10 of 247 entries"),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_currentPage > 1) setState(() => _currentPage--);
                      },
                      icon: Icon(Icons.chevron_left),
                    ),
                    for (int i = 1; i <= 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(i.toString()),
                          selected: _currentPage == i,
                          onSelected: (selected) {
                            if (selected) setState(() => _currentPage = i);
                          },
                        ),
                      ),
                    Text("..."),
                    ChoiceChip(
                      label: Text("10"),
                      selected: _currentPage == 10,
                      onSelected: (selected) {
                        if (selected) setState(() => _currentPage = 10);
                      },
                    ),
                    IconButton(
                      onPressed: () {
                        if (_currentPage < 10) setState(() => _currentPage++);
                      },
                      icon: Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
