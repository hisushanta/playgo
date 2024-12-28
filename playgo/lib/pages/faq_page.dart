import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({Key? key}) : super(key: key);

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
              "Om Namo",
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
                  "The Lottlo app is your go-to fashion destination, offering a curated collection of trendy clothing and accessories. Designed to make shopping a delightful experience, Lottlo brings you the latest styles from top brands, all in one place. Whether you're looking for everyday essentials or statement pieces, our app provides seamless browsing, easy ordering, and personalized recommendations tailored to your unique style. With Lottlo, you're just a few taps away from revamping your wardrobe!",
            ),
            
            _buildFAQItem(
              question: 'How can I contact customer support?',
              answer:
                  'You can reach customer support by calling +917596912157 or emailing us at lottloapp@gmail.com. We’re here to help!',
            ),
            _buildFAQItem(
              question: 'How do I update my profile?',
              answer:
                  "To update your profile information, such as your name, address, and phone number, go to the User Profile section in the app. Simply click on the Edit Profile text, and you'll be able to make changes to your name, profile picture, address, and phone number.",
            ),
            _buildFAQItem(
              question: 'What should I do if I forget my password?',
              answer:
                  'If you forget your password, you can reset it by clicking on "Forgot Password" on the login screen. Follow the instructions to reset your password.',
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                'Still have questions? Contact us at lottloapp@gmail.com.',
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
            child: Text(
              answer,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
