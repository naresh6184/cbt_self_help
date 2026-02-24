import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⭐ Save list locally
Future<void> cachePhq9HistoryLocally(
    List<Map<String, dynamic>> history) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = jsonEncode(history);
  await prefs.setString("phq9HistoryCache", jsonString);
}

/// ⭐ Load instantly from local cache
Future<List<Map<String, dynamic>>> loadPhq9HistoryFromLocal() async {
  final prefs = await SharedPreferences.getInstance();

  final jsonString = prefs.getString("phq9HistoryCache");

  if (jsonString == null) return [];

  final decoded = jsonDecode(jsonString) as List;

  return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
}

/// ⭐ Fetch from Firebase and update local cache
Future<List<Map<String, dynamic>>> fetchAndCachePhq9History() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  final snapshot = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .collection("phq9_history")
      .orderBy("date", descending: true)
      .get();

  final history = snapshot.docs.map((doc) {
    final data = doc.data();
    final Timestamp ts = data["date"];

    return {
      "score": data["score"],
      "severity": data["severity"],
      "date": ts.toDate().toIso8601String(),
    };
  }).toList();

  await cachePhq9HistoryLocally(history);

  return history;
}
