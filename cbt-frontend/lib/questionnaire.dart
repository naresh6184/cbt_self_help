import 'dart:convert';
import 'package:cbt/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'phq9_history_helper.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({super.key});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  String _question = "";
  int _questionNumber = 0;
  Map<String, dynamic> _choices = {};
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();
  String? _result;
  String _sessionId = "";
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _checkAndStart();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ================= PHQ9 LOCK =================
  Future<bool> _canStartPhq9() async {
    if (_currentUser == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(_currentUser!.uid)
        .get();

    if (!doc.exists) return true;

    final data = doc.data();
    if (data == null || data["lastPhq9Date"] == null) return true;

    final Timestamp ts = data["lastPhq9Date"];
    final lastDate = ts.toDate();
    final now = DateTime.now();

    if (lastDate.year == now.year &&
        lastDate.month == now.month &&
        lastDate.day == now.day) {
      return false;
    }

    final difference = now.difference(lastDate).inDays;
    if (difference < 7) return false;

    return true;
  }

  Future<void> _checkAndStart() async {
    final allowed = await _canStartPhq9();

    if (!allowed) {
      setState(() {
        _result =
        "You have already completed the PHQ-9 recently.\n\nPlease try again next week.";
      });
      return;
    }

    _startQuestionnaire();
  }

  // ================= START =================
  Future<void> _startQuestionnaire() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response =
      await http.post(Uri.parse("${dotenv.env['BACKEND_URL']??"http://10.100.32.33:8000"}/start"));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _sessionId = data["session_id"];
          _question = data["question"];
          _questionNumber = data["question_number"] ?? 1;
          _choices = Map<String, dynamic>.from(data["choices"]);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ================= SUBMIT =================
  Future<void> _submitAnswer(String answer) async {
    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${dotenv.env['BACKEND_URL']??"http://10.100.32.33:8000"}/message"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(
            {"session_id": _sessionId, "user_input": answer}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data["done"] == true) {
          final int score = data["total_score"];
          final String severity = data["severity"] ?? "N/A";

          await _saveResultToFirebase(score, severity);
          await fetchAndCachePhq9History();
          await _saveResultLocally(score, severity);

          setState(() {
            _result =
            "Final Score: $score\n\nInterpretation: $severity";
            _question = "";
            _choices = {};
          });
        } else {
          setState(() {
            _question = data["question"];
            _questionNumber =
                data["question_number"] ?? _questionNumber + 1;
            _choices =
            Map<String, dynamic>.from(data["choices"]);
          });
        }
      }
    } catch (_) {}

    if (!mounted) return;
    _controller.clear();
    setState(() => _isLoading = false);
  }

  // ================= LOCAL SAVE =================
  Future<void> _saveResultLocally(int score, String severity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastPhq9Score', score);
    await prefs.setString('lastPhq9Severity', severity);
    await prefs.setString(
        'lastPhq9Date', DateTime.now().toIso8601String());
  }

  // ================= FIREBASE SAVE =================
  Future<void> _saveResultToFirebase(
      int score, String severity) async {
    if (_currentUser == null) return;

    final userRef = FirebaseFirestore.instance
        .collection("users")
        .doc(_currentUser!.uid);

    await userRef.collection("phq9_history").add({
      "score": score,
      "severity": severity,
      "date": FieldValue.serverTimestamp(),
    });

    await userRef.set({
      "lastPhq9Score": score,
      "lastPhq9Severity": severity,
      "lastPhq9Date": FieldValue.serverTimestamp(),
      "weeklyActivity": 0,
    }, SetOptions(merge: true));
  }

  // ================= START WEEKLY ACTIVITY =================
  Future<void> _startWeeklyActivity() async {
    if (_currentUser == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(_currentUser!.uid)
        .set({"weeklyActivity": 0}, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
          (Route<dynamic> route) => false,
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("PHQ-9 Questionnaire"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding:
        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
        child: _result != null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _result!,
              style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton(
              onPressed: _startWeeklyActivity,
              child:
              const Text("Start Weekly Activity"),
            ),
          ],
        )
            : SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: screenHeight * 0.02),
              if (_question.isNotEmpty)
                Text(
                  _question,
                  style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600),
                ),
              SizedBox(height: screenHeight * 0.02),

              /// ⭐ CLEAN RECTANGULAR OPTIONS
              ListView(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                children:
                _choices.entries.map((entry) {
                  final key = entry.key;
                  final value = entry.value;
                  final text = value is Map &&
                      value.containsKey("text")
                      ? value["text"]
                      : value.toString();

                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 6),
                    child: InkWell(
                      onTap: () =>
                          _submitAnswer(key.toString()),
                      borderRadius:
                      BorderRadius.circular(8),
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius:
                          BorderRadius.circular(8),
                          border: Border.all(
                            color:
                            Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "$key. $text",
                          style: TextStyle(
                            fontSize:
                            screenWidth * 0.04,
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Divider(height: 30),

              /// ⭐ TEXT INPUT (UNCHANGED)
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Or type how you feel...",
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (val) {
                  if (val.isNotEmpty)
                    _submitAnswer(val);
                },
              ),
              SizedBox(height: screenHeight * 0.015),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      _submitAnswer(_controller.text);
                    }
                  },
                  child: const Text("Submit Answer"),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
    );
  }
}
