import 'dart:async';

import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'fund_page.dart';
import 'home.dart';

class TournamentPage extends StatefulWidget {
  @override
  GameTournamentPage createState() => GameTournamentPage();
}

class GameTournamentPage extends State<TournamentPage> {
  Color allColor = Color.fromARGB(255, 247, 255, 16); // Default selected
  Color regularColor = Color.fromARGB(255, 241, 239, 239);
  bool isallCheck = true; // Default is "All"
  bool isregularCheck = false;

  List<Map<String, String>> tournaments = [];
  List<Map<String, String>> filteredTournaments = [];
  String? selectedSortOption; // Holds the currently selected sort option

  @override
  void initState() {
    super.initState();
    // Initialize tournaments list
    tournaments = (info!.itemInfo[userId]! as List<dynamic>).map((tournament) {
      return {
        "entryPrice": tournament[0].toString(),
        "prizePools": tournament[1].toString(),
        "category": tournament[2].toString(),
        "time":tournament[3].toString(),
      };
    }).toList();
    filteredTournaments = List.from(tournaments); // Default to showing all items
  }

  void applyFilter(String filter) {
    setState(() {
      if (filter == "all") {
        filteredTournaments = List.from(tournaments);
        allColor = Color.fromARGB(255, 247, 255, 16);
        regularColor = Color.fromARGB(255, 241, 239, 239);
        isallCheck = true;
        isregularCheck = false;
      } else if (filter == "regular") {
        filteredTournaments = tournaments
            .where((tournament) => tournament["category"] == "Regular")
            .toList();
        allColor = Color.fromARGB(255, 241, 239, 239);
        regularColor = Color.fromARGB(255, 247, 255, 16);
        isallCheck = false;
        isregularCheck = true;
      }
    });
  }

  void resetSorting() {
    setState(() {
      selectedSortOption = null; // Reset sort option to default
      if (isallCheck) {
        filteredTournaments = List.from(tournaments);
      } else if (isregularCheck) {
        filteredTournaments = tournaments
            .where((tournament) => tournament["category"] == "Regular")
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 246, 247),
      appBar: AppBar(
        title: Text('Play Match', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          GestureDetector(
            child: Padding ( 
              padding: EdgeInsets.all(8.0),
              child: Row(
              children: [
                Icon(Icons.currency_rupee, color: Colors.black, size: 16.0),
                Text(
                  '${info!.userProfile[info!.uuid]!['fund']}',
                  style: TextStyle(color: Colors.black),
                ),
                SizedBox(width: 20),
                CircleAvatar(
                  backgroundColor: Color.fromARGB(255, 213, 246, 206),
                  radius: 14,
                  child: Icon(Icons.add, color: Colors.black, size: 18),
                ),
              ],
            ),
            ),
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (context) => AddCashPage()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<String>(
                    hint: Text(selectedSortOption == null
                        ? "Sort by Price"
                        : selectedSortOption == "low_to_high"
                            ? "Price: Low to High"
                            : selectedSortOption == "high_to_low"
                                ? "Price: High to Low"
                                : "Sort by Price"), // Display based on current option
                    value: selectedSortOption,
                    items: [
                      DropdownMenuItem(
                        value: "low_to_high",
                        child: Text("Price: Low to High"),
                      ),
                      DropdownMenuItem(
                        value: "high_to_low",
                        child: Text("Price: High to Low"),
                      ),
                      DropdownMenuItem(
                        value: "reset",
                        child: Text("Reset"),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSortOption = value;
                          if (value == "low_to_high") {
                            filteredTournaments.sort((a, b) =>
                                int.parse(a["entryPrice"]!)
                                    .compareTo(int.parse(b["entryPrice"]!)));
                          } else if (value == "high_to_low") {
                            filteredTournaments.sort((a, b) =>
                                int.parse(b["entryPrice"]!)
                                    .compareTo(int.parse(a["entryPrice"]!)));
                          } else if (value == "reset") {
                            resetSorting();
                          }
                        });
                      }
                    },
                  ),
                  Row(
                    children: [
                      FilterChip(
                        label: Text('All'),
                        backgroundColor: allColor,
                        onSelected: (val) => applyFilter("all"),
                      ),
                      SizedBox(width: 8),
                      FilterChip(
                        label: Text('Regular'),
                        backgroundColor: regularColor,
                        onSelected: (val) => applyFilter("regular"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recommended Tournaments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: filteredTournaments.length,
              itemBuilder: (context, index) {
                final tournament = filteredTournaments[index];
                return buildTournamentTile(
                  tournament["entryPrice"]!,
                  tournament["prizePools"]!,
                  tournament["category"]!,
                  tournament['time']!,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTournamentTile(String entryPrice, String prizePools, String category,String time) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Card(
                color: const Color.fromARGB(255, 199, 237, 236),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.timer, size: 16, color: Colors.amber),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prize Pool', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Row(
                        children: [
                          Text(
                            prizePools,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.black),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('ENTRY',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic)),
                      ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                          ),
                          builder: (context) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Handle for aesthetic purposes
                                  Container(
                                    width: 50,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  // Currency Icon
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.purple.withOpacity(0.1),
                                    child: Icon(
                                      Icons.currency_rupee,
                                      color: Colors.purple,
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(height: 15),
                                  // Title
                                  Text(
                                    "Confirm Payment",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  // Game Info
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timer, size: 20, color: Colors.amber),
                                      SizedBox(width: 5),
                                      Text(
                                        "$time min Go",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  // Entry Fee
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Entry Fee",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          "₹$entryPrice",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 30),
                                  // Join Now Button
                                  ElevatedButton(
                                    onPressed: () {
                                    Navigator.pop(context); // Close the current dialog
                                    info!.updateGameStatus("Active");
                                    showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                                    ),
                                    builder: (context) {
                                      return CountdownBottomDialog();
                                    },
                                  );
                                      // Handle payment confirmation logic here
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      backgroundColor: Colors.yellow,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: Text(
                                      "Join Now",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        entryPrice,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CountdownBottomDialog extends StatefulWidget {
  @override
  _CountdownBottomDialogState createState() => _CountdownBottomDialogState();
}

class _CountdownBottomDialogState extends State<CountdownBottomDialog> {
  late int _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = 30; // 30 seconds countdown
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentTime > 0) {
          _currentTime--;
        } else {
          _timer.cancel();
          info!.updateGameStatus("DeActive");
          Navigator.pop(context); // Close the dialog when countdown reaches 0
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(onPressed: (){
                _timer.cancel();
                info!.updateGameStatus("DeActive");
                Navigator.pop(context);
              }, 
              child: Icon(Icons.cancel_outlined,color: Colors.white,),
              style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),)
            ],
          ),
          // Handle for aesthetic purposes
          Container(
            width: double.maxFinite,
            height: 5,
          ),
          SizedBox(height: 20),
          // Title
          Text(
            "Game starting in...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          // Countdown Timer
          Text(
            "$_currentTime",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          // Additional Info (Optional)
          Text(
            "Get ready to play!",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
