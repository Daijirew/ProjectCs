import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceFeeUtils {
  // ค่าเริ่มต้น
  static const double DEFAULT_PLATFORM_FEE = 10.0; // ค่าธรรมเนียมแพลตฟอร์ม (%)
  static const double DEFAULT_MIN_SERVICE_RATE = 100.0; // ค่าบริการขั้นต่ำ (บาท)
  static const double DEFAULT_MAX_SERVICE_RATE = 1000.0; // ค่าบริการสูงสุด (บาท)
  static const double DEFAULT_SERVICE_RATE = 300.0; // ค่าบริการเริ่มต้น (บาท)
  static const double DEFAULT_TAX_RATE = 7.0; // อัตราภาษี (%)
  
  // สำหรับเก็บแคชข้อมูล
  static Map<String, dynamic>? _cachedFees;
  static DateTime? _lastFetchTime;
  
  // ตรวจสอบว่าจำเป็นต้องดึงข้อมูลใหม่หรือไม่ (แคชหมดอายุหลัง 1 ชั่วโมง)
  static bool _shouldRefresh() {
    if (_cachedFees == null || _lastFetchTime == null) {
      return true;
    }
    
    final Duration diff = DateTime.now().difference(_lastFetchTime!);
    return diff.inMinutes > 60; // แคชหมดอายุหลัง 1 ชั่วโมง
  }
  
  // ดึงข้อมูลค่าบริการทั้งหมด
  static Future<Map<String, dynamic>> getServiceFees() async {
    if (!_shouldRefresh() && _cachedFees != null) {
      return _cachedFees!;
    }
    
    try {
      DocumentSnapshot feeDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('serviceFees')
          .get();
      
      if (feeDoc.exists) {
        Map<String, dynamic> data = feeDoc.data() as Map<String, dynamic>;
        _cachedFees = data;
        _lastFetchTime = DateTime.now();
        return data;
      } else {
        // ถ้าไม่มีข้อมูล ใช้ค่าเริ่มต้น
        return {
          'platformFee': DEFAULT_PLATFORM_FEE,
          'minServiceRate': DEFAULT_MIN_SERVICE_RATE,
          'maxServiceRate': DEFAULT_MAX_SERVICE_RATE,
          'defaultServiceRate': DEFAULT_SERVICE_RATE,
          'taxRate': DEFAULT_TAX_RATE,
        };
      }
    } catch (e) {
      print('Error fetching service fees: $e');
      // กรณีเกิดข้อผิดพลาด ใช้ค่าเริ่มต้น
      return {
        'platformFee': DEFAULT_PLATFORM_FEE,
        'minServiceRate': DEFAULT_MIN_SERVICE_RATE,
        'maxServiceRate': DEFAULT_MAX_SERVICE_RATE,
        'defaultServiceRate': DEFAULT_SERVICE_RATE,
        'taxRate': DEFAULT_TAX_RATE,
      };
    }
  }
  
  // ดึงค่าธรรมเนียมแพลตฟอร์ม
  static Future<double> getPlatformFee() async {
    Map<String, dynamic> fees = await getServiceFees();
    return fees['platformFee'] ?? DEFAULT_PLATFORM_FEE;
  }
  
  // ดึงค่าบริการขั้นต่ำ
  static Future<double> getMinServiceRate() async {
    Map<String, dynamic> fees = await getServiceFees();
    return fees['minServiceRate'] ?? DEFAULT_MIN_SERVICE_RATE;
  }
  
  // ดึงค่าบริการสูงสุด
  static Future<double> getMaxServiceRate() async {
    Map<String, dynamic> fees = await getServiceFees();
    return fees['maxServiceRate'] ?? DEFAULT_MAX_SERVICE_RATE;
  }
  
  // ดึงค่าบริการเริ่มต้น
  static Future<double> getDefaultServiceRate() async {
    Map<String, dynamic> fees = await getServiceFees();
    return fees['defaultServiceRate'] ?? DEFAULT_SERVICE_RATE;
  }
  
  // ดึงอัตราภาษี
  static Future<double> getTaxRate() async {
    Map<String, dynamic> fees = await getServiceFees();
    return fees['taxRate'] ?? DEFAULT_TAX_RATE;
  }
  
  // คำนวณราคารวมทั้งหมด
  static Future<double> calculateTotalPrice(double basePrice) async {
    double platformFee = await getPlatformFee();
    double taxRate = await getTaxRate();
    
    double platformFeeAmount = basePrice * (platformFee / 100);
    double subtotal = basePrice + platformFeeAmount;
    double taxAmount = subtotal * (taxRate / 100);
    
    return subtotal + taxAmount;
  }
}