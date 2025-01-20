import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'cat.dart';

class CatEditPage extends StatefulWidget {
  final Cat cat;

  const CatEditPage({Key? key, required this.cat}) : super(key: key);

  @override
  State<CatEditPage> createState() => _CatEditPageState();
}

class _CatEditPageState extends State<CatEditPage> {
  late TextEditingController nameController;
  late TextEditingController breedController;
  late TextEditingController vaccinationsController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.cat.name);
    breedController = TextEditingController(text: widget.cat.breed);
    vaccinationsController =
        TextEditingController(text: widget.cat.vaccinations);
    descriptionController = TextEditingController(text: widget.cat.description);
  }

  @override
  void dispose() {
    nameController.dispose();
    breedController.dispose();
    vaccinationsController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    // อัปเดตข้อมูลใน Firestore
    try {
      await FirebaseFirestore.instance
          .collection('cats')
          .doc(widget.cat.id)
          .update({
        'name': nameController.text,
        'breed': breedController.text,
        'vaccinations': vaccinationsController.text,
        'description': descriptionController.text,
      });

      // เมื่ออัปเดตสำเร็จ ให้กลับไปที่หน้าก่อนหน้า
      Navigator.pop(
        context,
        Cat(
          id: widget.cat.id,
          name: nameController.text,
          breed: breedController.text,
          imagePath: widget.cat.imagePath,
          birthDate: widget.cat.birthDate,
          vaccinations: vaccinationsController.text,
          description: descriptionController.text,
        ),
      );
    } catch (e) {
      // หากมีข้อผิดพลาดเกิดขึ้น
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cat data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Cat Details'),
        backgroundColor: Colors.orange.shade400,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: breedController,
              decoration: const InputDecoration(
                labelText: 'Breed',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: vaccinationsController,
              decoration: const InputDecoration(
                labelText: 'Vaccinations',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
