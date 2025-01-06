import 'package:flutter/material.dart';
import 'add_fund.dart';

class AddCashPage extends StatefulWidget {
  @override
  _AddCashPageState createState() => _AddCashPageState();
}

class _AddCashPageState extends State<AddCashPage> {
  TextEditingController _amountController = TextEditingController();
  bool _isAmountEntered = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {
        _isAmountEntered = _amountController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Cash', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.currency_rupee, color: Colors.black),
                    hintText: 'Enter amount here',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAmountButton(context, '₹100'),
                  _buildAmountButton(context, '₹50'),
                  _buildAmountButton(context, '₹10'),
                ],
              ),
              SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.lock, color: Colors.green, size: 30),
                    SizedBox(height: 8),
                    Text(
                      '100% Safe & Secure',
                      style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAmountEntered
                      ? () {
                          // Add functionality to handle adding money
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentOptionsPage()));
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    backgroundColor: _isAmountEntered ? Colors.yellow : Colors.deepPurple,
                  ),
                  child: Text(
                    'Add Money',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isAmountEntered ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountButton(BuildContext context, String amount) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _amountController.text = amount.replaceAll('₹', '');
        });
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        backgroundColor: Colors.green.withOpacity(0.1),
        foregroundColor: Colors.green,
        elevation: 0,
      ),
      child: Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}
