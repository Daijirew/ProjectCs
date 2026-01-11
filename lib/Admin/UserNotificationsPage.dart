import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({Key? key}) : super(key: key);

  @override
  _UserNotificationsPageState createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  bool _isLoading = true;
  List<DocumentSnapshot> _notifications = [];
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      _loadNotifications();
    } else {
      // ไม่มีผู้ใช้ที่ล็อกอินอยู่
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();
      
      setState(() {
        _notifications = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดการแจ้งเตือน: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      
      setState(() {
        // อัพเดตสถานะการอ่านในรายการปัจจุบัน
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          Map<String, dynamic> data = _notifications[index].data() as Map<String, dynamic>;
          data['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('การแจ้งเตือนของฉัน'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'ไม่มีการแจ้งเตือน',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  padding: EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final data = notification.data() as Map<String, dynamic>;
                    
                    final bool isRead = data['isRead'] ?? false;
                    final String type = data['type'] ?? '';
                    final String title = data['title'] ?? 'การแจ้งเตือน';
                    final String message = data['message'] ?? '';
                    final Timestamp? timestamp = data['timestamp'];
                    
                    // เลือกสีตามประเภทการแจ้งเตือน
                    Color notificationColor = Colors.blue;
                    if (type == 'verification') {
                      if (title.contains('อนุมัติ')) {
                        notificationColor = Colors.green;
                      } else if (title.contains('ไม่ได้รับการอนุมัติ') || title.contains('ระงับ')) {
                        notificationColor = Colors.red;
                      }
                    }
                    
                    return Card(
                      elevation: isRead ? 1 : 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isRead ? Colors.transparent : notificationColor.withOpacity(0.5),
                          width: isRead ? 0 : 1,
                        ),
                      ),
                      margin: EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () {
                          // ทำเครื่องหมายว่าอ่านแล้ว
                          if (!isRead) {
                            _markAsRead(notification.id);
                          }
                          
                          // แสดงข้อความเต็ม
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(title),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(message),
                                    SizedBox(height: 16),
                                    Text(
                                      timestamp != null 
                                          ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()) 
                                          : 'ไม่ระบุเวลา',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('ปิด'),
                                ),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: notificationColor.withOpacity(0.2),
                                child: Icon(
                                  _getNotificationIcon(type, title),
                                  color: notificationColor,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: notificationColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      message.length > 100 
                                          ? message.substring(0, 100) + '...' 
                                          : message,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        height: 1.3,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      timestamp != null 
                                          ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate()) 
                                          : 'ไม่ระบุเวลา',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  IconData _getNotificationIcon(String type, String title) {
    if (type == 'verification') {
      if (title.contains('อนุมัติ')) {
        return Icons.check_circle;
      } else if (title.contains('ไม่ได้รับการอนุมัติ') || title.contains('ระงับ')) {
        return Icons.cancel;
      } else {
        return Icons.verified_user;
      }
    } else if (type == 'booking') {
      return Icons.calendar_today;
    } else if (type == 'payment') {
      return Icons.payment;
    } else {
      return Icons.notifications;
    }
  }
}