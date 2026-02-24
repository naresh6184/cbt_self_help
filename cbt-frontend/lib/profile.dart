import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'phq9_history_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _noMobilePlaceholder = 'No Mobile No. Provided';

  bool _isLoading = true;
  String _name = 'Loading...';
  String _email = 'Loading...';
  String _mobile = 'Loading...';

  List<Map<String, dynamic>> _phq9History = [];

  bool _isEditingMobile = false;
  bool _isSaving = false;
  final TextEditingController _mobileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic rawDate) {
    try {
      DateTime dt;

      if (rawDate is Timestamp) {
        dt = rawDate.toDate();
      } else if (rawDate is String) {
        dt = DateTime.parse(rawDate);
      } else {
        return rawDate.toString();
      }

      return DateFormat("d MMM. yyyy , hh:mm a").format(dt);
    } catch (_) {
      return rawDate.toString();
    }
  }

  Color _getSeverityColor(String? severity) {
    if (severity == null) return Colors.deepPurple;

    final s = severity.toLowerCase();

    if (s.contains("severe")) return Colors.redAccent;
    if (s.contains("moderate")) return Colors.orange;
    if (s.contains("mild") || s.contains("minimal")) return Colors.green;

    return Colors.deepPurple;
  }

  Future<void> _fetchUserData() async {
    if (mounted) setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;

    _phq9History = await loadPhq9HistoryFromLocal();

    if (mounted) setState(() {});

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final String? phoneFromDb = data['phone'];

          _name = data['name'] ?? 'No Name Provided';
          _email = data['email'] ?? 'No Email Provided';
          _mobile = (phoneFromDb == null || phoneFromDb.isEmpty)
              ? _noMobilePlaceholder
              : phoneFromDb;

          _mobileController.text = _mobile;
        }

        final freshHistory = await fetchAndCachePhq9History();

        if (mounted) {
          setState(() {
            _phq9History = freshHistory;
          });
        }
      } catch (e) {
        debugPrint("Error fetching profile data: $e");
        _name = 'Error Fetching Data';
      }
    } else {
      _name = 'Not Logged In';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMobileNumber() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      final newMobile = _mobileController.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'phone': newMobile});

      setState(() {
        _mobile =
        newMobile.isEmpty ? _noMobilePlaceholder : newMobile;
        _isEditingMobile = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mobile number updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update mobile number: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchUserData,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 16),

            Text(
              _name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.email_outlined,
                    color: Theme.of(context).primaryColor),
                title: const Text('Email'),
                subtitle:
                Text(_email, style: const TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.phone_outlined,
                    color: Theme.of(context).primaryColor),
                title: const Text('Mobile No.'),
                subtitle: _isEditingMobile
                    ? TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter your mobile number',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 16),
                )
                    : Text(_mobile,
                    style: const TextStyle(fontSize: 16)),
                trailing: _isSaving
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child:
                  CircularProgressIndicator(strokeWidth: 2),
                )
                    : IconButton(
                  icon: Icon(_isEditingMobile
                      ? Icons.download_done
                      : Icons.edit_outlined),
                  onPressed: () {
                    if (_isEditingMobile) {
                      _updateMobileNumber();
                    } else {
                      if (_mobile == _noMobilePlaceholder) {
                        _mobileController.clear();
                      }
                      setState(() {
                        _isEditingMobile = true;
                      });
                    }
                  },
                ),
              ),
            ),

            /// ⭐ PHQ9 HISTORY WITH NUMBER BADGE
            if (_phq9History.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "PHQ-9 History",
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ..._phq9History.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final number = _phq9History.length - index;
                final color = _getSeverityColor(item["severity"]);

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withOpacity(0.12),
                      child: Text(
                        "$number",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    title: Text(
                      "Score: ${item["score"]} (${item["severity"]})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      "Taken on: ${_formatDate(item["date"])}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ]
          ],
        ),
      ),
    );
  }
}
