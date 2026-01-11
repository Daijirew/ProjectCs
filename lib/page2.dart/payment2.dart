// lib/page2.dart/payment2.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:intl/intl.dart';

class Payment2 extends StatefulWidget {
  const Payment2({super.key});

  @override
  State<Payment2> createState() => _Payment2State();
}

class _Payment2State extends State<Payment2> {
  String? wallet, id;
  bool isLoading = false;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> pendingPayments = [];
  List<Map<String, dynamic>> completedJobs = [];
  double totalEarnings = 0; // เพิ่มตัวแปรนี้เพื่อเก็บยอดรายได้ทั้งหมด

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _calculateTotalEarnings(); // ตรวจสอบว่ามีการเรียกใช้ฟังก์ชันนี้
    _loadTransactions();
    _loadPendingPayments();
    _loadCompletedJobs();
  }

  Future<bool> _checkFirestoreConnection() async {
    try {
      await _firestore.collection('test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print("Firestore connection error: $e");
      return false;
    }
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      // ตรวจสอบการเชื่อมต่อกับ Firestore
      bool hasConnection = await _checkFirestoreConnection();
      if (!hasConnection) {
        throw Exception("ไม่สามารถเชื่อมต่อกับ Firestore ได้");
      }

      // ดึงข้อมูลจาก Firestore โดยตรง (จะเป็นข้อมูลล่าสุดเสมอ)
      if (_currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('wallet')) {
            wallet = userData['wallet'] ?? "0";

            // ตรวจสอบค่าและแก้ไขถ้าจำเป็น
            double walletAmount = double.tryParse(wallet!) ?? 0;
            if (walletAmount < 0) walletAmount = 0;
            wallet = walletAmount.toStringAsFixed(0);

            // อัพเดท SharedPreferences
            await SharedPreferenceHelper().saveUserWallet(wallet!);
          } else {
            wallet = "0";
            await _firestore
                .collection('users')
                .doc(_currentUser!.uid)
                .update({'wallet': wallet});
            await SharedPreferenceHelper().saveUserWallet(wallet!);
          }
        } else {
          wallet = "0";
        }
      } else {
        wallet = await SharedPreferenceHelper().getUserWallet() ?? "0";
      }

      id = await SharedPreferenceHelper().getUserId();

      // อัพเดต totalEarnings เพื่อแสดงในหน้าจอ
      totalEarnings = double.tryParse(wallet!) ?? 0;
    } catch (e) {
      print("Error loading user data: $e");
      wallet = await SharedPreferenceHelper().getUserWallet() ?? "0";
      totalEarnings = double.tryParse(wallet!) ?? 0;
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    if (_currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      setState(() {
        transactions = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print("Error loading transactions: $e");
    }
  }

  Future<void> _resetAndRecalculateEarnings() async {
    try {
      if (_currentUser == null) return;

      // ดึงข้อมูลรายได้จากงานที่เสร็จแล้ว (completed)
      double totalCompletedRevenue = 0;
      final completedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in completedSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('totalPrice')) {
          totalCompletedRevenue += (data['totalPrice'] as num).toDouble();
        }
      }

      // ดึงข้อมูลการถอนเงิน
      double totalWithdrawn = 0;
      final withdrawals = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'withdraw')
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in withdrawals.docs) {
        final data = doc.data();
        if (data.containsKey('amount')) {
          totalWithdrawn += (data['amount'] as num).toDouble();
        }
      }

      // คำนวณยอดเงินคงเหลือที่ถูกต้อง (ไม่ติดลบ)
      double calculatedBalance = totalCompletedRevenue - totalWithdrawn;
      if (calculatedBalance < 0) calculatedBalance = 0;

      // อัพเดทยอดเงินใน Firestore ใหม่
      String newWalletValue = calculatedBalance.toStringAsFixed(0);
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'wallet': newWalletValue});

      // อัพเดท SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(newWalletValue);

      // อัพเดทค่าในหน่วยความจำ
      wallet = newWalletValue;
      totalEarnings = calculatedBalance;

      // แจ้งผู้ใช้ถ้ามีการเปลี่ยนแปลงยอด
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ยอดเงินของคุณได้รับการอัพเดท'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error recalculating earnings: $e");
    }
  }

  Future<void> _calculateTotalEarnings() async {
    try {
      if (_currentUser == null) return;

      // ดึงข้อมูลผู้ใช้ - เพื่อเช็คยอดเงินที่บันทึกไว้
      final userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();

      double currentBalance = 0;
      if (userDoc.exists) {
        Map<String, dynamic>? userData = userDoc.data();
        if (userData != null && userData.containsKey('wallet')) {
          String walletStr = userData['wallet'] ?? "0";
          currentBalance = double.tryParse(walletStr) ?? 0;
        }
      }

      // ดึงข้อมูลรายได้ทั้งหมดจากการจองทุกสถานะ
      double totalRevenue = 0;

      // ดึงข้อมูลการจองที่สถานะ 'completed'
      final completedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      // ดึงข้อมูลการจองที่สถานะ 'accepted' (งานที่กำลังดำเนินการ)
      final acceptedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      // คำนวณรายได้ทั้งหมด (ยอดรวม)
      for (var doc in completedSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('totalPrice')) {
          totalRevenue += (data['totalPrice'] as num).toDouble();
        }
      }

      for (var doc in acceptedSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('totalPrice')) {
          totalRevenue += (data['totalPrice'] as num).toDouble();
        }
      }

      // ใช้ยอดเงินจาก Firestore (เป็นยอดที่หักการถอนแล้ว)
      // แต่ตรวจสอบว่าไม่น้อยกว่ายอดรวมทั้งหมด
      double finalBalance = currentBalance;

      // ถ้าไม่เคยมีการถอนเงิน ใช้ยอด totalRevenue
      if (finalBalance == 0 && totalRevenue > 0) {
        finalBalance = totalRevenue;
      }

      setState(() {
        totalEarnings = finalBalance;
      });
    } catch (e) {
      print("Error calculating total earnings: $e");
    }
  }

  Future<void> _loadPendingPayments() async {
    if (_currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('paymentStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> payments = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> booking = doc.data() as Map<String, dynamic>;

        // ดึงข้อมูลเจ้าของแมว
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(booking['userId']).get();

        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? 'Unknown User';

        payments.add({
          'id': doc.id,
          'amount': booking['totalPrice'],
          'userName': userName,
          'status': booking['status'],
          'date': booking['createdAt'],
        });
      }

      setState(() {
        pendingPayments = payments;
      });
    } catch (e) {
      print("Error loading pending payments: $e");
    }
  }

  Future<void> _loadCompletedJobs() async {
    if (_currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> jobs = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> booking = doc.data() as Map<String, dynamic>;

        // ดึงข้อมูลเจ้าของแมว
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(booking['userId']).get();

        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? 'Unknown User';

        jobs.add({
          'id': doc.id,
          'amount': booking['totalPrice'],
          'userName': userName,
          'paymentStatus': booking['paymentStatus'] ?? 'pending',
          'date': booking['completedAt'] ?? booking['createdAt'],
        });
      }

      setState(() {
        completedJobs = jobs;
      });
    } catch (e) {
      print("Error loading completed jobs: $e");
    }
  }

  Future<void> _withdrawMoney() async {
    if (_currentUser == null) return;

    // เรียกฟังก์ชันคำนวณรายได้ใหม่ก่อนถอนเงิน
    await _calculateTotalEarnings();

    if (!mounted) return;

    // แสดงหน้าต่างให้ใส่จำนวนเงินที่ต้องการถอน
    TextEditingController amountController = TextEditingController();

    // ตั้งค่าเริ่มต้นให้เป็นยอดรายได้ทั้งหมด
    amountController.text = totalEarnings.toStringAsFixed(0);

    // ใช้ showDialog แบบปลอดภัยมากขึ้น
    await showDialog(
      context: context,
      barrierDismissible: false, // ป้องกันการปิดโดยคลิกด้านนอก
      builder: (dialogContext) {
        // ใช้ dialogContext แทน context
        return AlertDialog(
          title: const Text('ถอนเงิน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงินที่ต้องการถอน',
                  hintText: 'ยืนยันจำนวนเงินที่ต้องการถอน',
                  prefixText: '฿ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // ปิด dialog โดยไม่ทำอะไรต่อ
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () {
                // ตรวจสอบความถูกต้องของข้อมูล
                final amount = int.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text('กรุณากรอกจำนวนเงินที่ถูกต้อง')),
                  );
                  return;
                }

                if (amount > totalEarnings) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('ยอดเงินไม่เพียงพอ')),
                  );
                  return;
                }

                // ปิด dialog และดำเนินการถอนเงิน
                Navigator.of(dialogContext).pop();

                // เรียกใช้ฟังก์ชันถอนเงินภายนอก dialog
                _confirmWithdrawal(amount);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );
  }

