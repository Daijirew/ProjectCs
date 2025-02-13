import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({Key? key}) : super(key: key);

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  List<String> getFormattedDates() {
    final now = DateTime.now();
    final formatter = DateFormat('EEE d');
    return List.generate(7, (index) {
      final date = now.add(Duration(days: index));
      return formatter.format(date);
    });
  }

  int track = 0;
  bool eight = false, ten = false, six = false;

  @override
  Widget build(BuildContext context) {
    final dates = getFormattedDates();
    return Scaffold(
      body: Container(
        child: Stack(
          children: [
            Image.asset(
              "images/duck.jpg",
              height: MediaQuery.of(context).size.height / 2,
              width: MediaQuery.of(context).size.width,
              fit: BoxFit.cover,
            ),
            Container(
              margin: EdgeInsets.only(left: 20.0, top: 30.0),
              child: Material(
                elevation: 3.0,
                borderRadius: BorderRadius.circular(30.0),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30)),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: 20.0, top: 20.0, right: 10.0),
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height / 2.5,
                    left: 5.0,
                    right: 5.0),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cat",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26.0,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Cat",
                      style: TextStyle(
                          color: const Color.fromARGB(174, 255, 255, 255),
                          fontSize: 18.0,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(
                      height: 20.0,
                    ),
                    Text(
                      "cat only birthday",
                      style: TextStyle(
                          color: const Color.fromARGB(174, 255, 255, 255),
                          fontSize: 18.0,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(
                      height: 10.0,
                    ),
                    Text(
                      "Select Date",
                      style: TextStyle(
                          color: Color.fromARGB(239, 255, 255, 255),
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700),
                    ),
                    SizedBox(
                      height: 10.0,
                    ),
                    Container(
                      height: 70,
                      child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: dates.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                track = index;
                                setState(() {});
                              },
                              child: Container(
                                width: 100,
                                margin: EdgeInsets.only(right: 20.0),
                                decoration: BoxDecoration(
                                    color: Color(0xffeed51e),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: track == index
                                            ? Colors.white
                                            : Colors.black,
                                        width: 5.0)),
                                child: Center(
                                  child: Text(
                                    dates[index],
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          }),
                    ),
                    SizedBox(
                      height: 10.0,
                    ),
                    Text(
                      "Select Time Slot",
                      style: TextStyle(
                          color: Color.fromARGB(239, 255, 255, 255),
                          fontSize: 18.0,
                          fontWeight: FontWeight.w700),
                    ),
                    SizedBox(
                      height: 10.0,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            eight = true;
                            ten = false;
                            six = false;
                            setState(() {});
                          },
                          child: eight
                              ? Material(
                                  elevation: 10.0,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: Color(0xffeed51e),
                                            width: 5.0),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                      "08:00 PM",
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Color(0xffeed51e), width: 3.0),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    "08:00 PM",
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(174, 255, 255, 255),
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ten = true;
                            eight = false;
                            six = false;
                            setState(() {});
                          },
                          child: ten
                              ? Material(
                                  elevation: 10.0,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: Color(0xffeed51e),
                                            width: 5.0),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                      "10:00 PM",
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Color(0xffeed51e), width: 3.0),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    "10:00 PM",
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(174, 255, 255, 255),
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () {
                            ten = false;
                            eight = false;
                            six = true;
                            setState(() {});
                          },
                          child: six
                              ? Material(
                                  elevation: 10.0,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: Color(0xffeed51e),
                                            width: 5.0),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(
                                      "06:00 PM",
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Color(0xffeed51e), width: 3.0),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    "06:00 PM",
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(174, 255, 255, 255),
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 30.0,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2.0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Icon(
                                Icons.add,
                                color: Colors.white,
                              ),
                              Text(
                                "1",
                                style: TextStyle(
                                    color: Color(0xffeed51e),
                                    fontSize: 30.0,
                                    fontWeight: FontWeight.bold),
                              ),
                              Icon(
                                Icons.remove,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 10.0,
                        ),
                        Container(
                          width: 200,
                          decoration: BoxDecoration(
                              color: Color(0xffeed51e),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.white, width: 2.0)),
                          child: Column(
                            children: [
                              Text(
                                "Total : " "\$50",
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "Book Now",
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 26.0,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
