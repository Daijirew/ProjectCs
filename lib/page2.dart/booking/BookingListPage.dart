import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:myproject/pages.dart/reviwe.dart';

class BookingListPage extends StatefulWidget {
  const BookingListPage({Key? key}) : super(key: key);

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<DocumentSnapshot> _bookings = [];
  String _filterStatus = 'all'; // all, pending, accepted, rejected, completed

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ดึงข้อมูลโดยใช้เพียง userId
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // กรองและเรียงลำดับข้อมูลในแอป
      List<DocumentSnapshot> filteredDocs = snapshot.docs;

      if (_filterStatus != 'all') {
        filteredDocs = filteredDocs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['status'] == _filterStatus;
        }).toList();
      }

      // เรียงลำดับตามวันที่สร้าง
      filteredDocs.sort((a, b) {
        Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
        Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;

        Timestamp? timestampA = dataA['createdAt'] as Timestamp?;
        Timestamp? timestampB = dataB['createdAt'] as Timestamp?;

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        return timestampB.compareTo(timestampA); // เรียงจากใหม่ไปเก่า
      });

      setState(() {
        _bookings = filteredDocs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกการจองเรียบร้อยแล้ว')),
      );

      // รีโหลดข้อมูล
      _loadBookings();
    } catch (e) {
      print('Error cancelling booking: $e');
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
          'การจองของฉัน',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ส่วนแถบตัวกรอง
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterButton('ทั้งหมด', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterButton('รอการยืนยัน', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterButton('ยอมรับแล้ว', 'accepted'),
                  const SizedBox(width: 8),
                  _buildFilterButton('ปฏิเสธแล้ว', 'rejected'),
                  const SizedBox(width: 8),
                  _buildFilterButton('ยกเลิกแล้ว', 'cancelled'),
                  const SizedBox(width: 8),
                  _buildFilterButton('เสร็จสิ้น', 'completed'),
                ],
              ),
            ),
          ),

          // ส่วนเนื้อหา
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่พบรายการจอง',
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
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          return _buildBookingCard(_bookings[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String title, String status) {
    final isSelected = _filterStatus == status;

    return GestureDetector(
      onTap: () {
        if (_filterStatus != status) {
          setState(() => _filterStatus = status);
          _loadBookings();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(DocumentSnapshot booking) {
    final bookingData = booking.data() as Map<String, dynamic>;
    final createdAt = bookingData['createdAt'] as Timestamp?;
    final dates = (bookingData['dates'] as List<dynamic>?)
            ?.map((date) => (date as Timestamp).toDate())
            .toList() ??
        [];

    // จัดการกับวันที่
    String dateRange;
    if (dates.isEmpty) {
      dateRange = 'ไม่ระบุวันที่';
    } else if (dates.length == 1) {
      dateRange = DateFormat('d MMM yyyy').format(dates[0]);
    } else {
      dates.sort();
      dateRange =
          '${DateFormat('d MMM').format(dates[0])} - ${DateFormat('d MMM yyyy').format(dates.last)}';
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(bookingData['sitterId']).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            margin: EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final sitterData = snapshot.data!.data() as Map<String, dynamic>?;
        final sitterName = sitterData?['name'] ?? 'ไม่ระบุชื่อ';
        final sitterPhoto = sitterData?['photo'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getStatusColor(bookingData['status']).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _showBookingDetails(booking),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            sitterPhoto != null && sitterPhoto.isNotEmpty
                                ? NetworkImage(sitterPhoto)
                                : null,
                        child: sitterPhoto == null || sitterPhoto.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sitterName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'สร้างเมื่อ: ${createdAt != null ? DateFormat('d MMM yyyy, HH:mm').format(createdAt.toDate()) : 'ไม่ระบุ'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(bookingData['status'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getStatusColor(bookingData['status']),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getStatusText(bookingData['status']),
                          style: TextStyle(
                            color: _getStatusColor(bookingData['status']),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.calendar_today,
                          'วันที่จอง',
                          dateRange,
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          Icons.payments,
                          'ค่าบริการ',
                          '${bookingData['totalPrice'] ?? 0} บาท',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.pets,
                          'จำนวนแมว',
                          '${(bookingData['catIds'] as List<dynamic>?)?.length ?? 0} ตัว',
                          Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // ปุ่มสำหรับการจองที่กำลังรอการยืนยัน
                            if (bookingData['status'] == 'pending')
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmCancelBooking(booking.id),
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                label: const Text(
                                  'ยกเลิก',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),

                            // ปุ่มให้คะแนนสำหรับการจองที่เสร็จสิ้นแล้ว
                            if (bookingData['status'] == 'completed')
                              TextButton.icon(
                                onPressed: () => _navigateToReview(
                                  bookingData['sitterId'],
                                  booking.id,
                                ),
                                icon:
                                    const Icon(Icons.star, color: Colors.amber),
                                label: const Text(
                                  'รีวิว',
                                  style: TextStyle(color: Colors.amber),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red.shade300;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'accepted':
        return 'ยอมรับแล้ว';
      case 'rejected':
        return 'ปฏิเสธแล้ว';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      case 'completed':
        return 'เสร็จสิ้น';
      default:
        return 'ไม่ระบุ';
    }
  }

  void _confirmCancelBooking(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: const Text('คุณต้องการยกเลิกการจองนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ไม่ใช่'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
  }

  void _navigateToReview(String sitterId, String bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewsPage(
          itemId: bookingId,
          sitterId: sitterId,
        ),
      ),
    );
  }

  void _showBookingDetails(DocumentSnapshot booking) {
    final bookingData = booking.data() as Map<String, dynamic>;
    final dates = (bookingData['dates'] as List<dynamic>)
        .map((date) => (date as Timestamp).toDate())
        .toList();

    // ดึงข้อมูลผู้รับเลี้ยง
    _firestore
        .collection('users')
        .doc(bookingData['sitterId'])
        .get()
        .then((sitterDoc) {
      if (!sitterDoc.exists || !mounted) return;

      final sitterData = sitterDoc.data() as Map<String, dynamic>;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'รายละเอียดการจอง',
                      style: AppWidget.HeadlineTextFeildStyle(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: sitterData['photo'] != null &&
                            sitterData['photo'].isNotEmpty
                        ? NetworkImage(sitterData['photo'])
                        : null,
                    child: sitterData['photo'] == null ||
                            sitterData['photo'].isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    sitterData['name'] ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(sitterData['email'] ?? 'ไม่ระบุอีเมล'),
                ),
                const SizedBox(height: 20),
                Text(
                  'วันที่ต้องการจ้าง:',
                  style: AppWidget.semiboldTextFeildStyle(),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(right: 10),
                        color: Colors.orange.shade100,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Center(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(dates[index]),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'ข้อมูลแมว:',
                  style: AppWidget.semiboldTextFeildStyle(),
                ),
                FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('users')
                      .doc(bookingData['userId'])
                      .collection('cats')
                      .where(FieldPath.documentId,
                          whereIn: bookingData['catIds'] ?? [])
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('ไม่พบข้อมูลแมว'),
                      );
                    }

                    return Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final catData = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.only(right: 10, top: 10),
                            child: Container(
                              width: 180,
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: catData['imagePath'] != null &&
                                                  catData['imagePath']
                                                      .isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                      catData['imagePath']),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: catData['imagePath'] == null ||
                                                catData['imagePath'].isEmpty
                                            ? const Icon(Icons.pets,
                                                color: Colors.grey)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              catData['name'] ?? 'ไม่ระบุชื่อ',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              catData['breed'] ??
                                                  'ไม่ระบุสายพันธุ์',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'วัคซีน: ${catData['vaccinations'] ?? 'ไม่ระบุ'}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.payments, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'ราคารวม: ${bookingData['totalPrice'] ?? 0} บาท',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (bookingData['notes'] != null &&
                    bookingData['notes'].isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'บันทึกเพิ่มเติม:',
                        style: AppWidget.semiboldTextFeildStyle(),
                      ),
                      const SizedBox(height: 5),
                      Text(bookingData['notes']),
                      const SizedBox(height: 10),
                    ],
                  ),
                const Spacer(),
                // แสดงปุ่มตามสถานะ
                if (bookingData['status'] == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmCancelBooking(booking.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'ยกเลิกการจอง',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                if (bookingData['status'] == 'completed' &&
                    (bookingData['reviewed'] == null ||
                        bookingData['reviewed'] == false))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToReview(
                          bookingData['sitterId'],
                          booking.id,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'ให้คะแนนและรีวิว',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }).catchError((e) {
      print('Error fetching sitter data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้รับเลี้ยง: $e')),
      );
    });
  }
}
