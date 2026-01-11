import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/pages.dart/buttomnav.dart';
import 'package:myproject/pages.dart/sitterscreen/bookingService.dart';
import 'package:myproject/services/checklist_service.dart';
import 'package:myproject/services/shared_pref.dart';

import 'package:myproject/services/ServiceFeeCalculator.dart';

class BookingScreen extends StatefulWidget {
  final String sitterId;
  final List<DateTime> selectedDates;
  final List<String> catIds;
  final double pricePerDay;
  final String? bookingRef;
  final Map<String, double>? feeDetails;

  const BookingScreen({
    Key? key,
    required this.sitterId,
    required this.selectedDates,
    required this.catIds,
    required this.pricePerDay,
    this.bookingRef,
    this.feeDetails,
  }) : super(key: key);

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _notesController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BookingService _bookingService = BookingService();
  bool _isLoading = false;
  final Map<String, double> _feeDetails = {};

  @override
  void initState() {
    super.initState();

    // ถ้ามีข้อมูล feeDetails มาให้ใช้ ถ้าไม่มีให้คำนวณใหม่
    if (widget.feeDetails != null && widget.feeDetails!.isNotEmpty) {
      _feeDetails.addAll(widget.feeDetails!);
    } else {
      _calculateServiceFee();
    }
  }

  // เพิ่มฟังก์ชันคำนวณค่าบริการ
  Future<void> _calculateServiceFee() async {
    try {
      Map<String, double> fees = await ServiceFeeCalculator.calculateTotalFee(
        widget.selectedDates.length,
        widget.catIds.length,
      );

      setState(() {
        _feeDetails.clear();
        _feeDetails.addAll(fees);
      });
    } catch (e) {
      print('Error calculating fees: $e');
    }
  }

  // ฟังก์ชันสำหรับการยืนยันการจอง
  Future<void> _confirmBooking() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("กรุณาเข้าสู่ระบบ");

      // คำนวณค่าบริการทั้งหมด
      final totalPrice = _feeDetails.isNotEmpty
          ? _feeDetails['total']!
          : widget.pricePerDay * widget.selectedDates.length;

      // ดีบัก: แสดงค่าบริการที่จะชำระ
      print("ค่าบริการที่ต้องชำระ: $totalPrice");
      print("Booking Reference: ${widget.bookingRef}");

      // ถ้ามี bookingRef ให้นำ catIds จาก booking_request มาใช้
      List<String> catIds = widget.catIds;
      if (widget.bookingRef != null) {
        try {
          final bookingDoc = await _firestore
              .collection('booking_requests')
              .doc(widget.bookingRef)
              .get();

          if (bookingDoc.exists) {
            final bookingData = bookingDoc.data();
            if (bookingData != null && bookingData.containsKey('catIds')) {
              catIds = List<String>.from(bookingData['catIds']);
              print("Using catIds from booking_request: $catIds");
            }
          }
        } catch (e) {
          print("Error fetching booking_request data: $e");
        }
      }

      // ดึงข้อมูลแมวที่มีสถานะ isForSitting เป็น true (ถ้า catIds ว่าง)
      if (catIds.isEmpty) {
        final catsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cats')
            .where('isForSitting', isEqualTo: true)
            .get();

        catIds = catsSnapshot.docs.map((doc) => doc.id).toList();
        print("Using catIds from isForSitting: $catIds");
      }

      if (catIds.isEmpty) {
        throw Exception("กรุณาเลือกแมวที่ต้องการฝากเลี้ยง");
      }

      // ตรวจสอบยอดเงินในกระเป๋าเงินของผู้ใช้ - ทั้งจาก SharedPreferences และ Firestore
      double walletFromPrefs = 0;
      String? walletStrFromPrefs =
          await SharedPreferenceHelper().getUserWallet();
      if (walletStrFromPrefs != null && walletStrFromPrefs.isNotEmpty) {
        walletFromPrefs = double.tryParse(walletStrFromPrefs) ?? 0;
      }

      // ดีบัก: แสดงยอดเงินจาก SharedPreferences
      print("ยอดเงินจาก SharedPreferences: $walletFromPrefs");

