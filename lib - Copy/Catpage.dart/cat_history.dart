import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myproject/Catpage.dart/CatRegistrationPage.dart';
import 'package:myproject/Catpage.dart/cat.dart';
import 'CatDetailsPage.dart'; // import หน้ารายละเอียดของแมว

class CatHistoryPage extends StatefulWidget {
  const CatHistoryPage({Key? key}) : super(key: key);

  @override
  _CatHistoryPageState createState() => _CatHistoryPageState();
}

class _CatHistoryPageState extends State<CatHistoryPage> {
  List<Cat> cats = [];
  List<Cat> filteredCats = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .snapshots()
          .listen((snapshot) {
        setState(() {
          cats = snapshot.docs.map((doc) => Cat.fromFirestore(doc)).toList();
          filteredCats = cats;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cat History'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CatRegistrationPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  filteredCats = cats
                      .where((cat) =>
                          cat.name.toLowerCase().contains(value.toLowerCase()))
                      .toList();
                });
              },
              decoration: InputDecoration(
                labelText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredCats.length,
              itemBuilder: (context, index) {
                final cat = filteredCats[index];
                return Card(
                  child: ListTile(
                    leading: cat.imagePath.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage:
                                NetworkImage(cat.imagePath), // ใช้ NetworkImage
                          )
                        : null,
                    title: Text(cat.name),
                    subtitle: Text(cat.breed),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CatDetailsPage(cat: cat), // ไปหน้ารายละเอียด
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CatRegistrationPage(cat: cat),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
