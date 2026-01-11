import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:myproject/services/shared_pref.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myproject/widget/widget_support.dart';
import 'package:fl_chart/fl_chart.dart';

class ScheduleIncomePage extends StatefulWidget {
  const ScheduleIncomePage({Key? key}) : super(key: key);

  @override
  State<ScheduleIncomePage> createState() => _ScheduleIncomePageState();
}

class _ScheduleIncomePageState extends State<ScheduleIncomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ปฏิทิน
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // ข้อมูลการจอง
  Map<DateTime, List<dynamic>> _bookingEvents = {};
  // ข้อมูลเกี่ยวกับรายได้
  double _totalIncome = 0;
  double _monthlyIncome = 0;
  double _weeklyIncome = 0;
  bool _isLoading = true;

  // ข้อมูลสำหรับกราฟ
  List<FlSpot> _incomeChartData = [];
  double _maxY = 1000; // ค่าเริ่มต้นสำหรับแกน Y

  // รายการการจองตามวันที่เลือก
  List<dynamic> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _loadBookingEvents();
    _loadIncomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // โหลดข้อมูลการจอง
  Future<void> _loadBookingEvents() async {
    setState(() => _isLoading = true);

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ดึงข้อมูลการจองที่ได้รับการยอมรับแล้ว
      final QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final Map<DateTime, List<dynamic>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> dates = data['dates'] ?? [];

        for (var dateData in dates) {
          final DateTime date = (dateData as Timestamp).toDate();
          final DateTime dateKey = DateTime(date.year, date.month, date.day);

          if (events[dateKey] != null) {
            events[dateKey]!.add(data);
          } else {
            events[dateKey] = [data];
          }
        }
      }

      setState(() {
        _bookingEvents = events;
        _selectedEvents = _getEventsForDay(_selectedDay!);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading booking events: $e');
      setState(() => _isLoading = false);
    }
  }

  // โหลดข้อมูลรายได้
  Future<void> _loadIncomeData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      // ดึงข้อมูลการจองที่ยอมรับแล้ว
      final QuerySnapshot snapshot = await _firestore
          .collection('bookings')
          .where('sitterId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      double total = 0;
      double monthly = 0;
      double weekly = 0;

      // ข้อมูลรายได้ตามเดือน สำหรับกราฟ
      Map<int, double> monthlyData = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['totalPrice'] ?? 0).toDouble();
        final createdAt = data['createdAt'] as Timestamp?;

        if (createdAt != null) {
          final date = createdAt.toDate();

          // รายได้ทั้งหมด
          total += price;

          // รายได้รายเดือน
          if (date.isAfter(startOfMonth) ||
              date.isAtSameMomentAs(startOfMonth)) {
            monthly += price;
          }

          // รายได้รายสัปดาห์
          if (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek)) {
            weekly += price;
          }

          // รวบรวมข้อมูลสำหรับกราฟ
          final int monthKey = date.month;
          if (monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = monthlyData[monthKey]! + price;
          } else {
            monthlyData[monthKey] = price;
          }
        }
      }

      // สร้างข้อมูลสำหรับกราฟ
      List<FlSpot> chartData = [];
      double maxIncome = 0;

      monthlyData.forEach((month, income) {
        chartData.add(FlSpot(month.toDouble(), income));
        if (income > maxIncome) maxIncome = income;
      });

      // เรียงลำดับตามเดือน
      chartData.sort((a, b) => a.x.compareTo(b.x));

      setState(() {
        _totalIncome = total;
        _monthlyIncome = monthly;
        _weeklyIncome = weekly;
        _incomeChartData = chartData;
        _maxY = maxIncome > 0
            ? maxIncome * 1.2
            : 1000; // เพิ่มพื้นที่ด้านบนของกราฟ 20%
      });
    } catch (e) {
      print('Error loading income data: $e');
    }
  }

  Future<void> _completeBooking(String bookingId) async {
    try {
      // ดึงข้อมูลการจองเพื่อเอายอดเงิน
      DocumentSnapshot bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('ไม่พบข้อมูลการจอง');
      }

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;
      double bookingAmount = 0;
      if (bookingData.containsKey('totalPrice')) {
        bookingAmount = (bookingData['totalPrice'] as num).toDouble();
      }

      // ดึงข้อมูล wallet ปัจจุบัน
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      // คำนวณยอดเงินใหม่
      double currentWallet = 0;
      if (userData != null && userData.containsKey('wallet')) {
        String walletStr = userData['wallet'] ?? "0";
        currentWallet = double.tryParse(walletStr) ?? 0;
      }

      double newWallet = currentWallet + bookingAmount;
      String walletStr = newWallet.toStringAsFixed(0);

      // อัพเดตสถานะงานและเพิ่มยอดเงินใน wallet พร้อมกัน
      await _firestore.runTransaction((transaction) async {
        // อัพเดตสถานะงาน
        transaction.update(_firestore.collection('bookings').doc(bookingId), {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });

        // อัพเดตยอดเงินใน wallet
        transaction
            .update(_firestore.collection('users').doc(currentUser.uid), {
          'wallet': walletStr,
        });
      });

      // บันทึกประวัติการทำธุรกรรม
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('transactions')
          .add({
        'amount': bookingAmount,
        'type': 'income',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'description': 'รายได้จากการรับเลี้ยงแมว',
        'bookingId': bookingId,
      });

      // อัพเดต SharedPreferences
      await SharedPreferenceHelper().saveUserWallet(walletStr);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('การดูแลเสร็จสิ้นเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error completing booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  // ดึงรายการการจองตามวันที่
  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _bookingEvents[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ตารางงานและรายได้',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'ตารางงาน'),
            Tab(text: 'รายได้'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleTab(),
          _buildIncomeTab(),
        ],
      ),
    );
  }

  // แท็บตารางงาน
  Widget _buildScheduleTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // ปฏิทิน
              TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedEvents = _getEventsForDay(selectedDay);
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'รายการการจองในวันที่เลือก',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _selectedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ไม่มีรายการในวันที่เลือก',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _selectedEvents.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final booking =
                              _selectedEvents[index] as Map<String, dynamic>;
                          return FutureBuilder<DocumentSnapshot>(
                            future: _firestore
                                .collection('users')
                                .doc(booking['userId'])
                                .get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Card(
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                );
                              }

                              final userData = snapshot.data!.data()
                                  as Map<String, dynamic>?;
                              final userName =
                                  userData?['name'] ?? 'ไม่ระบุชื่อ';
                              final userPhoto = userData?['photo'];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 3,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundImage: userPhoto != null &&
                                            userPhoto.isNotEmpty
                                        ? NetworkImage(userPhoto)
                                        : null,
                                    child:
                                        userPhoto == null || userPhoto.isEmpty
                                            ? const Icon(Icons.person)
                                            : null,
                                  ),
                                  title: Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.pets,
                                              size: 16,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(booking['catIds'] as List<dynamic>?)?.length ?? 0} ตัว',
                                            style: TextStyle(
                                                color: Colors.grey[700]),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.payments,
                                              size: 16,
                                              color: Colors.green[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${booking['totalPrice'] ?? 0} บาท',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios,
                                      size: 18),
                                  onTap: () {
                                    // แสดงรายละเอียดการจอง
                                    _showBookingDetailsDialog(booking);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
  }

  // แท็บรายได้
  Widget _buildIncomeTab() {
    final currencyFormat =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // สรุปรายได้
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายได้ทั้งหมด',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(_totalIncome),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // รายได้รายเดือนและรายสัปดาห์
            Row(
              children: [
                Expanded(
                  child: _buildIncomeCard(
                    'รายได้เดือนนี้',
                    _monthlyIncome,
                    Colors.blue,
                    Icons.calendar_month,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildIncomeCard(
                    'รายได้สัปดาห์นี้',
                    _weeklyIncome,
                    Colors.amber,
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // สถิติรายได้
            const Text(
              'สถิติรายได้รายเดือน',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _incomeChartData.isEmpty
                  ? _buildEmptyChartMessage()
                  : _buildIncomeChart(),
            ),
            const SizedBox(height: 24),

            // การวิเคราะห์รายได้
            _buildIncomeAnalysis(),
          ],
        ),
      ),
    );
  }

  // ข้อความเมื่อไม่มีข้อมูลกราฟ
  Widget _buildEmptyChartMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีข้อมูลรายได้',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ข้อมูลจะแสดงเมื่อคุณมีรายได้จากการรับเลี้ยงแมว',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // การ์ดแสดงรายได้
  Widget _buildIncomeCard(
      String title, double amount, Color color, IconData icon) {
    final currencyFormat =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // กราฟแสดงรายได้
  Widget _buildIncomeChart() {
    final List<String> months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                // Add type annotation for clarity
                if (value < 1 || value > 12 || value % 1 != 0) {
                  return const SizedBox();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    months[value.toInt() - 1],
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (double value, TitleMeta meta) {
                final currencyFormat = NumberFormat.compact(locale: 'th');
                return SideTitleWidget(
                  axisSide: meta.axisSide, // Changed from 'axisSide' to 'side'
                  child: Text(
                    currencyFormat.format(value),
                    style: const TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        minX: 1,
        maxX: 12,
        minY: 0,
        maxY: _maxY,
        lineBarsData: [
          LineChartBarData(
            spots: _incomeChartData,
            isCurved: true,
            color: Colors.teal,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.teal.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  // การวิเคราะห์รายได้
  Widget _buildIncomeAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics, color: Colors.purple.shade700),
              ),
              const SizedBox(width: 12),
              const Text(
                'การวิเคราะห์รายได้',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ข้อมูลการวิเคราะห์
          _buildAnalysisItem(
            'อัตรารายได้เฉลี่ยต่อการจอง',
            _getTotalBookings() > 0 ? _totalIncome / _getTotalBookings() : 0,
            Icons.attach_money,
            Colors.green,
            isAmount: true,
          ),
          const SizedBox(height: 12),
          _buildAnalysisItem(
            'จำนวนการจองทั้งหมด',
            _getTotalBookings().toDouble(),
            Icons.confirmation_number,
            Colors.blue,
            isAmount: false,
          ),
          _buildAnalysisItem(
            'จำนวนการจองทั้งหมด',
            _getTotalBookings().toDouble(),
            Icons.confirmation_number,
            Colors.blue,
            isAmount: false,
          ),
          const SizedBox(height: 12),
          _buildAnalysisItem(
            'จำนวนวันทำงานทั้งหมด',
            _getTotalWorkingDays().toDouble(),
            Icons.work,
            Colors.orange,
            isAmount: false,
          ),
        ],
      ),
    );
  }

  // รายการวิเคราะห์
  Widget _buildAnalysisItem(
      String title, double value, IconData icon, Color color,
      {required bool isAmount}) {
    final currencyFormat =
        NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          isAmount ? currencyFormat.format(value) : value.toInt().toString(),
          style: TextStyle(
            color: Colors.blue.shade700,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // นับจำนวนการจองทั้งหมด
  int _getTotalBookings() {
    final Set<String> uniqueBookings = {};

    _bookingEvents.forEach((date, events) {
      for (var event in events) {
        uniqueBookings.add(event['id'] ?? '');
      }
    });

    return uniqueBookings.length;
  }

  // นับจำนวนวันทำงานทั้งหมด
  int _getTotalWorkingDays() {
    return _bookingEvents.length;
  }

  // แสดงรายละเอียดการจอง
  void _showBookingDetailsDialog(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                controller: scrollController,
                child: FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('users')
                      .doc(booking['userId'])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>?;
                    final userName = userData?['name'] ?? 'ไม่ระบุชื่อ';
                    final userEmail = userData?['email'] ?? 'ไม่ระบุอีเมล';
                    final userPhone = userData?['phone'] ?? 'ไม่ระบุเบอร์โทร';

                    return Column(
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
                        const SizedBox(height: 16),

                        // ข้อมูลผู้ใช้
                        _buildDetailSection(
                          'ข้อมูลผู้ใช้',
                          Icons.person,
                          Colors.blue,
                          [
                            _buildDetailItem('ชื่อ', userName),
                            _buildDetailItem('อีเมล', userEmail),
                            _buildDetailItem('เบอร์โทร', userPhone),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ข้อมูลการจอง
                        _buildDetailSection(
                          'ข้อมูลการจอง',
                          Icons.calendar_today,
                          Colors.orange,
                          [
                            _buildDetailItem(
                              'วันที่จอง',
                              booking['createdAt'] != null
                                  ? DateFormat('dd MMM yyyy, HH:mm').format(
                                      (booking['createdAt'] as Timestamp)
                                          .toDate())
                                  : 'ไม่ระบุ',
                            ),
                            _buildDetailItem(
                              'จำนวนแมว',
                              '${(booking['catIds'] as List<dynamic>?)?.length ?? 0} ตัว',
                            ),
                            _buildDetailItem(
                              'ราคา',
                              '${booking['totalPrice'] ?? 0} บาท',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ข้อมูลแมว
                        _buildCatsSection(booking),
                        const SizedBox(height: 20),

                        // หมายเหตุ
                        if (booking['notes'] != null &&
                            booking['notes'].isNotEmpty)
                          _buildDetailSection(
                            'หมายเหตุ',
                            Icons.note,
                            Colors.purple,
                            [
                              _buildDetailItem('', booking['notes']),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // สร้างส่วนรายละเอียด
  Widget _buildDetailSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // สร้างรายการรายละเอียด
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ส่วนแสดงข้อมูลแมว
  Widget _buildCatsSection(Map<String, dynamic> booking) {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .doc(booking['userId'])
          .collection('cats')
          .where(FieldPath.documentId, whereIn: booking['catIds'] ?? [])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.pets, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ข้อมูลแมว',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('ไม่พบข้อมูลแมว'),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.pets, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ข้อมูลแมว',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final catData =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: catData['imagePath'] != null &&
                                    catData['imagePath'].isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(catData['imagePath']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: catData['imagePath'] == null ||
                                  catData['imagePath'].isEmpty
                              ? const Icon(Icons.pets, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                catData['name'] ?? 'ไม่ระบุชื่อ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'สายพันธุ์: ${catData['breed'] ?? 'ไม่ระบุ'}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'วัคซีน: ${catData['vaccinations'] ?? 'ไม่ระบุ'}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              if (catData['description'] != null &&
                                  catData['description'].isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'คำอธิบาย: ${catData['description']}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
