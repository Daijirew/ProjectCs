import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ฟังก์ชันลบข้อมูลผู้ใช้
  Future<void> _deleteUser(String userId, String userType) async {
    try {
      setState(() => _isLoading = true);
      
      // ลบข้อมูลผู้ใช้จาก Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      
      // ถ้าเป็น user ให้ลบข้อมูลแมวด้วย
      if (userType == 'user') {
        final catsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cats')
            .get();
        
        // ลบรูปแมวจาก Storage
        for (var doc in catsSnapshot.docs) {
          final catData = doc.data();
          if (catData['imagePath'] != null) {
            try {
              await FirebaseStorage.instance
                  .refFromURL(catData['imagePath'])
                  .delete();
            } catch (e) {
              print('Error deleting cat image: $e');
            }
          }
          // ลบข้อมูลแมวจาก Firestore
          await doc.reference.delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบข้อมูลสำเร็จ')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันลบแมว
  Future<void> _deleteCat(String userId, String catId, String? imagePath) async {
    try {
      setState(() => _isLoading = true);

      // ลบรูปแมวจาก Storage (ถ้ามี)
      if (imagePath != null) {
        try {
          await FirebaseStorage.instance.refFromURL(imagePath).delete();
        } catch (e) {
          print('Error deleting cat image: $e');
        }
      }

      // ลบข้อมูลแมวจาก Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cats')
          .doc(catId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบข้อมูลแมวสำเร็จ')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ผู้ใช้ทั่วไป'),
            Tab(text: 'พี่เลี้ยง'),
            Tab(text: 'แมว'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList('user'),
                _buildUserList('sitter'),
                _buildCatsList(),
              ],
            ),
    );
  }

  Widget _buildUserList(String userType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: userType)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return Center(child: Text('ไม่พบข้อมูล${userType == 'user' ? 'ผู้ใช้' : 'พี่เลี้ยง'}'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: userData['photo'] != null
                      ? NetworkImage(userData['photo'])
                      : null,
                  child: userData['photo'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(userData['name'] ?? 'ไม่ระบุชื่อ'),
                subtitle: Text(userData['email'] ?? 'ไม่ระบุอีเมล'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(
                    users[index].id,
                    userType,
                    userData['name'] ?? 'ผู้ใช้นี้',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCatsList() {
  return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${userSnapshot.error}'));
        }

        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: userSnapshot.data!.docs.length,
          itemBuilder: (context, userIndex) {
            final userId = userSnapshot.data!.docs[userIndex].id;
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('cats')
                  .snapshots(),
              builder: (context, catSnapshot) {
                if (catSnapshot.hasError || !catSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final cats = catSnapshot.data!.docs;
                if (cats.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'แมวของ: ${(userSnapshot.data!.docs[userIndex].data() as Map<String, dynamic>)['name'] ?? 'ไม่ระบุชื่อ'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...cats.map((cat) {
                      final catData = cat.data() as Map<String, dynamic>;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: catData['imagePath'] != null
                                ? NetworkImage(catData['imagePath'])
                                : null,
                            child: catData['imagePath'] == null
                                ? const Icon(Icons.pets)
                                : null,
                          ),
                          title: Text(catData['name'] ?? 'ไม่ระบุชื่อแมว'),
                          subtitle: Text(catData['breed'] ?? 'ไม่ระบุสายพันธุ์'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _showDeleteCatConfirmation(
                              userId,
                              cat.id,
                              catData['name'] ?? 'แมวตัวนี้',
                              catData['imagePath'],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(String userId, String userType, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบข้อมูลของ $name ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUser(userId, userType);
              },
              child: const Text(
                'ลบ',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCatConfirmation(
      String userId, String catId, String name, String? imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบข้อมูลของ $name ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCat(userId, catId, imagePath);
              },
              child: const Text(
                'ลบ',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}