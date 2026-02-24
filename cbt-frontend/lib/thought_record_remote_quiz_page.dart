import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'db_helper.dart';

class ThoughtRecordRemoteQuizPage extends StatefulWidget {
  const ThoughtRecordRemoteQuizPage({super.key});

  @override
  State<ThoughtRecordRemoteQuizPage> createState() =>
      _ThoughtRecordRemoteQuizPageState();
}

class _ThoughtRecordRemoteQuizPageState
    extends State<ThoughtRecordRemoteQuizPage> {
  bool isLoading = true;
  bool isSubmitting = false;

  int currentIndex = 0;
  List<dynamic> questions = [];
  final Map<String, String> answers = {};

  final TextEditingController controller = TextEditingController();

  final String baseUrl = dotenv.env['BACKEND_URL']!;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // ================= FETCH QUESTIONS =================

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/thought-record/questions"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          questions = data["questions"] as List<dynamic>;
          isLoading = false;
        });
        _loadAnswer();
      } else {
        _showError("Failed to load questions");
      }
    } catch (_) {
      _showError("Could not connect to server");
    }
  }

  // ================= NAVIGATION =================

  void _loadAnswer() {
    if (questions.isEmpty) return;
    final key = questions[currentIndex]["key"] as String;
    controller.text = answers[key] ?? "";
  }

  void _next() {
    FocusScope.of(context).unfocus();

    final q = questions[currentIndex];
    final isRequired = q["required"] == true;

    if (isRequired && controller.text.trim().isEmpty) {
      _showSnack("Please enter a response");
      return;
    }

    answers[q["key"] as String] = controller.text.trim();

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        _loadAnswer();
      });
    } else {
      _submit();
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (currentIndex == 0) return;

    setState(() {
      currentIndex--;
      _loadAnswer();
    });
  }

  // ================= SUBMIT =================

  Future<void> _submit() async {
    setState(() => isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/thought-record/submit"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"answers": answers}),
      );

      if (response.statusCode == 200) {
        await DBHelper.insertThoughtRecord(
          trigger: answers["trigger"] ?? "",
          feeling: answers["feeling"] ?? "",
          negativeThought: answers["negative_thought"] ?? "",
          newThought: answers["new_thought"],
          outcome: answers["outcome"],
        );

        controller.clear();
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError("Submission failed");
      }
    } catch (_) {
      _showError("Could not submit data");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Thought Record")),
        body: const Center(child: Text("No questions available")),
      );
    }

    final q = questions[currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text("Thought Record")),
      resizeToAvoidBottomInset: true, // 👈 keyboard aware

      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // ✅ SCROLLABLE CONTENT
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: (currentIndex + 1) / questions.length,
                      ),
                      const SizedBox(height: 20),

                      Text(
                        q["text"],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if ((q["helper"] as String?)?.isNotEmpty ?? false)
                        Text(
                          q["helper"],
                          style: TextStyle(color: Colors.grey[600]),
                        ),

                      const SizedBox(height: 16),

                      // ✅ MULTILINE TEXT FIELD (2–3 lines)
                      TextField(
                        controller: controller,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        minLines: 3,
                        maxLines: 5,
                        onSubmitted: (_) => _next(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Type your answer...",
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ BUTTON BAR (NEAR BOTTOM, NEVER DISAPPEARS)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
                ),
                child: Row(
                  children: [
                    if (currentIndex > 0)
                      TextButton(
                        onPressed: _back,
                        child: const Text("Back"),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : _next,
                      child: Text(
                        currentIndex == questions.length - 1
                            ? "Submit"
                            : "Next",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
    setState(() => isLoading = false);
  }
}
