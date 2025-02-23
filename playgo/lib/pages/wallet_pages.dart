import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'package:playgo/pages/fund_page.dart';
import 'home.dart';

class WalletPage extends StatefulWidget {
  @override
  _WalletPage createState() => _WalletPage();
}

class _WalletPage extends State<WalletPage> {
  String fundBalance = "0.0";
  String deposit = "0.0";
  String winning = '0.0';

  @override
  void initState() {
    _loadData();
    super.initState();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      fundBalance = info?.userProfile[info?.uuid]?['fund'] ?? '0.0'; // Provide a default value
      deposit = info?.userProfile[info?.uuid]?['deposit'] ?? '0.0'; // Provide a default value
      winning = info?.userProfile[info?.uuid]?['winning'] ?? '0.0'; // Provide a default value
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Wallet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildBalanceCard(),
              SizedBox(height: 16),
              _buildSection('Deposits', '₹${double.parse(deposit).toStringAsFixed(2)}', 'Add Cash', Colors.green, Icons.add, context),
              SizedBox(height: 16),
              _buildSection('Winnings', '₹${double.parse(winning).toStringAsFixed(2)}', 'Withdraw', Colors.orange, Icons.arrow_downward, context),
              SizedBox(height: 16),
              _buildInfoSection('Cashback Reward', '₹1.32', 'CASHBACK DETAILS'),
              SizedBox(height: 16),
              _buildInfoSection('Bonus Reward', '₹0', 'BONUS DETAILS'),
              SizedBox(height: 16),
              _buildOptions('Saved Payment Modes'),
              SizedBox(height: 8),
              _buildOptions('Transaction History'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: EdgeInsets.all(16.0),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Icon(Icons.info_outline, size: 16, color: Colors.black54),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '₹${double.parse(fundBalance).toStringAsFixed(2)}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String amount, String actionText, Color buttonColor, IconData icon, BuildContext context) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: Colors.black54)),
              SizedBox(height: 4),
              Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (actionText == 'Add Cash') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCashPage()),
                );
                _loadData(); // Reload data after returning from AddCashPage
              }
            },
            icon: Icon(icon, color: Colors.white, size: 16),
            label: Text(actionText),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String amount, String actionText) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: Colors.black54)),
              SizedBox(height: 4),
              Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              actionText,
              style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(String title) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Icon(Icons.chevron_right, color: Colors.black54),
        ],
      ),
    );
  }
}