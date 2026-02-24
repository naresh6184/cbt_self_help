import 'package:flutter/material.dart';

class InfoIconButton extends StatelessWidget {

  final String title;
  final String description;

  const InfoIconButton({
    super.key,
    required this.title,
    required this.description,
  });

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(

          insetPadding: const EdgeInsets.symmetric(horizontal: 20),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),

          content: SingleChildScrollView(
            child: Text(
              description,
              style: const TextStyle(fontSize: 15),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Got it"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      onPressed: () => _showInfo(context),
    );
  }
}