// แก้ไขฟังก์ชัน _confirmWithdrawal ที่มีอยู่แล้ว
  Future<void> _confirmWithdrawal(int amount) async {
    // เพิ่ม dialog เพื่อยืนยันรหัสผ่าน
    final TextEditingController passwordController = TextEditingController();
    final passwordFormKey = GlobalKey<FormState>();

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ยืนยันการถอนเงิน'),
          content: Form(
            key: passwordFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('กรุณากรอกรหัสผ่านเพื่อยืนยันการถอนเงิน ฿$amount'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'รหัสผ่าน',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกรหัสผ่าน';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordFormKey.currentState!.validate()) {
                  // ปิด dialog และส่งค่า true กลับไป
                  Navigator.of(dialogContext).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('ยืนยัน'),
            ),
          ],
        );
      },
    );

    // ถ้าผู้ใช้กดยกเลิกหรือปิด dialog ให้ยกเลิกการถอนเงิน
    if (confirmed != true) {
      return;
    }

    // ตรวจสอบรหัสผ่าน (ใช้ Firebase Authentication)
    try {
      setState(() => isLoading = true);

      // ตรวจสอบรหัสผ่านกับ Firebase Auth
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        try {
          // สร้าง credential สำหรับตรวจสอบรหัสผ่าน
          AuthCredential credential = EmailAuthProvider.credential(
            email: user.email!,
            password: passwordController.text,
          );

          // ตรวจสอบรหัสผ่าน
          await user.reauthenticateWithCredential(credential);

          // รหัสผ่านถูกต้อง ดำเนินการถอนเงิน
          await _processWithdrawalAfterVerification(amount);
        } on FirebaseAuthException catch (e) {
          // รหัสผ่านไม่ถูกต้อง
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        // กรณีที่ไม่มีผู้ใช้ที่ล็อกอินอยู่
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } catch (e) {
      print("Error in password verification: $e");
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการตรวจสอบรหัสผ่าน: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // เพิ่มฟังก์ชันนี้หลังจากฟังก์ชัน _confirmWithdrawal
  Future<void> _processWithdrawalAfterVerification(int amount) async {
    try {
      // คำนวณยอดเงินใหม่หลังจากถอน
      double newEarnings = totalEarnings - amount;
      if (newEarnings < 0) newEarnings = 0; // ป้องกันยอดติดลบ

      wallet = newEarnings.toStringAsFixed(0);

      // อัพเดต Firestore
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'wallet': wallet});
      } catch (e) {
        print("Error updating Firestore wallet: $e");
      }

      // อัพเดต SharedPreferences
      try {
        await SharedPreferenceHelper().saveUserWallet(wallet!);
      } catch (e) {
        print("Error saving to SharedPreferences: $e");
      }

      // บันทึกประวัติการทำธุรกรรม
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('transactions')
            .add({
          'amount': amount,
          'type': 'withdraw',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
          'description': 'ถอนเงินไปยังบัญชีธนาคาร',
        });
      } catch (e) {
        print("Error adding transaction: $e");
      }

      // อัพเดต state
      if (mounted) {
        setState(() {
          totalEarnings = newEarnings;
          isLoading = false;
        });

        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ถอนเงินจำนวน ฿$amount สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );

        // รีโหลดข้อมูล
        _loadTransactions();
      }
    } catch (e) {
      print("Error in withdrawal process: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการถอนเงิน: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processWithdrawal(int amount) async {
    if (_currentUser == null) return;

    setState(() => isLoading = true);

    try {
      // ดึงข้อมูลยอดเงินปัจจุบัน
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (!userDoc.exists) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      double currentBalance = double.tryParse(userData['wallet'] ?? "0") ?? 0;

      // ตรวจสอบว่ามียอดเงินเพียงพอหรือไม่
      if (currentBalance < amount) {
        throw Exception('ยอดเงินไม่เพียงพอสำหรับการถอน');
      }

      // คำนวณยอดเงินใหม่หลังจากถอน
      double newBalance = currentBalance - amount;
      wallet = newBalance.toStringAsFixed(0);

      // อัพเดต SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(wallet!);

      // อัพเดต Firestore ภายใน try-catch
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'wallet': wallet});
      } catch (e) {
        print("Error updating Firestore: $e");
      }

      // บันทึกประวัติการทำธุรกรรม
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .add({
        'amount': amount,
        'type': 'withdraw',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'description': 'ถอนเงินไปยังบัญชีธนาคาร',
      });

      // อัพเดตค่า totalEarnings ในหน้าจอ
      if (mounted) {
        setState(() {
          totalEarnings = newBalance;
        });
      }

      // โหลดข้อมูลธุรกรรมใหม่
      _loadTransactions();

      // แสดงข้อความสำเร็จ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ถอนเงินจำนวน ฿$amount สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error processing withdrawal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _handleWithdrawal(int amount) async {
    if (_currentUser == null) return;

    setState(() => isLoading = true);

    try {
      // โค้ดอื่นๆ คงเดิม

      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal request for ฿$amount submitted'),
          backgroundColor: Colors.green,
        ),
      );

      // ตรวจสอบว่า context ยังใช้ได้อยู่หรือไม่
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("Error processing withdrawal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: const Text(
          'รายได้ของคุณ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _calculateTotalEarnings(); // ตรวจสอบว่ามีการเรียกใช้ฟังก์ชันนี้
                await _loadTransactions();
                await _loadPendingPayments();
                await _loadCompletedJobs();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEarningsCard(),
                    const SizedBox(height: 20),
                    _buildEarningsSummary(), // เพิ่มส่วนนี้
                    const SizedBox(height: 20),
                    if (pendingPayments.isNotEmpty)
                      _buildPendingPaymentsSection(),
                    if (pendingPayments.isNotEmpty) const SizedBox(height: 20),
                    if (completedJobs.isNotEmpty) _buildCompletedJobsSection(),
                    if (completedJobs.isNotEmpty) const SizedBox(height: 20),
                    _buildTransactionHistorySection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _withdrawMoney,
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text('ถอนเงิน'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  // เพิ่มใน Widget _buildEarningsCard()
  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.teal, Colors.tealAccent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'รายได้จากการรับเลี้ยงแมว',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  // เพิ่มปุ่มรีเซ็ต
                  if (totalEarnings < 0) // แสดงเฉพาะเมื่อยอดติดลบ
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        // แสดงกล่องยืนยันก่อนรีเซ็ต
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('รีเซ็ตการคำนวณ'),
                            content: Text(
                                'คุณต้องการรีเซ็ตการคำนวณรายได้ใช่หรือไม่?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('ยกเลิก'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _resetAndRecalculateEarnings();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text('รีเซ็ต'),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'รีเซ็ตการคำนวณรายได้',
                    ),
                  Icon(
                    Icons.payments,
                    color: Colors.white,
                    size: 40,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '฿${totalEarnings.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'สามารถถอนเงินได้ทั้งหมด',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEarningsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สรุปข้อมูลการจอง',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEarningsStat(
                'รอยืนยัน',
                '${pendingPayments.length}',
                Icons.pending_actions,
                Colors.orange,
              ),
              _buildEarningsStat(
                'ยอมรับแล้ว',
                '${completedJobs.length}',
                Icons.check_circle,
                Colors.green,
              ),
              _buildEarningsStat(
                'รายได้',
                '${totalEarnings.toStringAsFixed(0)} ฿',
                Icons.attach_money,
                Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingPaymentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingPayments.length,
            itemBuilder: (context, index) {
              final payment = pendingPayments[index];
              final timestamp = payment['date'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final formattedDate = '${date.day}/${date.month}/${date.year}';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    child: const Icon(
                      Icons.pending_actions,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(
                    'Booking from ${payment['userName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      Text('Status: ${payment['status']} • $formattedDate'),
                  trailing: Text(
                    '฿${payment['amount']}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedJobsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Jobs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedJobs.length,
            itemBuilder: (context, index) {
              final job = completedJobs[index];
              final timestamp = job['date'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              final formattedDate = '${date.day}/${date.month}/${date.year}';
              final isPaid = job['paymentStatus'] == 'completed';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPaid
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    child: Icon(
                      isPaid ? Icons.check_circle : Icons.access_time,
                      color: isPaid ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    'Job for ${job['userName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      '${isPaid ? 'Paid' : 'Payment pending'} • $formattedDate'),
                  trailing: Text(
                    '฿${job['amount']}',
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _withdrawMoney,
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text('ถอนเงิน'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _refreshWalletData,
          icon: const Icon(Icons.refresh),
          label: const Text('รีเฟรชข้อมูล'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
        ),
      ],
    );
  }

// เพิ่มฟังก์ชันนี้
  Future<void> _refreshWalletData() async {
    try {
      setState(() => isLoading = true);

      if (_currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนดำเนินการ')));
        return;
      }

      // ตรวจสอบการเชื่อมต่อกับ Firestore
      bool hasConnection = await _checkFirestoreConnection();
      if (!hasConnection) {
        throw Exception("ไม่สามารถเชื่อมต่อกับ Firestore ได้");
      }

      // คำนวณรายได้ทั้งหมดจากงานที่เสร็จสิ้น
      double totalCompletedRevenue = 0;
      final completedSnapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in completedSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('totalPrice')) {
          totalCompletedRevenue += (data['totalPrice'] as num).toDouble();
        }
      }

      // คำนวณยอดถอนเงินทั้งหมด
      double totalWithdrawn = 0;
      final withdrawals = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'withdraw')
          .where('status', isEqualTo: 'completed')
          .get();

      for (var doc in withdrawals.docs) {
        final data = doc.data();
        if (data.containsKey('amount')) {
          totalWithdrawn += (data['amount'] as num).toDouble();
        }
      }

      // คำนวณยอดเงินคงเหลือที่ถูกต้อง
      double calculatedBalance = totalCompletedRevenue - totalWithdrawn;
      if (calculatedBalance < 0) calculatedBalance = 0;

      // อัพเดทยอดเงินใน Firestore
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'wallet': calculatedBalance.toStringAsFixed(0)});

      // อัพเดท SharedPreferences
      await SharedPreferenceHelper()
          .saveUserWallet(calculatedBalance.toStringAsFixed(0));

      // โหลดข้อมูลใหม่
      await _loadUserData();
      await _loadTransactions();
      await _loadPendingPayments();
      await _loadCompletedJobs();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'อัพเดทข้อมูลรายได้เรียบร้อยแล้ว: ฿${calculatedBalance.toStringAsFixed(0)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error refreshing wallet data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการรีเฟรชข้อมูล: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTransactionHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ประวัติรายรับ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          transactions.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'ไม่มีประวัติรายรับ',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isWithdraw = transaction['type'] == 'withdraw';
                    final isIncome = transaction['type'] == 'income';
                    final timestamp = transaction['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();
                    final formattedDate =
                        '${date.day}/${date.month}/${date.year}';

                    Color iconColor;
                    IconData iconData;

                    if (isWithdraw) {
                      iconColor = Colors.red;
                      iconData = Icons.account_balance_wallet;
                    } else if (isIncome) {
                      iconColor = Colors.green;
                      iconData = Icons.attach_money;
                    } else {
                      iconColor = Colors.blue;
                      iconData = Icons.swap_horiz;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.2),
                          child: Icon(
                            iconData,
                            color: iconColor,
                          ),
                        ),
                        title: Text(
                          transaction['description'] ??
                              (isWithdraw
                                  ? 'Withdrawal'
                                  : (isIncome
                                      ? 'Payment received'
                                      : 'Transaction')),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${transaction['status'] ?? 'completed'} • $formattedDate'),
                        trailing: Text(
                          '${isWithdraw ? '-' : '+'}฿${transaction['amount']}',
                          style: TextStyle(
                            color: isWithdraw ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
