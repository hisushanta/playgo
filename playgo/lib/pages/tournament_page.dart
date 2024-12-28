import 'package:flutter/material.dart';
import 'package:playgo/main.dart';
import 'fund_page.dart';

class GameTournamentPage extends StatelessWidget {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      FilterChip(label: Text('All'), onSelected: (val) {}),
                      SizedBox(width: 8),
                      FilterChip(label: Text('Regular'), onSelected: (val) {}),
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
