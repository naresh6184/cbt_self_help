import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class ThoughtRecordPage extends StatefulWidget {
  const ThoughtRecordPage({super.key});

  @override
  State<ThoughtRecordPage> createState() => _ThoughtRecordPageState();
}

class _ThoughtRecordPageState extends State<ThoughtRecordPage> {
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // ================= LOAD RECORDS =================

  Future<void> _loadRecords() async {
    try {
      final data = await DBHelper.getAllThoughtRecords();
      if (mounted) {
        setState(() {
          records = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading thought records: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= DETAIL DIALOG =================

  void _showDetails(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Thought Record #${record['id']}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy • h:mm a')
                  .format(DateTime.parse(record['created_at'])),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section("Trigger / Situation", record['trigger']),
              _section("Feeling", record['feeling']),
              _section("Negative Thought", record['negative_thought']),
              if (record['new_thought'] != null &&
                  record['new_thought'].toString().isNotEmpty)
                _section("Balanced Thought", record['new_thought']),
              if (record['outcome'] != null &&
                  record['outcome'].toString().isNotEmpty)
                _section("Outcome", record['outcome']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String? text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text ?? "",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (records.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Thought Records")),
        body: const Center(
          child: Text("No thought records found yet."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thought Records"),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          final createdAt =
          DateTime.parse(record['created_at']);

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.psychology_outlined,
                color: Colors.deepPurple,
              ),
              title: Text(
                "Thought Record #${record['id']}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                DateFormat('MMM d, yyyy • h:mm a').format(createdAt),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetails(record),
            ),
          );
        },
      ),
    );
  }
}
