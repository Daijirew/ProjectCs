// lib/pages.dart/payment.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/app_constant.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Payment extends StatefulWidget {
  const Payment({super.key});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  String? wallet, id;
  bool isLoading = false;
  List<Map<String, dynamic>> transactions = [];
  TextEditingController amountController = TextEditingController();
  final List<int> quickAmounts = [50, 100, 150, 300];
  int? selectedAmount;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTransactions();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      // ดึงข้อมูลจาก SharedPreferences
      wallet = await SharedPreferenceHelper().getUserWallet();
      id = await SharedPreferenceHelper().getUserId();

      // ถ้าไม่มีข้อมูล Wallet ให้ดึงจาก Firestore
      if (wallet == null || wallet!.isEmpty) {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            Map<String, dynamic>? userData =
                userDoc.data() as Map<String, dynamic>?;
            wallet = userData?['wallet'] ?? "0";
            await SharedPreferenceHelper().saveUserWallet(wallet!);
          } else {
            wallet = "0";
            await SharedPreferenceHelper().saveUserWallet(wallet!);
          }
        } else {
          wallet = "0";
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
      wallet = "0";
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // ดึงข้อมูลการทำธุรกรรมจาก Firestore
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        setState(() {
          transactions = snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (e) {
      print("Error loading transactions: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _selectAmount(int amount) {
    setState(() {
      selectedAmount = amount;
      amountController.text = amount.toString();
    });
  }

  Future<void> _makePayment() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = int.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. สร้าง payment intent
      final paymentIntent =
          await _createPaymentIntent(amount.toString(), 'THB');

      // 2. เริ่ม payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Cat Sitter',
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.orange,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12.0,
              shadow: PaymentSheetShadowParams(color: Colors.black),
            ),
          ),
        ),
      );

      // 3. แสดง payment sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. เมื่อชำระเงินสำเร็จ
      _onPaymentSuccess(amount);
    } catch (e) {
      print("Payment error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _createPaymentIntent(
      String amount, String currency) async {
    final body = {
      'amount': _calculateAmount(amount),
      'currency': currency,
      'payment_method_types[]': 'card'
    };

    final response = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body,
    );

    return jsonDecode(response.body);
  }

  String _calculateAmount(String amount) {
    final calculatedAmount = (int.parse(amount)) * 100;
    return calculatedAmount.toString();
  }

  void _onPaymentSuccess(int amount) async {
    try {
      // 1. อัพเดทยอดเงินใน wallet
      final currentWallet = int.parse(wallet ?? "0");
      final newWallet = currentWallet + amount;
      wallet = newWallet.toString();

      // 2. อัพเดท SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(wallet!);

      // 3. อัพเดท Firestore
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'wallet': wallet});

        // 4. บันทึกประวัติการทำธุรกรรม
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .add({
          'amount': amount,
          'type': 'topup',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
          'description': 'Top up wallet',
        });

        // 5. โหลดข้อมูลธุรกรรมใหม่
        _loadTransactions();
      }

      // 6. รีเซ็ตค่า
      setState(() {
        amountController.clear();
        selectedAmount = null;
      });

      // 7. แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added ฿$amount to your wallet'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("Error updating wallet: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating wallet: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        title: const Text(
          'Wallet',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadTransactions();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWalletCard(),
                    const SizedBox(height: 20),
                    _buildQuickAddMoneySection(),
                    const SizedBox(height: 20),
                    _buildCustomAmountSection(),
                    const SizedBox(height: 20),
                    _buildTransactionHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
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
                'Your Balance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Image.asset(
                'images/wallet.png',
                height: 40,
                width: 40,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '฿${wallet ?? "0"}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddMoneySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Add Money',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: quickAmounts.length,
            itemBuilder: (context, index) {
              final amount = quickAmounts[index];
              final isSelected = selectedAmount == amount;

              return GestureDetector(
                onTap: () => _selectAmount(amount),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '฿$amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.orange : Colors.black,
                      ),
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

  Widget _buildCustomAmountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Amount',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: '฿ ',
              hintText: 'Enter amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _makePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Add Money',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction History',
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
                      'No transactions yet',
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
                    final isTopUp = transaction['type'] == 'topup';
                    final timestamp = transaction['timestamp'] as Timestamp?;
                    final date = timestamp?.toDate() ?? DateTime.now();
                    final formattedDate =
                        '${date.day}/${date.month}/${date.year}';

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
                          backgroundColor: isTopUp
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          child: Icon(
                            isTopUp ? Icons.add : Icons.remove,
                            color: isTopUp ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          transaction['description'] ??
                              (isTopUp ? 'Top up' : 'Payment'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(formattedDate),
                        trailing: Text(
                          '${isTopUp ? '+' : '-'}฿${transaction['amount']}',
                          style: TextStyle(
                            color: isTopUp ? Colors.green : Colors.red,
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
