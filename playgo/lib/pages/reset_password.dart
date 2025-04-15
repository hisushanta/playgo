import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'home.dart';


class PasswordResetGuideWidget extends StatefulWidget {
  @override
  _PasswordResetGuideWidget createState() => _PasswordResetGuideWidget();
}
class _PasswordResetGuideWidget extends State<PasswordResetGuideWidget> {

  StreamSubscription<QuerySnapshot>? _confirmationListener;
  StreamSubscription<QuerySnapshot>? _countdownListener;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose(){
    _confirmationListener?.cancel();
    _countdownListener?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/homeIcon.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 4),
            const Text(
              "Play Go",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black,),
        leading:IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 3,
      ),
        
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              'Resetting Your Password in Lottlo App',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildStep(
              '1. Open the PlayGo App',
              'Launch the PlayGo app on your smartphone.',
              Icons.phone_android_rounded,
            ),
            _buildStep(
              '2. Tap on "Forgot Password?"',
              'On the login screen, tap on the "Forgot Password?" link.',
              Icons.lock_open_rounded,
            ),
            _buildStep(
              '3. Enter Your Registered Email',
              'Enter your registered email address and tap "Submit".',
              Icons.email_rounded,
            ),
            _buildStep(
              '4. Check Your Email',
              'Look for an email from PlayGo with a password reset link.',
              Icons.mail_outline_rounded,
            ),
            _buildStep(
              '5. Click the Reset Link',
              'Open the email and click the reset link to be redirected to a new page.',
              Icons.link_rounded,
            ),
            _buildStep(
              '6. Enter New Password',
              'Set your new password, confirm it, and tap "Submit".',
              Icons.vpn_key_rounded,
            ),
            _buildStep(
              '7. Login with New Password',
              'Return to the PlayGo app and log in using your new password.',
              Icons.login_rounded,
            ),
            const SizedBox(height: 30),
            const Text(
              '💡 Tip: Choose a strong, unique password to enhance your account security.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Colors.teal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.teal.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const Divider(color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
