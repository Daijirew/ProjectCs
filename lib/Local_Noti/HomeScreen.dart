import 'package:flutter/material.dart';
import 'package:myproject/Local_Noti/NotiClass.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({Key? key}) : super(key: key);

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  NotifiationServices notifiationServices = NotifiationServices();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Local Noti'),
        centerTitle: true,
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              notifiationServices.sendNotification();
            },
            child: Text('Send Noti'),
          ),
          ElevatedButton(
            onPressed: () {
              notifiationServices.scheduleNotification();
            },
            child: Text('Schedule Noti'),
          ),
          ElevatedButton(
            onPressed: () {
              notifiationServices.stopNoti();
            },
            child: Text('Stop Noti'),
          ),
        ],
      )),
    );
  }
}
