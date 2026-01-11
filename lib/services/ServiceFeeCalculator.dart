import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceFeeCalculator {
  // ค่าบริการเริ่มต้น (กรณีไม่สามารถดึงข้อมูลจาก Firestore ได้)
  static final Map<String, double> _defaultFees = {
    'baseFee': 100.0,
    'commissionRate': 10.0,
    'extraCatFee': 50.0,
    'taxRate': 7.0,
    'cancellationFee': 50.0,
  };

  // ค่าบริการที่ใช้คำนวณจริง
  static Map<String, double> _currentFees = Map.from(_defaultFees);
  static bool _feesLoaded = false;
  static DateTime _lastFetchTime = DateTime(2000); // เริ่มต้นด้วยเวลาในอดีต

  // ดึงค่าบริการล่าสุดจาก Firestore
  static Future<Map<String, double>> getServiceFees() async {
    // ตรวจสอบว่าข้อมูลล่าสุดถูกโหลดไปแล้วหรือไม่ และเวลาผ่านไปไม่เกิน 5 นาที
    DateTime now = DateTime.now();
    if (_feesLoaded && now.difference(_lastFetchTime).inMinutes < 5) {
      return _currentFees;
    }

    try {
      // ตรวจสอบเวลาอัพเดทล่าสุดของค่าบริการ
      bool needRefresh = false;
      try {
        DocumentSnapshot cacheDoc = await FirebaseFirestore.instance
            .collection('system')
            .doc('cache')
            .get();

        if (cacheDoc.exists) {
          Timestamp? lastUpdated = cacheDoc.get('serviceFeeLastUpdated');
          if (lastUpdated != null) {
            DateTime lastUpdateTime = lastUpdated.toDate();
            if (lastUpdateTime.isAfter(_lastFetchTime)) {
              needRefresh = true;
            }
          }
        }
      } catch (e) {
        print('Error checking cache: $e');
        // ถ้าเช็คไม่ได้ จะทำการดึงข้อมูลใหม่
        needRefresh = true;
      }

      // ถ้าจำเป็นต้องรีเฟรชข้อมูล หรือยังไม่เคยโหลดข้อมูล
      if (needRefresh || !_feesLoaded) {
        // ลองดึงจาก admin/service_fees ก่อน
        DocumentSnapshot feeDoc = await FirebaseFirestore.instance
            .collection('admin')
            .doc('service_fees')
            .get();

        if (feeDoc.exists) {
          await _processServiceFeeDocument(feeDoc);
          return _currentFees;
        }

        // ถ้าไม่พบ ลองดึงจาก service_fees/default
        feeDoc = await FirebaseFirestore.instance
            .collection('service_fees')
            .doc('default')
            .get();

        if (feeDoc.exists) {
          await _processServiceFeeDocument(feeDoc);
          return _currentFees;
        }
      }
    } catch (e) {
      print('Error loading service fees: $e');
    }

    // ถ้าไม่สามารถดึงข้อมูลได้ ใช้ค่าเริ่มต้น
    return _currentFees;
  }

  // แปลงข้อมูล document เป็น Map
  static Future<void> _processServiceFeeDocument(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Map<String, double> newFees = {};

    // แปลงข้อมูลเป็น double
    data.forEach((key, value) {
      if (value is num) {
        newFees[key] = value.toDouble();
      } else if (value is String) {
        double? parsedValue = double.tryParse(value);
        if (parsedValue != null) {
          newFees[key] = parsedValue;
        }
      }
    });

    // ตรวจสอบว่ามีข้อมูลที่จำเป็นทั้งหมดหรือไม่
    _defaultFees.forEach((key, defaultValue) {
      if (!newFees.containsKey(key)) {
        newFees[key] = defaultValue;
      }
    });

    // อัพเดทค่าบริการปัจจุบัน
    _currentFees = newFees;
    _feesLoaded = true;
    _lastFetchTime = DateTime.now();
  }

  // คำนวณค่าบริการพื้นฐาน
  static Future<double> calculateBaseFee(
      int numberOfDays, int numberOfCats) async {
    Map<String, double> fees = await getServiceFees();

    double baseFee = fees['baseFee'] ?? _defaultFees['baseFee']!;
    double extraCatFee = fees['extraCatFee'] ?? _defaultFees['extraCatFee']!;

    // คำนวณค่าบริการ = ค่าบริการพื้นฐาน * จำนวนวัน + (ค่าธรรมเนียมแมวเพิ่ม * (จำนวนแมว - 1))
    double totalBaseFee = baseFee * numberOfDays;
    if (numberOfCats > 1) {
      totalBaseFee += extraCatFee * (numberOfCats - 1) * numberOfDays;
    }

    return totalBaseFee;
  }

  // คำนวณค่าคอมมิชชั่น
  static Future<double> calculateCommission(double baseAmount) async {
    Map<String, double> fees = await getServiceFees();

    double commissionRate =
        fees['commissionRate'] ?? _defaultFees['commissionRate']!;

    return baseAmount * (commissionRate / 100);
  }

  // คำนวณภาษีมูลค่าเพิ่ม
  static Future<double> calculateTax(double amount) async {
    Map<String, double> fees = await getServiceFees();

    double taxRate = fees['taxRate'] ?? _defaultFees['taxRate']!;

    return amount * (taxRate / 100);
  }

  // คำนวณค่าบริการทั้งหมด
  static Future<Map<String, double>> calculateTotalFee(
      int numberOfDays, int numberOfCats) async {
    // คำนวณค่าบริการพื้นฐาน
    double baseFee = await calculateBaseFee(numberOfDays, numberOfCats);

    // คำนวณค่าคอมมิชชั่น
    double commission = await calculateCommission(baseFee);

    // คำนวณภาษีมูลค่าเพิ่ม
    double subtotal = baseFee + commission;
    double tax = await calculateTax(subtotal);

    // คำนวณค่าบริการทั้งหมด
    double total = subtotal + tax;

    // สร้างข้อมูลการคำนวณทั้งหมด
    return {
      'baseFee': baseFee,
      'commission': commission,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
    };
  }

  // คำนวณค่าธรรมเนียมการยกเลิก
  static Future<double> getCancellationFee() async {
    Map<String, double> fees = await getServiceFees();

    return fees['cancellationFee'] ?? _defaultFees['cancellationFee']!;
  }

  // รีเซ็ตแคชค่าบริการ (เรียกเมื่อต้องการดึงข้อมูลล่าสุดจาก Firestore)
  static void resetCache() {
    _feesLoaded = false;
  }
}
