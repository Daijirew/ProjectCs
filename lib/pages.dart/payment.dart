import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:myproject/widget/app_constant.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:myproject/services/database.dart';
import 'package:http/http.dart' as http;

class Payment extends StatefulWidget {
  const Payment({super.key});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  String? wallet, id;
  int? add;
  TextEditingController amountController = TextEditingController();
  bool _isLoading = false;

  // รายการจำนวนเงินที่แนะนำ
  final List<String> _suggestedAmounts = ["50", "100", "200", "500"];

  // ดึงข้อมูล shared preferences
  getthesharedpref() async {
    try {
      wallet = await SharedPreferenceHelper().getUserWallet();
      // ถ้าค่า wallet เป็น null หรือค่าว่าง ให้กำหนดเป็น "0"
      if (wallet == null || wallet!.isEmpty) {
        wallet = "0";
        // บันทึกค่าเริ่มต้นลงใน SharedPreferences
        await SharedPreferenceHelper().saveUserWallet("0");
      }
      id = await SharedPreferenceHelper().getUserId();
      setState(() {});
    } catch (e) {
      // จัดการกับข้อผิดพลาด
      print('Error getting shared preferences: $e');
      // กำหนดค่าเริ่มต้นในกรณีที่เกิดข้อผิดพลาด
      wallet = "0";
      setState(() {});
    }
  }

  ontheload() async {
    await getthesharedpref();
    setState(() {});
  }

  @override
  void initState() {
    ontheload();
    super.initState();
  }

  Map<String, dynamic>? paymentIntent;

  // สร้าง Payment Intent สำหรับ Stripe
  Future<Map<String, dynamic>> createPaymentIntent(
      String amount, String currency) async {
    try {
      // แปลงจำนวนเงินเป็นรูปแบบที่ Stripe ต้องการ (สตางค์)
      final calculatedAmount = (int.parse(amount) * 100).toString();

      // สร้าง body สำหรับ request
      Map<String, dynamic> body = {
        'amount': calculatedAmount,
        'currency': currency,
        'payment_method_types[]': 'card'
      };

      // ส่ง request ไปยัง Stripe API
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body,
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error creating payment intent: $e');
      throw Exception(e.toString());
    }
  }

  // แสดงหน้าจอชำระเงินของ Stripe
  Future<bool> displayPaymentSheet(String amount) async {
    try {
      setState(() => _isLoading = true);

      // สร้าง payment intent
      paymentIntent = await createPaymentIntent(amount, 'THB');

      // ตรวจสอบข้อผิดพลาดจาก payment intent
      if (paymentIntent != null && paymentIntent!.containsKey('error')) {
        throw Exception(paymentIntent!['error']['message']);
      }

      // ตั้งค่า payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent!['client_secret'],
          style: ThemeMode.dark,
          merchantDisplayName: 'แอปรับฝากเลี้ยงแมว',
          allowsDelayedPaymentMethods: true,
        ),
      );

      // แสดง payment sheet
      await Stripe.instance.presentPaymentSheet();

      // อัพเดท wallet หลังจากชำระเงินสำเร็จ
      add = int.parse(wallet!) + int.parse(amount);
      await SharedPreferenceHelper().saveUserWallet(add.toString());

      // แสดงข้อความสำเร็จ
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ชำระเงินสำเร็จ เติมเงิน ฿$amount ในกระเป๋าเงิน'),
        backgroundColor: Colors.orange,
      ));

      // อัพเดทค่า wallet ในหน้าจอ
      await getthesharedpref();

      return true;
    } catch (e) {
      // จัดการข้อผิดพลาด
      if (e is StripeException) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('การชำระเงินถูกยกเลิก'),
          backgroundColor: Colors.red,
        ));
      } else {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ฟังก์ชันเติมเงิน
  Future<void> addMoney(String amount) async {
    // ตรวจสอบว่าจำนวนเงินถูกต้อง
    if (amount.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('กรุณาระบุจำนวนเงิน')));
      return;
    }

    try {
      int.parse(amount);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('กรุณาระบุจำนวนเงินที่ถูกต้อง')));
      return;
    }

    // แสดงหน้าจอชำระเงิน
    bool success = await displayPaymentSheet(amount);

    // บันทึกประวัติการเติมเงิน
    if (success && id != null) {
      try {
        await FirebaseFirestore.instance.collection('payment_history').add({
          'userId': id,
          'amount': int.parse(amount),
          'type': 'topup',
          'method': 'stripe',
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error saving payment history: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: wallet == null
          ? Center(child: CircularProgressIndicator())
          : Container(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนหัว
                    Container(
                      padding: EdgeInsets.only(
                          top: 50, left: 20, right: 20, bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: Text(
                              "กระเป๋าเงิน",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "ยอดเงินคงเหลือ",
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "฿${wallet!}",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ส่วนเติมเงิน
                    Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "เติมเงิน",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "เลือกจำนวนเงินที่ต้องการเติม",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 20),

                          // จำนวนเงินที่แนะนำ
                          GridView.count(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 2.0,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: _suggestedAmounts.map((amount) {
                              return GestureDetector(
                                onTap:
                                    _isLoading ? null : () => addMoney(amount),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 5,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      "฿$amount",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          SizedBox(height: 20),

                          // ช่องกรอกจำนวนเงินเอง
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'ระบุจำนวนเงิน',
                                prefixIcon: Icon(Icons.monetization_on,
                                    color: Colors.orange),
                                suffixText: 'THB',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // ปุ่มเติมเงิน
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      addMoney(amountController.text.trim());
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ))
                                  : Text(
                                      "เติมเงิน",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // คำอธิบาย
                          Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "วิธีการเติมเงิน",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "1. เลือกหรือระบุจำนวนเงินที่ต้องการเติม\n"
                                  "2. กดปุ่ม 'เติมเงิน' เพื่อดำเนินการ\n"
                                  "3. กรอกข้อมูลบัตรเครดิต/เดบิตของคุณ\n"
                                  "4. ยืนยันการชำระเงิน",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
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
  }
}
