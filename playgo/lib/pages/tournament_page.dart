import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'fund_page.dart';

class TournamentPage extends StatefulWidget {
  @override
  GameTournamentPage createState() => GameTournamentPage();
}
class GameTournamentPage extends State<TournamentPage>{

  Color allColor =  Color.fromARGB(255, 241, 239, 239);
  Color regularColor =  Color.fromARGB(255, 241, 239, 239);
  bool isallCheck = false;
  bool isregularCheck = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 246, 247),
      appBar: AppBar(
        title: Text('Play Match', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(width: 12),
            Icon(Icons.currency_rupee, color: Colors.black,size: 16.0,),
            Text(
              '${info!.userProfile[info!.uuid]!['fund']}',
              style: TextStyle(color: Colors.black),
            ),
            SizedBox(width: 20),
            CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 213, 246, 206),
              radius: 14,
              child: Icon(Icons.add, color: Colors.black, size: 18),
            ),
          ],
        ),
        onTap: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) =>  AddCashPage()));
        },
          ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilterChip(
                            label: Text('Clear All', style: TextStyle(color: Colors.red),),
                            backgroundColor: Colors.white,
                            onSelected: (val) {
                              setState(() {
                               isallCheck = false;
                                isregularCheck = false;
                                allColor = const Color.fromARGB(255, 241, 239, 239);
                                regularColor = const Color.fromARGB(255, 241, 239, 239);
                              });
                            },
                          ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Sort by Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<String>(
                        hint: Text("Sort by Price"),
                        value: null,
                        items: [
                          DropdownMenuItem(
                            value: "low_to_high",
                            child: Text("Price: Low to High"),
                          ),
                          DropdownMenuItem(
                            value: "high_to_low",
                            child: Text("Price: High to Low"),
                          ),
                        ],
                        onChanged: (value) {
                          // Logic for sorting based on selected value
                          if (value == "low_to_high") {
                            // Sort by low to high
                          } else if (value == "high_to_low") {
                            // Sort by high to low
                          }
                        },
                      ),
                      // Game Modes
                      Row(
                        children: [
                          FilterChip(
                            label: Text('All'),
                            backgroundColor: allColor,
                            onSelected: (val) {
                              setState(() {
                                if (!isallCheck) {
                                  allColor = Color.fromARGB(255, 247, 255, 16);
                                  isallCheck = true;
                                } else {
                                  allColor = Color.fromARGB(255, 241, 239, 239);
                                  isallCheck = false;
                                }
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          FilterChip(
                            label: Text('Regular'),
                            backgroundColor: regularColor,
                            onSelected: (val) {
                              setState(() {
                                if (!isregularCheck) {
                                  regularColor = const Color.fromARGB(255, 247, 255, 16);
                                  isregularCheck = true;
                                } else {
                                  regularColor = Color.fromARGB(255, 241, 239, 239);
                                  isregularCheck = false;
                                }
                              });
                            },
                          ),
                        
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),


            // Recommended Tournaments Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recommended Tournaments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Tournament List
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 4,
              itemBuilder: (context, index) => buildTournamentTile(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTournamentTile(int index) {
    final prizePools = ['₹8.5', '₹1.7', '₹17', '₹20'];
    final entries = ['₹5', '₹1', '₹10', '₹15'];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:Column(
            children: [
              Card (
              color: const Color.fromARGB(255, 199, 237, 236),
                child:Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text('Regular', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                      SizedBox(width: 8),
                      Icon(Icons.timer, size: 16, color: Colors.amber),
                    ],
                  ),
                ],
              ),
              ),
              // SizedBox(height: 8),
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
                            prizePools[index],
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.black),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('ENTRY', style: TextStyle(fontSize: 12, color: Colors.grey,fontStyle: FontStyle.italic)),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          entries[index],
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
