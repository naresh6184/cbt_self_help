import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home.dart';
import '../db_helper.dart';

class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key});

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  // ================= WALKTHROUGH CONTENT =================

  final List<Map<String, dynamic>> pages = [
    {
      "title": "Welcome to MindSpace 🧠",
      "icon": Icons.psychology_alt_rounded,
      "desc":
      "MindSpace is a gentle space to understand your thoughts, emotions, and daily habits.\n\n"
          "It does not judge you or label you — it simply helps you observe patterns and reflect on your mental wellbeing step by step.",
    },
    {
      "title": "PHQ-9 Weekly Check-In",
      "icon": Icons.monitor_heart_outlined,
      "desc":
      "Every week you answer a short PHQ-9 questionnaire.\n\n"
          "Your answers calculate a depression score that helps you track changes in mood over time.\n\n"
          "You can always view your past scores and progress history from your Profile page.",
    },
    {
      "title": "Weekly Activity",
      "icon": Icons.timeline_rounded,
      "desc":
      "Think of Weekly Activity as a simple daily diary for one full week.\n\n"
          "You note what you did during the day — studying, resting, socialising, or relaxing.\n\n"
          "After completing a week, you retake the PHQ-9 check-in to see how your habits may be affecting your progress.",
    },
    {
      "title": "Thought Record",
      "icon": Icons.auto_awesome_outlined,
      "desc":
      "Whenever a difficult or negative thought appears, you can record it here.\n\n"
          "MindSpace guides you with simple questions to help you reflect and reframe thoughts in a healthier way.\n\n"
          "If you choose to share your reports with a psychiatrist or counsellor, these records can help them understand your experiences better.",
    },
    {
      "title": "Your Personal Progress Space",
      "icon": Icons.bubble_chart_outlined,
      "desc":
      "PHQ-9 shows how you feel.\n"
          "Weekly Activity shows what you do.\n"
          "Thought Records show how you think.\n\n"
          "Together they create a clear picture of your journey — always private, always in your control.",
    },
  ];

  // ================= COMPLETE WALKTHROUGH =================

  Future<void> _finishWalkthrough() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"walkthroughCompleted": true});
    }

    await DBHelper.setWalkthroughCompleted(true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // ================= DOTS =================

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pages.length, (index) {
        final active = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 26 : 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  // ================= PAGE CARD =================

  Widget _buildPage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          /// ICON BADGE
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.18),
            ),
            child: Icon(
              data["icon"],
              size: 40,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 30),

          /// TITLE
          Text(
            data["title"],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 30),

          /// GLASS CARD
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Text(
                  data["desc"],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.6,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final bool lastPage = _currentIndex == pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff5b4dff),
              Color(0xff7b6dff),
              Color(0xffb1a8ff),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              /// ===== SKIP (hidden on last page) =====
              if (!lastPage)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finishWalkthrough,
                    child: const Text(
                      "Skip",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              else
                const SizedBox(height: 48),

              /// ===== PAGE VIEW =====
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) {
                    setState(() => _currentIndex = i);
                  },
                  itemBuilder: (_, index) =>
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _buildPage(pages[index]),
                      ),
                ),
              ),

              const SizedBox(height: 10),

              _buildDots(),

              const SizedBox(height: 22),

              /// ===== NEXT BUTTON =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact(); // ⭐ premium feel

                    if (lastPage) {
                      _finishWalkthrough();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    lastPage ? "Start My Journey" : "Next",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}