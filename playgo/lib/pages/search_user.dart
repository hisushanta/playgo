import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playgo/main.dart'; // Import your ItemInfo class
import 'home.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  bool _isSearching = false;
  Timer? _debounce;
  String _selectedBoardSize = '9x9'; // Default board size

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUser();
    });
  }

  Future<void> _searchUser() async {
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) {
      setState(() {
        _isSearching = false;
        _foundUser = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
    });

    final userProfile = await info!.searchUserById(searchId);
    setState(() {
      _isSearching = false;
      _foundUser = userProfile;
    });

    if (_foundUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not found')),
      );
    }
  }

  Future<void> _sendMatchRequest(String entryPrice, String duration) async {
    if (_foundUser == null) return;

    final success = await info!.sendMatchRequest(
      userId,
      _foundUser!['id'],
      duration,
      entryPrice,
      _selectedBoardSize, // Pass the selected board size
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Match request sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send match request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Search User', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.grey[200],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter User ID',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: Colors.blue),
                      onPressed: _searchUser,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Loading or Results
              if (_isSearching)
                _buildShimmerLoading()
              else if (_foundUser != null)
                Expanded(child: _buildUserProfileCard()) // Use Expanded to avoid overflow
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: 200,
              height: 20,
              color: Colors.white,
            ),
            SizedBox(height: 10),
            Container(
              width: 150,
              height: 20,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    // Set default values if not provided
    final totalGameTime = _foundUser!['totalGameTime'] ?? '12';
    final entryPrice = _foundUser!['entryPrice']?.toStringAsFixed(2) ?? '0.00';

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
              SizedBox(height: 10),
              Text(
                'User ID: ${_foundUser!['id']}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 5),
              Text(
                'Username: ${_foundUser!['username']}',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              SizedBox(height: 20),
              // Editable Total Game Time
              _buildEditableFieldForMinutes(
                label: 'Total Game Time',
                value: totalGameTime,
                onChanged: (value) {
                  setState(() {
                    _foundUser!['totalGameTime'] = value;
                  });
                },
                icon: Icons.timer,
              ),
              SizedBox(height: 20),
              // Editable Entry Price
              _buildEditableField(
                label: 'Entry Price',
                value: entryPrice,
                onChanged: (value) {
                  setState(() {
                    _foundUser!['entryPrice'] = double.tryParse(value) ?? 0.0;
                  });
                },
                icon: Icons.attach_money,
              ),
              SizedBox(height: 20),
              // Board Size Selection
              _buildBoardSizeSelector(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _sendMatchRequest(entryPrice.toString(), totalGameTime.toString());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text('Request to Play Match'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to create an editable field with an icon
  Widget _buildEditableField({
    required String label,
    required String value,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: value,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Helper method to create an editable field with an icon
  Widget _buildEditableFieldForMinutes({
    required String label,
    required String value,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            initialValue: value,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Helper method to create a board size selector
  Widget _buildBoardSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Board Size',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBoardSizeOption('9x9'),
            _buildBoardSizeOption('13x13'),
          ],
        ),
      ],
    );
  }

  Widget _buildBoardSizeOption(String size) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBoardSize = size;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedBoardSize == size ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedBoardSize == size ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          size,
          style: TextStyle(
            fontSize: 16,
            color: _selectedBoardSize == size ? Colors.blue : Colors.white70,
            fontWeight: _selectedBoardSize == size ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No user found. Try searching again!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}