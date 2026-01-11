import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/Catpage.dart/cat.dart';
import 'package:myproject/pages.dart/matching/matching.dart';

class SelectCatsForSittingPage extends StatefulWidget {
  final List<DateTime> targetDates;

  const SelectCatsForSittingPage({
    Key? key,
    required this.targetDates,
  }) : super(key: key);

  @override
  State<SelectCatsForSittingPage> createState() =>
      _SelectCatsForSittingPageState();
}

class _SelectCatsForSittingPageState extends State<SelectCatsForSittingPage> {
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

  Future<void> _proceedToSitterSearch() async {
    if (selectedCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one cat')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // เก็บ ID ของแมวทั้งหมดที่ถูกเลือก
      final List<String> catIds = selectedCats.map((cat) => cat.id).toList();

      // แสดงข้อความ loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังตรวจสอบข้อมูล...')),
      );

      // Create a booking request document - ยังไม่มีการกำหนด sitterId ณ ตอนนี้
      // จะกำหนดเมื่อเลือกผู้รับเลี้ยงในหน้าถัดไป
      final bookingRequest = {
        'userId': user.uid,
        'catIds': catIds,
        'dates':
            widget.targetDates.map((date) => Timestamp.fromDate(date)).toList(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save the booking request
      DocumentReference bookingRef = await FirebaseFirestore.instance
          .collection('booking_requests')
          .add(bookingRequest);

      // อัพเดตสถานะแมวที่เลือก
      for (var cat in selectedCats) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .doc(cat.id)
            .update({'isForSitting': true});
      }

      // ขั้นตอนถัดไป ไปยังหน้าค้นหาผู้รับเลี้ยง
      if (!mounted) return;

      // ส่งต่อ booking reference เพื่อจะได้อัพเดต sitterId ในภายหลัง
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchSittersScreen(
            targetDates: widget.targetDates,
            catIds: selectedCats.map((cat) => cat.id).toList(),
            bookingRef: bookingRef.id, // เพิ่มค่านี้เพื่อส่งต่อให้หน้าถัดไป
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Cats for Sitting'),
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
                              Text(
                                'No cats registered',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
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
                    child: Column(
                      children: [
                        Text(
                          '${selectedCats.length} cats selected',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _proceedToSitterSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Continue to Find Sitter',
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
