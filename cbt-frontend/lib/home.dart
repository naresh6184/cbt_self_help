import 'dart:async';
import 'dart:ui';
import 'package:cbt/profile.dart';
import 'package:cbt/shareReports.dart';
import 'package:cbt/thought_record_remote_quiz_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '/questionnaire.dart';
import '/thoughtRecords.dart';
import '/weeklyActivity.dart';
import 'db_helper.dart';
import 'login.dart';
import 'chat_interface.dart';
import 'instructSet/cbt_texts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _phqKey = GlobalKey();
  final GlobalKey _chatKey = GlobalKey();
  final GlobalKey _thoughtKey = GlobalKey();

// ⭐ INFO BUTTON KEYS
  final GlobalKey _weeklyInfoKey = GlobalKey();
  final GlobalKey _phqInfoKey = GlobalKey();
  final GlobalKey _thoughtInfoKey = GlobalKey();

  int weeklyActivity = -2;
  StreamSubscription? _activityStreamSubscription;

  bool _homeShowcaseStarted = false;
  bool _phq9ShowcaseStarted = false;

  @override
  void initState() {
    super.initState();
    _checkWeeklyDeadline();
    _listenToActivityStream();
  }

  @override
  void dispose() {
    _activityStreamSubscription?.cancel();
    super.dispose();
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

// =======================================================================
// ⭐ PHQ9 SHOWCASE
// =======================================================================
  Future<void> _initPHQ9Showcase(BuildContext showcaseContext) async {
    if (_phq9ShowcaseStarted) return;
    _phq9ShowcaseStarted = true;

    if (weeklyActivity == -2) {
      _phq9ShowcaseStarted = false;
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _initPHQ9Showcase(showcaseContext);
      return;
    }

    if (weeklyActivity != -1 && weeklyActivity != 1) {
      _phq9ShowcaseStarted = false;
      return;
    }

    bool? localValue = await DBHelper.getPHQ9ShowcaseCompleted();
    bool isDone;

    if (localValue != null) {
      isDone = localValue;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _phq9ShowcaseStarted = false;
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      isDone = doc.data()?['phq9ShowcaseCompleted'] ?? false;
      await DBHelper.setPHQ9ShowcaseCompleted(isDone);
    }

    if (!isDone && mounted) {
      await DBHelper.setPHQ9ShowcaseCompleted(true);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'phq9ShowcaseCompleted': true});
      }

      await Future.delayed(const Duration(milliseconds: 700));

      if (mounted) {
        ShowCaseWidget.of(showcaseContext).startShowCase([
          _menuKey,
          _phqKey,
          _phqInfoKey, // ⭐ ADDED
        ]);
      }
    }
  }

// =======================================================================
// ⭐ HOME SHOWCASE
// =======================================================================
  Future<void> _initHomeShowcase(BuildContext showcaseContext) async {
    if (_homeShowcaseStarted) return;
    _homeShowcaseStarted = true;

    if (weeklyActivity == -2) {
      _homeShowcaseStarted = false;
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _initHomeShowcase(showcaseContext);
      return;
    }

    if (weeklyActivity != 0 && weeklyActivity != 1) {
      _homeShowcaseStarted = false;
      return;
    }

    bool? localValue = await DBHelper.getHomeShowcaseCompleted();
    bool isDone;

    if (localValue != null) {
      isDone = localValue;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _homeShowcaseStarted = false;
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      isDone = doc.data()?['homeShowcaseCompleted'] ?? false;
      await DBHelper.setHomeShowcaseCompleted(isDone);
    }

    if (!isDone && mounted) {
      await DBHelper.setHomeShowcaseCompleted(true);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'homeShowcaseCompleted': true});
      }

      List<GlobalKey> sequence = [];

      if (weeklyActivity == 0) {
        sequence.add(_chatKey);
        sequence.add(_weeklyInfoKey); // ⭐ ADDED
      }

      sequence.add(_thoughtKey);
      sequence.add(_thoughtInfoKey); // ⭐ ADDED

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        ShowCaseWidget.of(showcaseContext).startShowCase(sequence);
      }
    }
  }

// =======================================================================
// Logic
// =======================================================================

  Future<void> _checkWeeklyDeadline() async {
    final weekData = await DBHelper.getCurrentWeekData();
    if (weekData == null || weekData['isCompleted'] == 1) return;

    final DateTime deadline = DateTime.parse(weekData['endDate']);
    if (DateTime.now().isAfter(deadline)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'weeklyActivity': 1});
        await DBHelper.markWeekAsCompleted();
      }
    }
  }

  void _listenToActivityStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _activityStreamSubscription = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey("weeklyActivity")) {
        final value = snapshot.data()!["weeklyActivity"];
        if (mounted) {
          setState(() {
            weeklyActivity =
                value is int ? value : (value as num?)?.toInt() ?? -1;
          });
        }
      }
    });
  }

  String _getCurrentTimeSlot() {
    final now = DateTime.now();
    final startHour = now.hour;
    final endHour = (startHour + 1) % 24;

    String formatHour(int hour) {
      final period = hour >= 12 ? "PM" : "AM";
      final h = hour % 12 == 0 ? 12 : hour % 12;
      return "$h $period";
    }

    return "${formatHour(startHour)} - ${formatHour(endHour)}";
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProfilePage()));
        break;
      case 'view_weekly_activity':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WeeklyActivityPage()));
        break;
      case 'view_thought_records':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ThoughtRecordPage()));
        break;
      case 'share reports':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ShareReportPage()));
        break;
      case 'logout':
        _logout(context);
        break;
    }
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Got it")),
        ],
      ),
    );
  }

