// Flutter imports:
import 'package:flutter/material.dart';

Future<void> showAlarmPopup(
  BuildContext context,
  String title,
  String body, {
  bool isRepeated = false,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.only(top: 60, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(Icons.alarm, size: 48, color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isRepeated)
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'snooze'),
                      child: const Text("다시 울림"),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'confirm'),
                    child: const Text("확인"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
