import 'package:flutter/material.dart';
import 'package:myproject/pages.dart/cat_history.dart';

class AddCatDialog extends StatefulWidget {
  final Function(Cat) onAdd;
  final Cat? cat;

  const AddCatDialog({Key? key, required this.onAdd, this.cat})
      : super(key: key);

  @override
  _AddCatDialogState createState() => _AddCatDialogState();
}

class _AddCatDialogState extends State<AddCatDialog> {
  // ฟิลด์และตัวควบคุม
  // ...

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cat == null ? 'Add New Cat' : 'Edit Cat'),
      content: Column(
          // เนื้อหาใน Add Cat Dialog
          ),
      actions: [
        // ปุ่ม Add/Update และ Cancel
      ],
    );
  }
}
