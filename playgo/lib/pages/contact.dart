import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:playgo/main.dart';

class ContactUsWidget extends StatelessWidget {
  const ContactUsWidget({Key? key}) : super(key: key);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Welcome Message
            const Text(
              'We\'re here to help!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Feel free to contact us through any of these methods:',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Contact Options
            _buildContactTile(
              icon: Icons.phone,
              title: 'Customer Support',
              subtitle: 'Call us at +917596912157',
              onTap: () => _launchPhone("tel:+917596912157"),
            ),
            const SizedBox(height: 10), // Space between items
            _buildContactTile(
              icon: Icons.email,
              title: 'Email Us',
              subtitle: 'lottloapp@gmail.com',
              onTap: () {
                _launchEmail('lottloapp@gmail.com');
              },
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              icon: Icons.share,
              title: 'Social Media',
              subtitle: 'Tap to visit our profiles!',
              onTap: () {
              _showSocialMediaOptions(context);
            },

            ),
            const SizedBox(height: 20),
            
            // Feedback and Footer Message
            Center(
              child: Column(
                children: [
                  const Divider(thickness: 1.0),
                  const SizedBox(height: 20),
                  Text(
                    'Your feedback is valuable to us!',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Together, we can keep improving!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    void Function()? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.teal.withOpacity(0.1),
              child: Icon(icon, color: Colors.teal, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSocialMediaOptions(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (context) {
        return Padding( 
          padding: const EdgeInsets.symmetric(vertical: 2.0,horizontal:4.0),
          child: Wrap(
          children: [
            ListTile(
              leading: Image.network(info!.imageUrls["assets/x-icon.png"]!,width: 24, height: 24, fit: BoxFit.contain,),
              title: const Text('Twitter'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('https://twitter.com/lottloapp');
              },
            ),
            ListTile(
              leading: Image.network(info!.imageUrls["assets/facebook-icon.png"]!,width: 24, height: 24, fit: BoxFit.contain,),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('https://facebook.com/lottloapp');
              },
            ),
            ListTile(
              leading: Image.network(info!.imageUrls["assets/instagram-icon.png"]!,width: 24, height: 24, fit: BoxFit.contain,),
              title: const Text('Instagram'),
              onTap: () {
                Navigator.pop(context);
                _launchURL('https://instagram.com/lottloapp');
              },
            ),
          ],
        )
        );
      },
    );
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  void _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri.parse(phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }

  Future<void> _launchEmail(String email) async {
      final Uri emailUri = Uri.parse('mailto:$email');
      if (!await launchUrl(emailUri)) {
        throw 'Could not launch $email';
      }
    }

}
