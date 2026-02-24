import 'dart:convert';
import 'dart:io';

import 'package:cbt/db_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

class ShareReportPage extends StatefulWidget {
  const ShareReportPage({super.key});

  @override
  State<ShareReportPage> createState() => _ShareReportPageState();
}

class _ShareReportPageState extends State<ShareReportPage> {
  bool _includeWeeklyActivity = true;
  bool _includeThoughtRecords = true;

  final String baseUrl = dotenv.env['BACKEND_URL']??"http://10.100.32.33:8000";

  // ================= FILE NAME =================

  String _generateReportFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');

    final formatted =
        "${now.year}-${two(now.month)}-${two(now.day)}"
        "-${two(now.hour)}-${two(now.minute)}";

    return "CBT-Report-$formatted.xlsx";
  }

  // ================= FETCH + PREPARE DATA =================

  Future<List<int>> _fetchExcelFromBackend() async {
    final user = FirebaseAuth.instance.currentUser;

    String patientName = "N/A";
    String patientEmail = user?.email ?? "N/A";

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      patientName = userDoc.data()?['name'] ?? "N/A";
    }

    // ---------- WEEKLY ACTIVITY ----------
    final List<Map<String, dynamic>> weeklyActivities =
    _includeWeeklyActivity
        ? (await DBHelper.getAllChats())
        .cast<Map<String, dynamic>>()
        .toList()
        : <Map<String, dynamic>>[];

    // sort by date (past → present)
    weeklyActivities.sort((a, b) {
      final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
      return da.compareTo(db);
    });

    // ---------- THOUGHT RECORDS ----------
    final List<Map<String, dynamic>> thoughtRecords =
    _includeThoughtRecords
        ? (await DBHelper.getAllThoughtRecords())
        .cast<Map<String, dynamic>>()
        .map((r) {
      final ts = r['created_at'];
      return {
        ...r,
        // ensure backend always receives string
        'created_at':
        ts is DateTime ? ts.toIso8601String() : ts,
      };
    }).toList()
        : <Map<String, dynamic>>[];

    // sort by created_at (past → present)
    thoughtRecords.sort((a, b) {
      final ta =
          DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final tb =
          DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return ta.compareTo(tb);
    });

    final payload = {
      "patient": {
        "name": patientName,
        "email": patientEmail,
      },
      "include_weekly_activity": _includeWeeklyActivity,
      "include_thought_records": _includeThoughtRecords,
      "weekly_activities": weeklyActivities,
      "thought_records": thoughtRecords,
    };

    final response = await http.post(
      Uri.parse("$baseUrl/reports/excel"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to generate Excel report");
    }

    return response.bodyBytes;
  }

  // ================= DOWNLOAD =================

  Future<void> _downloadReport() async {
    if (!_includeWeeklyActivity && !_includeThoughtRecords) {
      _showSnack("Please select at least one item to export.");
      return;
    }

    _showLoading();

    try {
      final bytes = await _fetchExcelFromBackend();
      final fileName = _generateReportFileName();
      final file = await _saveToDownloads(bytes, fileName);
      _showSnack("Report downloaded to ${file.path}");
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  // ================= SHARE =================

  Future<void> _shareReport() async {
    if (!_includeWeeklyActivity && !_includeThoughtRecords) {
      _showSnack("Please select at least one item to export.");
      return;
    }

    _showLoading();

    try {
      final bytes = await _fetchExcelFromBackend();
      final fileName = _generateReportFileName();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(path)],
        subject: "CBT Report",
      );
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  // ================= FILE SAVE HELPER =================

  Future<File> _saveToDownloads(List<int> bytes, String fileName) async {
    Directory? dir;

    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else if (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS) {
      dir = await getDownloadsDirectory();
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir == null) {
      throw Exception("Unable to access download directory");
    }

    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ================= UI HELPERS =================

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Share Report"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report Content",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            CheckboxListTile(
              title: const Text("Include Weekly Activity"),
              value: _includeWeeklyActivity,
              onChanged: (v) =>
                  setState(() => _includeWeeklyActivity = v ?? false),
            ),

            CheckboxListTile(
              title: const Text("Include Thought Records"),
              value: _includeThoughtRecords,
              onChanged: (v) =>
                  setState(() => _includeThoughtRecords = v ?? false),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Download Excel"),
                    onPressed: _downloadReport,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text("Share Excel"),
                    onPressed: _shareReport,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
