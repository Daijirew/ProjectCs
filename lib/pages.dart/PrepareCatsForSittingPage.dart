import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/Catpage.dart/cat.dart';
import 'package:myproject/pages.dart/matching/matching.dart';

class PrepareCatsForSittingPage extends StatefulWidget {
  const PrepareCatsForSittingPage({Key? key}) : super(key: key);

  @override
  State<PrepareCatsForSittingPage> createState() =>
      _PrepareCatsForSittingPageState();
}

class _PrepareCatsForSittingPageState extends State<PrepareCatsForSittingPage> {
  final List<Cat> selectedCats = [];
  List<Cat> userCats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCats();
  }

  Future<void> _loadUserCats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cats')
          .get();

      setState(() {
        userCats = snapshot.docs.map((doc) => Cat.fromFirestore(doc)).toList();
        // เลือกแมวที่เคยถูกเลือกไว้แล้วโดยอัตโนมัติ
        selectedCats.addAll(
          userCats.where((cat) => cat.isForSitting),
        );
        isLoading = false;
      });
    } catch (e) {
      print('Error loading cats: $e');
      setState(() => isLoading = false);
    }
  }

  void _toggleCatSelection(Cat cat) {
    setState(() {
      if (selectedCats.contains(cat)) {
        selectedCats.remove(cat);
      } else {
        selectedCats.add(cat);
      }
    });
  }

  Future<void> _saveCatsForSitting() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // อัพเดตสถานะแมวทุกตัว
      for (var cat in userCats) {
        final isSelected = selectedCats.contains(cat);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .doc(cat.id)
            .update({
          'isForSitting': isSelected,
        });
      }

      if (!mounted) return;

      if (selectedCats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเลือกแมวอย่างน้อย 1 ตัว')),
        );
        return;
      }

      // ไปยังหน้าเลือกวันที่
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectTargetDateScreen(
            onDateSelected: (dates) {
              // ต่อไปจะไปหน้าค้นหา sitter
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'เลือกแมวที่ต้องการฝาก',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: userCats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pets,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'ยังไม่มีแมวที่ลงทะเบียนไว้',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: userCats.length,
                          itemBuilder: (context, index) {
                            final cat = userCats[index];
                            final isSelected = selectedCats.contains(cat);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isSelected ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.orange
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _toggleCatSelection(cat),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          image: cat.imagePath.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                      cat.imagePath),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: cat.imagePath.isEmpty
                                            ? Icon(
                                                Icons.pets,
                                                size: 40,
                                                color: Colors.grey[400],
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              cat.breed,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (cat.vaccinations.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  'วัคซีน: ${cat.vaccinations}',
                                                  style: TextStyle(
                                                    color: Colors.green[700],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (_) =>
                                            _toggleCatSelection(cat),
                                        activeColor: Colors.orange,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (userCats.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'เลือกแล้ว ${selectedCats.length} ตัว',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveCatsForSitting,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'ดำเนินการต่อ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
