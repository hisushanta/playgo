import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:playgo/main.dart';

class PaymentOptionsPage extends StatefulWidget {
  final String amount;
  PaymentOptionsPage({Key? key, required this.amount}):super(key:key);
  @override
  _PaymentOptionsPage createState() => _PaymentOptionsPage();
}
class _PaymentOptionsPage extends State<PaymentOptionsPage>{
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
      child:Container(
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
      child:Row(
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
                Text("Google Pay", style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
      
    ),
    onTap: (){
      info!.addFund(widget.amount);
      Navigator.pop(context);
    },
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
