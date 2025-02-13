import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:playgo/main.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentOptionsPage extends StatefulWidget {
  final String amount;
  PaymentOptionsPage({Key? key, required this.amount}):super(key:key);
  @override
  _PaymentOptionsPage createState() => _PaymentOptionsPage();
}
class _PaymentOptionsPage extends State<PaymentOptionsPage>{

  Future<void> _launchUpiPayment(BuildContext context) async {
    debugPrint("Amoung: ${widget.amount}");
    // Your UPI details
    final upiId = "7596912157@ybl";  // Replace with your UPI ID
    final name = "Your Name";        // Replace with your name
    final note = "Payment for services";
    final amount = widget.amount;

    // Google Pay specific URI
    final googlePayUri = Uri.parse(
      'tez://upi/pay?pa=$upiId&pn=$name&tn=$note&am=$amount&cu=INR'
    );

    // Generic UPI URI (backup)
    final upiUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=$name&tn=$note&am=$amount&cu=INR'
    );

    try {
      // First try Google Pay
      final gpayInstalled = await canLaunchUrl(googlePayUri);
      if (gpayInstalled) {
        print("Launching Google Pay...");
        await launchUrl(
          googlePayUri,
          mode: LaunchMode.externalApplication,
        );
        
        // Wait for potential completion
        await Future.delayed(Duration(seconds: 5));
        if (!mounted) return;
        
        info!.addFund(amount);
        Navigator.pop(context);
        return;
      }

      // If Google Pay not available, try generic UPI
      final upiAvailable = await canLaunchUrl(upiUri);
      if (upiAvailable) {
        print("Launching UPI app...");
        await launchUrl(
          upiUri,
          mode: LaunchMode.externalApplication,
        );
        
        await Future.delayed(Duration(seconds: 5));
        if (!mounted) return;
        
        info!.addFund(amount);
        Navigator.pop(context);
        return;
      }

      // If we get here, no UPI apps were found
      if (!mounted) return;
      _showNoUpiAppsDialog(context);
      
    } catch (e) {
      print("Error launching UPI: $e");
      if (!mounted) return;
      _showErrorDialog(context, e.toString());
    }
  }

  void _showNoUpiAppsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('No UPI Apps Found'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please make sure:'),
              SizedBox(height: 8),
              Text('1. Google Pay is installed'),
              Text('2. Google Pay is up to date'),
              Text('3. Google Pay is set up with your UPI ID'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Payment Error'),
          content: Text('There was an error launching the payment: $error'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Payment Options'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),
              _buildUPISection(context),
              SizedBox(height: 20),
              _buildCreditDebitCardSection(),
              SizedBox(height: 20),
              _buildNetBankingSection(),
            ],
          ),
        ),
      ),
    );
  }

  

  Widget _buildUPISection(BuildContext context) {
    return GestureDetector(
      onTap: ()=>_launchUpiPayment(context),
      
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('assets/gpay-logo.png'),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("UPI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text("Google Pay, PhonePe & more", style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditDebitCardSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Credit/Debit Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          // crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

          ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepPurple,
            side: BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text('+ Add new card'),
        ),
          ],
        ),
        
        SizedBox(height: 12),
        Row(
          children: [
            Image.asset('assets/mc-card.png', height: 16,fit: BoxFit.fill,),
            SizedBox(width: 8),
            Image.asset('assets/visa-card.png', height: 16,fit:BoxFit.fill),
            SizedBox(width: 8),
            Image.asset('assets/rupay-card.png', height: 16,fit: BoxFit.fill),
          ],
        ),
      ],
    ),
    );
  }

  Widget _buildNetBankingSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Net Banking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Popular Banks', style: TextStyle(fontSize: 14, color: Colors.grey)),
        SizedBox(height: 12),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage: AssetImage('assets/hdfc-logo.jpg'),
          ),
          title: Text('Kotak Bank', style: TextStyle(fontSize: 16)),
          trailing: Icon(Icons.arrow_forward, color: Colors.grey),
          onTap: () {},
        ),
      ],
    ),
    );
  }
}
