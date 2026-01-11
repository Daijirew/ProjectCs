import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SitterIncomeReport extends StatefulWidget {
  const SitterIncomeReport({Key? key}) : super(key: key);

  @override
  _SitterIncomeReportState createState() => _SitterIncomeReportState();
}

class _SitterIncomeReportState extends State<SitterIncomeReport>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sitterIncomeList = [];
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  late TabController _tabController;

  // ข้อมูลสำหรับกราฟ
  List<Map<String, dynamic>> _monthlyIncomeData = [];
  List<Map<String, dynamic>> _bookingStatusData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSitterIncomeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSitterIncomeData() async {
    setState(() => _isLoading = true);

    try {
      // 1. ดึงข้อมูลการจองในช่วงเวลาที่กำหนด
      QuerySnapshot bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('status',
              whereIn: ['confirmed', 'in_progress', 'completed']).get();

      // 2. จัดกลุ่มข้อมูลตามพี่เลี้ยง
      Map<String, Map<String, dynamic>> sitterIncomeMap = {};

      // สร้างตัวแปรสำหรับเก็บข้อมูลสถานะการจอง
      Map<String, int> statusCount = {
        'pending': 0,
        'confirmed': 0,
        'in_progress': 0,
        'completed': 0,
        'cancelled': 0,
      };

      // สร้างตัวแปรสำหรับเก็บข้อมูลรายได้รายเดือน
      Map<String, double> monthlyIncome = {};

      for (var doc in bookingsSnapshot.docs) {
        Map<String, dynamic> bookingData = doc.data() as Map<String, dynamic>;

        // นับจำนวนสถานะการจอง
        String status = bookingData['status'] ?? 'pending';
        statusCount[status] = (statusCount[status] ?? 0) + 1;

        // ข้ามรายการที่ไม่ได้อยู่ในช่วงเวลาที่กำหนด
        if (bookingData['createdAt'] != null) {
          DateTime bookingDate =
              (bookingData['createdAt'] as Timestamp).toDate();
          if (bookingDate.isBefore(_startDate) ||
              bookingDate.isAfter(_endDate)) {
            continue;
          }

          // เก็บข้อมูลรายได้รายเดือน
          String monthYear = DateFormat('MM-yyyy').format(bookingDate);
          double amount = (bookingData['totalPrice'] is int)
              ? (bookingData['totalPrice'] as int).toDouble()
              : (bookingData['totalPrice'] ?? 0);

          monthlyIncome[monthYear] = (monthlyIncome[monthYear] ?? 0) + amount;
        }

        String sitterId = bookingData['sitterId'];
        double totalPrice = (bookingData['totalPrice'] is int)
            ? (bookingData['totalPrice'] as int).toDouble()
            : (bookingData['totalPrice'] ?? 0);

        if (!sitterIncomeMap.containsKey(sitterId)) {
          sitterIncomeMap[sitterId] = {
            'sitterId': sitterId,
            'totalIncome': 0.0,
            'bookingCount': 0,
            'sitterName': 'รอโหลด...',
            'photo': null,
          };
        }

        sitterIncomeMap[sitterId]!['totalIncome'] += totalPrice;
        sitterIncomeMap[sitterId]!['bookingCount'] += 1;
      }

      // 3. ดึงข้อมูลชื่อพี่เลี้ยง
      for (String sitterId in sitterIncomeMap.keys) {
        DocumentSnapshot sitterDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(sitterId)
            .get();

        if (sitterDoc.exists) {
          Map<String, dynamic> sitterData =
              sitterDoc.data() as Map<String, dynamic>;
          sitterIncomeMap[sitterId]!['sitterName'] =
              sitterData['name'] ?? 'ไม่ระบุชื่อ';
          sitterIncomeMap[sitterId]!['photo'] = sitterData['photo'];
        }
      }

      // 4. แปลงเป็น List และเรียงลำดับตามรายได้
      _sitterIncomeList = sitterIncomeMap.values.toList();
      _sitterIncomeList.sort((a, b) =>
          (b['totalIncome'] as double).compareTo(a['totalIncome'] as double));

      // 5. แปลงข้อมูลสถานะการจองเป็นรูปแบบสำหรับกราฟ
      _bookingStatusData = statusCount.entries
          .map((entry) => {
                'status': entry.key,
                'count': entry.value,
              })
          .toList();

      // 6. แปลงข้อมูลรายได้รายเดือนเป็นรูปแบบสำหรับกราฟ
      List<Map<String, dynamic>> monthlyData =
          monthlyIncome.entries.map((entry) {
        List<String> parts = entry.key.split('-');
        int month = int.parse(parts[0]);
        int year = int.parse(parts[1]);

        return {
          'month': month,
          'year': year,
          'monthYear': entry.key,
          'income': entry.value,
          'monthName': DateFormat('MMM').format(DateTime(year, month)),
        };
      }).toList();

      // เรียงลำดับตามเดือน
      monthlyData.sort((a, b) {
        int yearCompare = a['year'].compareTo(b['year']);
        if (yearCompare != 0) return yearCompare;
        return a['month'].compareTo(b['month']);
      });

      _monthlyIncomeData = monthlyData;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading sitter income data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepOrange,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSitterIncomeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานรายได้พี่เลี้ยง'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'เลือกช่วงเวลา',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSitterIncomeData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'รายได้'),
            Tab(text: 'กราฟรายเดือน'),
            Tab(text: 'สถานะการจอง'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // แท็บที่ 1: รายได้
                _buildIncomeTab(),

                // แท็บที่ 2: กราฟรายเดือน
                _buildMonthlyIncomeChart(),

                // แท็บที่ 3: กราฟสถานะการจอง
                _buildBookingStatusChart(),
              ],
            ),
    );
  }

  Widget _buildIncomeTab() {
    return _sitterIncomeList.isEmpty
        ? const Center(child: Text('ไม่พบข้อมูลรายได้'))
        : Column(
            children: [
              // แสดงช่วงเวลาที่เลือก
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.deepOrange.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('เปลี่ยน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // สรุปรายได้รวม
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'รายได้รวมทั้งหมด',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '฿${NumberFormat('#,##0').format(_calculateTotalIncome())}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'จำนวนการจอง',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_calculateTotalBookings()} รายการ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // รายการรายได้ของพี่เลี้ยงแต่ละคน
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _sitterIncomeList.length,
                  itemBuilder: (context, index) {
                    final sitterData = _sitterIncomeList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: sitterData['photo'] != null &&
                                  sitterData['photo'].toString().isNotEmpty &&
                                  sitterData['photo'] != 'images/User.png'
                              ? NetworkImage(sitterData['photo'])
                              : null,
                          child: (sitterData['photo'] == null ||
                                  sitterData['photo'].toString().isEmpty ||
                                  sitterData['photo'] == 'images/User.png')
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          sitterData['sitterName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${sitterData['bookingCount']} รายการ',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '฿${NumberFormat('#,##0').format(sitterData['totalIncome'])}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'เฉลี่ย ฿${NumberFormat('#,##0').format(sitterData['totalIncome'] / sitterData['bookingCount'])}/งาน',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildMonthlyIncomeChart() {
    if (_monthlyIncomeData.isEmpty) {
      return Center(child: Text('ไม่พบข้อมูลรายได้รายเดือน'));
    }

    return Column(
      children: [
        // แสดงช่วงเวลาที่เลือก
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepOrange.shade50,
          child: Row(
            children: [
              const Icon(Icons.date_range, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('เปลี่ยน'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // กราฟรายได้รายเดือน
        Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxMonthlyIncome() * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${_monthlyIncomeData[groupIndex]['monthName']} ${_monthlyIncomeData[groupIndex]['year']}\n',
                      TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text:
                              '฿${NumberFormat('#,##0').format(_monthlyIncomeData[groupIndex]['income'])}',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 &&
                          value.toInt() < _monthlyIncomeData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _monthlyIncomeData[value.toInt()]['monthName'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      return Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return Text('');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          '฿${NumberFormat('#,##0').format(value)}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                    reservedSize: 60,
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: false,
              ),
              barGroups: List.generate(
                _monthlyIncomeData.length,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: _monthlyIncomeData[index]['income'],
                      color: Colors.deepOrange,
                      width: 20,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ตารางข้อมูลรายเดือน
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: _monthlyIncomeData.length,
              itemBuilder: (context, index) {
                final data = _monthlyIncomeData[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepOrange.shade100,
                      child: Text(
                        data['monthName'],
                        style: TextStyle(
                          color: Colors.deepOrange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${data['monthName']} ${data['year']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Text(
                      '฿${NumberFormat('#,##0').format(data['income'])}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingStatusChart() {
    if (_bookingStatusData.isEmpty) {
      return Center(child: Text('ไม่พบข้อมูลสถานะการจอง'));
    }

    final List<Color> statusColors = [
      Colors.amber, // pending
      Colors.green, // confirmed
      Colors.blue, // in_progress
      Colors.purple, // completed
      Colors.red, // cancelled
    ];

    // นับจำนวนการจองทั้งหมด
    int totalBookings =
        _bookingStatusData.fold(0, (sum, item) => sum + (item['count'] as int));

    return Column(
      children: [
        // แสดงช่วงเวลาที่เลือก
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepOrange.shade50,
          child: Row(
            children: [
              const Icon(Icons.date_range, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              ElevatedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('เปลี่ยน'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // กราฟวงกลมแสดงสถานะการจอง
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 70,
              sections: List.generate(
                _bookingStatusData.length,
                (index) {
                  final item = _bookingStatusData[index];
                  if (item['count'] == 0)
                    return PieChartSectionData(
                        value: 0, color: Colors.transparent);

                  final double percentage = item['count'] / totalBookings * 100;

                  return PieChartSectionData(
                    color: _getStatusColorByName(item['status']),
                    value: item['count'].toDouble(),
                    title: '${percentage.toStringAsFixed(1)}%',
                    radius: 100,
                    titleStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // สรุปจำนวนการจองแต่ละสถานะ
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // จำนวนการจองทั้งหมด
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.summarize, color: Colors.deepOrange),
                        SizedBox(width: 12),
                        Text(
                          'จำนวนการจองทั้งหมด:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '$totalBookings รายการ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),

                // รายการสถานะการจอง
                Expanded(
                  child: ListView.builder(
                    itemCount: _bookingStatusData.length,
                    itemBuilder: (context, index) {
                      final item = _bookingStatusData[index];
                      final percentage = item['count'] / totalBookings * 100;

                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getStatusColorByName(item['status']),
                            child: Icon(_getStatusIconByName(item['status']),
                                color: Colors.white),
                          ),
                          title: Text(
                            _getStatusTextByName(item['status']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item['count']} รายการ',
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Add any additional trailing widgets here
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _calculateTotalIncome() {
    return _sitterIncomeList.fold(
        0, (sum, item) => sum + (item['totalIncome'] as double));
  }

  int _calculateTotalBookings() {
    return _sitterIncomeList.fold(
        0, (sum, item) => sum + (item['bookingCount'] as int));
  }

  double _getMaxMonthlyIncome() {
    if (_monthlyIncomeData.isEmpty) return 0;
    return _monthlyIncomeData
        .map((item) => item['income'] as double)
        .reduce((a, b) => a > b ? a : b);
  }

  Color _getStatusColorByName(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'confirmed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIconByName(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.pets;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusTextByName(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'in_progress':
        return 'กำลังดูแล';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
}
