import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'home.dart';

class FAQPage extends StatefulWidget {
  @override
  _FAQPage createState() => _FAQPage();
}

class _FAQPage extends State<FAQPage> {
  StreamSubscription<QuerySnapshot>? _confirmationListener;
  StreamSubscription<QuerySnapshot>? _countdownListener;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _listenForConfirmation(); // Listen for confirmation
    _listenForCountdown(); // Listen for countdown
  }

  @override
  void dispose(){
    _confirmationListener?.cancel();
    _countdownListener?.cancel();
    super.dispose();
  }

  void _listenForConfirmation() {
    _confirmationListener = FirebaseFirestore.instance
        .collection('matchRequests')
        .where('senderId', isEqualTo: userId) // Listen for requests where the current user is the sender
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final request = snapshot.docs.first;
        final requestId = request.id;

        // Check if the confirmation dialog should be shown
        final showConfirmation = request['showConfirmation'] ?? false;

        if (showConfirmation && !_isDialogShowing) {
          _isDialogShowing = true;

          // Show the confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Confirm Match', style: TextStyle(color: Colors.blue)),
                content: Text('The receiver has accepted your match request. Do you want to proceed?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Confirm', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              );
            },
          );

          // Reset the `showConfirmation` field to prevent re-triggering
          await FirebaseFirestore.instance
              .collection('matchRequests')
              .doc(requestId)
              .update({'showConfirmation': false});

          _isDialogShowing = false;

          if (confirmed == true) {
            // Update Firestore to indicate the sender has confirmed
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .update({'senderConfirmed': true});
          } else {
            // Cancel the match request if the sender declines
            await FirebaseFirestore.instance
                .collection('matchRequests')
                .doc(requestId)
                .delete();
          }
        }
      }
    });
  }

void _listenForCountdown() {
    _countdownListener = FirebaseFirestore.instance
        .collection('matchRequests')
        .where('senderId', isEqualTo: userId) // Listen for requests where the current user is the sender
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final request = snapshot.docs.first;
        final requestId = request.id;

        // Check if both users have confirmed
        final senderConfirmed = request['senderConfirmed'] ?? false;
        final receiverConfirmed = request['receiverConfirmed'] ?? false;
        final entryPrice = request['entryPrice']??'0.0';
        final duration = int.parse(request['duration']);

        final prizePool = double.parse(entryPrice) > 0.0?((double.parse(request['entryPrice'])*2)-(((double.parse(request['entryPrice']) * 2)/100)*2)).toString():"0.0";

        if (senderConfirmed && receiverConfirmed && !_isDialogShowing) {
          _isDialogShowing = true;

          // Show the countdown dialog
          showModalBottomSheet(
            context: context,
            isDismissible: false,
            enableDrag: false,
            isScrollControlled: true,
            builder: (context) => PopScope(
              canPop:false,
              child: CountdownBottomDialogForGame(
              time: duration,
              entryPrice: request['entryPrice'] ?? '0.0',
              prizePool:prizePool,
              partnerId: request['receiverId'],
              boardSize: request['boardSize'] ?? '9x9',
            ),
          ));

          // Reset the confirmation fields to prevent re-triggering
          await FirebaseFirestore.instance
              .collection('matchRequests')
              .doc(requestId)
              .update({
            'senderConfirmed': false,
            'receiverConfirmed': false,
          });

          _isDialogShowing = false;
        }
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 3,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'How can we help you today?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildFAQItem(
              question: 'What is the Lottlo app?',
              answer:
                  "PlayGo is a one-stop gaming platform where you can challenge friends or AI in exciting matches. Test your skills, compete, and even play with real money—where your earnings and losses depend entirely on your expertise!",
            ),
            
            _buildFAQItem(
              question: 'How can I contact customer support?',
              answer:
                  'You can reach customer support by calling +917596912157 or emailing us at playgoapp@gmail.com. We’re here to help!',
            ),
            _buildFAQItem(
              question: 'How do I update my profile?',
              answer:
                  "To update your profile information, such as your name, address, and phone number, go to the User Profile section in the app. Simply click on the Edit Profile text, and you'll be able to make changes to your name, profile picture, and phone number.",
            ),
            _buildFAQItem(
              question: 'What should I do if I forget my password?',
              answer:
                  'If you forget your password, you can reset it by clicking on "Forgot Password" on the login screen. Follow the instructions to reset your password.',
            ),
            const SizedBox(height: 30),
            Center(
              child: SelectableText(
                'Still have questions? Contact us at playgoapp@gmail.com.',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Card(
      elevation: 3,
      color:  Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: ExpansionTile(
        collapsedIconColor: const Color.fromARGB(255, 246, 181, 40),
        iconColor: const Color.fromARGB(255, 246, 181, 40),
        title: Text(
          question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SelectableText(
              answer,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
