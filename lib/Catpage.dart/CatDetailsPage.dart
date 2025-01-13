import 'package:flutter/material.dart';
import 'cat.dart'; // import โมเดล Cat

class CatDetailsPage extends StatelessWidget {
  final Cat cat;

  const CatDetailsPage({Key? key, required this.cat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${cat.name} Details'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // จัดให้อยู่กลาง
            crossAxisAlignment:
                CrossAxisAlignment.center, // จัดให้ตรงกลางแนวขวาง
            children: [
              // แสดงภาพแมวถ้ามี
              if (cat.imagePath.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      cat.imagePath,
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                const CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    Icons.pets,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 20),

              // ข้อมูลของแมว
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${cat.name}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Breed: ${cat.breed}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Birthdate: ${cat.birthDate?.toDate().toString().split(' ')[0] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