      // ดึงข้อมูลจาก Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // ถ้าไม่มีข้อมูลใน Firestore ให้ใช้ค่าจาก SharedPreferences
        if (walletFromPrefs < totalPrice) {
          // แจ้งเตือนและนำไปยังหน้าหลัก
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'ยอดเงินในกระเป๋าไม่เพียงพอ กรุณาเติมเงิน (ยอดในกระเป๋า: ฿${walletFromPrefs.toStringAsFixed(2)}, ค่าบริการ: ฿${totalPrice.toStringAsFixed(2)})'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );

            // รอให้แสดง SnackBar สักครู่ก่อนนำไปหน้าหลัก
            Future.delayed(Duration(seconds: 1), () {
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => BottomNav()),
                  (route) => false,
                );
              }
            });
          }

          setState(() => _isLoading = false);
          return; // ออกจากฟังก์ชันทันที
        }

        // สร้างข้อมูล wallet ใน Firestore ถ้ายังไม่มี
        await _firestore.collection('users').doc(user.uid).set(
            {'wallet': walletFromPrefs.toStringAsFixed(0)},
            SetOptions(merge: true));

        // ใช้ค่าจาก SharedPreferences เป็นยอดปัจจุบัน
        double currentWallet = walletFromPrefs;
        double newWallet = currentWallet - totalPrice;
        String newWalletStr = newWallet.toStringAsFixed(0);

        // Using the BookingService to handle the transaction
        final bookingId = await _bookingService.createBooking(
            sitterId: widget.sitterId,
            dates: widget.selectedDates,
            totalPrice: totalPrice,
            notes: _notesController.text.trim(),
            catIds: catIds,
            currentWallet: currentWallet,
            newWallet: newWallet);

        // อัพเดตค่า wallet ใน SharedPreferences
        await SharedPreferenceHelper().saveUserWallet(newWalletStr);

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'จองสำเร็จ หักเงินจากกระเป๋าเงินแล้ว ฿$totalPrice บาท (เหลือ ฿$newWalletStr)')),
        );

        // Navigate to home screen instead of just popping
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => BottomNav()),
          (route) => false,
        );

        return;
      }

      // มีข้อมูลใน Firestore
      final userData = userDoc.data();
      String walletStr = userData?['wallet'] ?? "0";
      double walletFromFirestore = double.tryParse(walletStr) ?? 0;

      // ดีบัก: แสดงยอดเงินจาก Firestore
      print("ยอดเงินจาก Firestore: $walletFromFirestore");

      // ใช้ยอดเงินที่มากกว่าระหว่าง SharedPreferences และ Firestore
      // เพื่อป้องกันการสูญเสียเงินจากการซิงค์ข้อมูลผิดพลาด
      double currentWallet = walletFromFirestore > walletFromPrefs
          ? walletFromFirestore
          : walletFromPrefs;

      // ดีบัก: แสดงยอดเงินที่จะใช้
      print("ยอดเงินที่จะใช้ในการตรวจสอบ: $currentWallet");

      // คำนวณยอดเงินใหม่หลังหักค่าบริการ
      double newWallet = currentWallet - totalPrice;
      String newWalletStr = newWallet.toStringAsFixed(0);

      // ดีบัก: แสดงยอดเงินคงเหลือหลังหักค่าบริการ
      print("ยอดเงินคงเหลือหลังหักค่าบริการ: $newWallet");

      // Using the BookingService to handle the transaction
      final bookingId = await _bookingService.createBooking(
          sitterId: widget.sitterId,
          dates: widget.selectedDates,
          totalPrice: totalPrice,
          notes: _notesController.text.trim(),
          catIds: catIds,
          currentWallet: currentWallet,
          newWallet: newWallet);

      // อัพเดตค่า wallet ใน SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(newWalletStr);

      if (!mounted) return;

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'จองสำเร็จ หักเงินจากกระเป๋าเงินแล้ว ฿$totalPrice บาท (เหลือ ฿$newWalletStr)')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => BottomNav()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // แสดงข้อความแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      // ถ้า exception เกี่ยวกับเงินไม่พอ ให้กลับไปหน้าหลัก
      if (e.toString().contains('ยอดเงินในกระเป๋าไม่เพียงพอ')) {
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => BottomNav()),
              (route) => false,
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ตรวจสอบว่าวันที่เลือกยังว่างอยู่
  Future<bool> _checkDateAvailability() async {
    try {
      final bookingSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: widget.sitterId)
          .where('status', whereIn: ['pending', 'confirmed']).get();

      // ตรวจสอบการซ้ำซ้อนของวันที่
      for (var booking in bookingSnapshot.docs) {
        List<Timestamp> bookedDates = List<Timestamp>.from(booking['dates']);
        for (var bookedDate in bookedDates) {
          if (widget.selectedDates
              .any((date) => isSameDay(date, bookedDate.toDate()))) {
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  // เปรียบเทียบวันที่
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณราคาทั้งหมด ใช้ค่าจาก _feeDetails ถ้ามี ถ้าไม่มีให้คำนวณแบบเดิม
    double totalPrice = _feeDetails.isNotEmpty
        ? _feeDetails['total']!
        : widget.pricePerDay * widget.selectedDates.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ยืนยันการจอง'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ส่วนแสดงแมวที่เลือก
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'แมวที่เลือก',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('จำนวน ${widget.catIds.length} ตัว'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // ส่วนแสดงวันที่เลือก
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วันที่เลือก',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.selectedDates.map((date) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(date),
                          ),
                        );
                      }).toList(),
                    ),
                    Text(
                      'จำนวน ${widget.selectedDates.length} วัน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // ส่วนแสดงรายละเอียดค่าบริการ
            Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รายละเอียดค่าบริการ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_feeDetails.isNotEmpty) ...[
                      _buildPriceRow(
                          'ค่าบริการพื้นฐาน', _feeDetails['baseFee']!),
                      _buildPriceRow(
                          'ค่าคอมมิชชั่น', _feeDetails['commission']!),
                      _buildPriceRow('ภาษีมูลค่าเพิ่ม', _feeDetails['tax']!),
                      Divider(),
                      _buildPriceRow('รวมทั้งสิ้น', _feeDetails['total']!,
                          isTotal: true),
                    ] else ...[
                      _buildPriceRow('ค่าบริการทั้งหมด', totalPrice,
                          isTotal: true),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // ช่องสำหรับใส่บันทึกเพิ่มเติม
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'บันทึกเพิ่มเติม',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText:
                            'เช่น ข้อมูลเกี่ยวกับแมวของคุณ หรือคำแนะนำเพิ่มเติม',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _confirmBooking,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('ยืนยันการจอง'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method เพื่อแสดงแถวราคา
  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '฿${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createBooking({
    required String sitterId,
    required List<DateTime> dates,
    required double totalPrice,
    required String notes,
    required List<String> catIds,
    required double currentWallet,
    required double newWallet,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("กรุณาเข้าสู่ระบบ");

    // Create a reference to a new document with auto-generated ID
    final bookingRef = _firestore.collection('bookings').doc();

    // ทำการบันทึกข้อมูลการจอง
    await bookingRef.set({
      'userId': user.uid,
      'sitterId': sitterId,
      'dates': dates.map((date) => Timestamp.fromDate(date)).toList(),
      'totalPrice': totalPrice,
      'notes': notes,
      'catIds': catIds,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // อัพเดตยอดเงินในบัญชีผู้ใช้
    await _firestore.collection('users').doc(user.uid).update({
      'wallet': newWallet.toStringAsFixed(0),
    });

    // สร้างเช็คลิสต์เริ่มต้นสำหรับการจองนี้
    try {
      final ChecklistService checklistService = ChecklistService();
      await checklistService.createDefaultChecklist(
        bookingRef.id,
        user.uid,
        sitterId,
        catIds,
      );
    } catch (e) {
      print('Error creating default checklist: $e');
      // ไม่ throw ข้อผิดพลาด เพราะไม่ควรทำให้การจองล้มเหลวเพียงเพราะสร้างเช็คลิสต์ไม่สำเร็จ
    }

    return bookingRef.id;
  }
}
