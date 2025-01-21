import 'package:flutter/material.dart';
import 'package:myproject/Catpage.dart/CatEdid.dart';
import 'cat.dart';

class CatDetailsPage extends StatefulWidget {
  final Cat cat;
  const CatDetailsPage({Key? key, required this.cat}) : super(key: key);

  @override
  State<CatDetailsPage> createState() => _CatDetailsPageState();
}

class _CatDetailsPageState extends State<CatDetailsPage> {
  late Cat currentCat;

  @override
  void initState() {
    super.initState();
    currentCat = widget.cat;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${currentCat.name}\' Profile',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange.shade400,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final updatedCat = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CatEditPage(cat: currentCat),
                ),
              );

              if (updatedCat != null) {
                setState(() {
                  currentCat = updatedCat;
                });
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade200, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                height: 300,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: Hero(
                  tag: 'cat-${currentCat.name}',
                  child: currentCat.imagePath.isNotEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.network(
                              currentCat.imagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Icon(
                            Icons.pets,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 16),
                      child: Text(
                        'Pet Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                    _buildInfoRow(
                      Icons.pets,
                      'Name',
                      currentCat.name,
                      Colors.orange.shade400,
                    ),
                    _buildInfoRow(
                      Icons.category,
                      'Breed',
                      currentCat.breed,
                      Colors.orange.shade400,
                    ),
                    _buildInfoRow(
                      Icons.cake,
                      'Birthday',
                      currentCat.birthDate?.toDate().toString().split(' ')[0] ??
                          'Unknown',
                      Colors.orange.shade400,
                    ),
                    _buildInfoRow(
                      Icons.medical_services,
                      'Vaccinations',
                      currentCat.vaccinations,
                      Colors.orange.shade400,
                    ),
                    _buildInfoRow(
                      Icons.description,
                      'Description',
                      currentCat.description,
                      Colors.orange.shade400,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      Icons.medical_services,
                      'Health Records',
                      () {
                        // TODO: นำไปยังหน้าประวัติสุขภาพ
                      },
                    ),
                    _buildActionButton(
                      Icons.calendar_today,
                      'Schedule',
                      () {
                        // TODO: นำไปยังหน้าตารางนัด
                      },
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

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.orange.shade400),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.orange.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
