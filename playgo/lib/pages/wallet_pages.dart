import 'package:flutter/material.dart';
import 'package:playgo/main.dart';

class WalletPage extends StatefulWidget {
  @override
  _WalletPage createState() => _WalletPage();
}

class _WalletPage extends State<WalletPage> {
  String totalPoints = "0";
  String winningsPoints = "0";
  String rewardsPoints = "0";

  @override
  void initState() {
    _loadData();
    super.initState();
  }

  void _loadData() {
    if (!mounted) return;
    setState(() {
      // Load points data from user profile
      totalPoints = info?.userProfile[info?.uuid]?['fund'] ?? '0';
      winningsPoints = info?.userProfile[info?.uuid]?['winning'] ?? '0';
      rewardsPoints = info?.userProfile[info?.uuid]?['rewards'] ?? '0';
    });
  }

  // Helper function to format points with proper decimal handling
  String _formatPoints(String points) {
    try {
      double value = double.parse(points);
      // If it's a whole number, show without decimals
      if (value == value.truncateToDouble()) {
        return value.truncate().toString();
      }
      // Otherwise show with up to 2 decimal places
      return value.toStringAsFixed(2);
    } catch (e) {
      return points; // Return original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
      ),
      body: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Points balance header
              _buildPointsHeader(),
              
              // Points summary and other content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildPointsSummary(),
                    SizedBox(height: 24),
                    _buildRewardsSection(),
                    SizedBox(height: 24),
                    _buildPointsInfo(),
                    SizedBox(height: 16), // Extra space at bottom for better scrolling
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Points ⭐',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _formatPoints(totalPoints),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Available to use in games',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total Points
          _buildPointsItem(
            title: 'Total Points',
            points: _formatPoints(totalPoints),
            icon: Icons.account_balance_wallet,
            color: Colors.blue,
          ),
          Divider(height: 24),
          // Winnings Points
          _buildPointsItem(
            title: 'Winnings Points',
            points: _formatPoints(winningsPoints),
            icon: Icons.emoji_events,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPointsItem({String? title, String? points, IconData? icon, Color? color}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color?.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            title!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          points!,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rewards',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Show rewards details
                  _showRewardsDetails(context);
                },
                child: Text(
                  'DETAILS',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.card_giftcard, color: Colors.purple, size: 22),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Available Rewards',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                _formatPoints(rewardsPoints),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Points',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          _buildInfoItem('Total Points: Points available for use in games'),
          SizedBox(height: 8),
          _buildInfoItem('Winnings Points: Points earned from game victories'),
          SizedBox(height: 8),
          _buildInfoItem('Rewards: Special points from promotions and events'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, size: 8, color: Colors.grey),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  void _showRewardsDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rewards Details'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Your rewards points: ${_formatPoints(rewardsPoints)}'),
                SizedBox(height: 16),
                Text('Rewards points are earned through:'),
                SizedBox(height: 8),
                Text('• Special promotions'),
                Text('• Daily check-ins'),
                Text('• Event participation'),
                Text('• Referral bonuses'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}