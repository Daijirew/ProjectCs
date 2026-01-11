import 'package:flutter/material.dart';

class VaccineSelectionPage extends StatefulWidget {
  final Map<String, Map<String, bool>> initialSelections;

  const VaccineSelectionPage({
    Key? key,
    required this.initialSelections,
  }) : super(key: key);

  @override
  State<VaccineSelectionPage> createState() => _VaccineSelectionPageState();
}

class _VaccineSelectionPageState extends State<VaccineSelectionPage> {
  late Map<String, Map<String, bool>> vaccinationGroups;

  @override
  void initState() {
    super.initState();
    vaccinationGroups = Map.fromEntries(
      widget.initialSelections.entries.map(
        (group) => MapEntry(
          group.key,
          Map.fromEntries(group.value.entries),
        ),
      ),
    );
  }

  String _getVaccineDescription(String vaccine) {
    Map<String, String> descriptions = {
      'FPV (Feline Panleukopenia)': 'Protects against feline distemper',
      'FHV (Feline Viral Rhinotracheitis)': 'Prevents respiratory infections',
      'FCV (Feline Calicivirus)':
          'Guards against oral disease and upper respiratory infections',
      'FeLV (Feline Leukemia Virus)': 'Protects against feline leukemia',
      'Rabies': 'Required by law, prevents rabies infection',
    };
    return descriptions[vaccine] ?? '';
  }

  int getSelectedCount() {
    int count = 0;
    vaccinationGroups.forEach((_, vaccines) {
      count += vaccines.values.where((isSelected) => isSelected).length;
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เลือกวัคซีน',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              '${getSelectedCount()} selected',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange, // เปลี่ยนเป็นสีส้ม
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, vaccinationGroups);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'ยืนยัน',
                style: TextStyle(
                  color: Colors.orange.shade700, // เปลี่ยนเป็นสีส้ม
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.white], // เปลี่ยนเป็นสีส้ม
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vaccinationGroups.length,
          itemBuilder: (context, groupIndex) {
            final group = vaccinationGroups.entries.elementAt(groupIndex);
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50, // เปลี่ยนเป็นสีส้ม
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100, // เปลี่ยนเป็นสีส้ม
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.medical_services,
                            color: Colors.orange.shade700, // เปลี่ยนเป็นสีส้ม
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          group.key,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700, // เปลี่ยนเป็นสีส้ม
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...group.value.entries
                      .map((vaccine) => Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade100,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Transform.scale(
                                scale: 1.2,
                                child: Checkbox(
                                  value: vaccine.value,
                                  activeColor:
                                      Colors.orange, // เปลี่ยนเป็นสีส้ม
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      vaccinationGroups[group.key]![
                                          vaccine.key] = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              title: Text(
                                vaccine.key,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _getVaccineDescription(vaccine.key),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