// ======================================================
// BUILD + UI (UNCHANGED FROM YOUR VERSION)
// ======================================================

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ShowCaseWidget(
      blurValue: 3,
      disableBarrierInteraction: true,
      builder: (showcaseContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ModalRoute.of(context)?.isCurrent != true) return;

          _initPHQ9Showcase(showcaseContext);
          _initHomeShowcase(showcaseContext);
        });

        return Scaffold(
          backgroundColor: const Color(0xfff2f2f7),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            title: const Text("Your Daily Space"),
            centerTitle: true,
            actions: [
              Showcase(
                key: _menuKey,
                title: 'Your Space & Reports',
                description:
                    'Open your profile, past activities, and share reports.',
                child: PopupMenuButton<String>(
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'profile', child: Text('Profile')),
                    PopupMenuItem(
                        value: 'view_weekly_activity',
                        child: Text('View Weekly Activity')),
                    PopupMenuItem(
                        value: 'view_thought_records',
                        child: Text('View Thought Records')),
                    PopupMenuItem(
                        value: 'share reports', child: Text('Share Reports')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'logout', child: Text('Logout')),
                  ],
                ),
              ),
            ],
          ),
          body: weeklyActivity == -2
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: _hideKeyboard,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: screenHeight * 0.75),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24),
                                _buildHeader(),
                                const SizedBox(height: 28),
                                if (weeklyActivity == -1)
                                  Showcase(
                                    key: _phqKey,
                                    title: 'Weekly Check-In (PHQ-9)',
                                    description:
                                        'This short questionnaire calculates your depression score and tracks progress.',
                                    child: _buildIOSCard(
                                        child: _buildPhq9Content()),
                                  ),
                                if (weeklyActivity == 0) ...[
                                  Showcase(
                                    key: _chatKey,
                                    title: 'Weekly Activity Journal',
                                    description:
                                        'Log what you are doing throughout the day.',
                                    child: _buildIOSCard(
                                      child: ChatInterface(
                                        activityType: "weekly-activity",
                                        headerText: "",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildThoughtButton(),
                                ],
                                if (weeklyActivity == 1) ...[
                                  Showcase(
                                    key: _phqKey,
                                    title: 'Weekly Follow-up',
                                    description:
                                        'Retake PHQ-9 to see your progress.',
                                    child: _buildIOSCard(
                                      child: _buildPhq9Content(
                                          isWeeklyCheckin: true),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  _buildThoughtButton(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

// =======================================================================
// UI WIDGETS
// =======================================================================

  Widget _buildIOSCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    if (weeklyActivity == 0) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🧠 Weekly Activity",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              Showcase(
                key: _weeklyInfoKey,
                title: 'Weekly Activity Info',
                description: 'Tap here to learn what weekly activity means.',
                child: IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  onPressed: () => _showInfoDialog(
                    CBTTexts.weeklyTitle,
                    CBTTexts.weeklyDescription,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_getCurrentTimeSlot(),
              style: const TextStyle(fontSize: 16, color: Colors.deepPurple)),
        ],
      );
    }

    return Text(
      weeklyActivity == 1 ? "🎉 Activity Completed" : "Welcome 👋",
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildPhq9Content({bool isWeeklyCheckin = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, size: 36, color: Colors.deepPurple),
            Showcase(
              key: _phqInfoKey,
              title: 'PHQ-9 Information',
              description: 'Tap to understand how the PHQ-9 works.',
              child: IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                onPressed: () => _showInfoDialog(
                  CBTTexts.phq9Title,
                  CBTTexts.phq9Description,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          isWeeklyCheckin
              ? "Time for your weekly check-in."
              : "Start with a PHQ-9 assessment.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const QuestionnairePage())),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("Start PHQ-9 Test"),
        )
      ],
    );
  }

  Widget _buildThoughtButton() {
    return Showcase(
      key: _thoughtKey,
      title: 'Thought Record',
      description: 'Whenever you feel overwhelmed, record your thoughts here.',
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ThoughtRecordRemoteQuizPage())),
              icon: const Icon(Icons.edit_note),
              label: const Text("Record a New Thought"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Showcase(
            key: _thoughtInfoKey,
            title: 'Thought Record Help',
            description: 'Tap here to understand how thought records help you.',
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showInfoDialog(
                  CBTTexts.thoughtTitle, CBTTexts.thoughtDescription),
            ),
          ),
        ],
      ),
    );
  }
}
