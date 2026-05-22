import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/medicine_schedule_model.dart';
import '../providers/medication_provider.dart';
import '../providers/health_provider.dart';

class AddMedicineScreen extends StatefulWidget {
  final MedicineScheduleModel? existingSchedule;
  const AddMedicineScreen({super.key, this.existingSchedule});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _durationController = TextEditingController(text: '7');

  String _frequency = 'daily';
  final List<String> _specificDays = [];
  final int _interval = 1;
  final List<String> _times = ['08:00'];
  DateTime _startDate = DateTime.now();

  XFile? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      final s = widget.existingSchedule!;
      _nameController.text = s.name;
      _dosageController.text = s.dosage;
      _instructionsController.text = s.instructions;
      _frequency = s.frequency;
      _specificDays.clear();
      _specificDays.addAll(s.specificDays);
      _times.clear();
      _times.addAll(s.times);
      _startDate = s.startDate;
      
      if (s.endDate != null) {
        final durationDays = s.endDate!.difference(s.startDate).inDays;
        _durationController.text = durationDays > 0 ? durationDays.toString() : '';
      } else {
        _durationController.text = '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // --- OCR prescription Scanner Call ---
  Future<void> _scanPrescription() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = pickedFile;
    });

    if (!mounted) return;
    final health = Provider.of<HealthProvider>(context, listen: false);

    // Show dynamic scanning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'AI Scanner Processing...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('Analyzing text and extracting medicine details', textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    try {
      Uint8List? bytes;
      String? name;
      if (kIsWeb) {
        bytes = await pickedFile.readAsBytes();
        name = pickedFile.name;
      }
      final ocrData = await health.scanPrescription(
        pickedFile.path,
        fileBytes: bytes,
        fileName: name,
      );
      if (mounted) Navigator.of(context).pop(); // Close dialog

      if (ocrData != null && ocrData['medicines'] != null) {
        final List medicines = ocrData['medicines'];
        if (medicines.isNotEmpty) {
          final firstMed = medicines.first;
          setState(() {
            _nameController.text = firstMed['name'] ?? '';
            _dosageController.text = firstMed['dosage'] ?? '1 pill';
            _frequency = firstMed['frequency'] ?? 'daily';
            
            if (firstMed['instructions'] != null) {
              _instructionsController.text = firstMed['instructions'];
            }

            if (firstMed['times'] != null && firstMed['times'] is List) {
              _times.clear();
              _times.addAll(List<String>.from(firstMed['times']));
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI Successfully extracted prescription details! Please review.'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI scanning failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final meds = Provider.of<MedicationProvider>(context, listen: false);

    try {
      Uint8List? bytes;
      String? name;
      if (kIsWeb && _imageFile != null) {
        bytes = await _imageFile!.readAsBytes();
        name = _imageFile!.name;
      }

      final durationDays = int.tryParse(_durationController.text.trim());
      DateTime? endDate;
      if (durationDays != null && durationDays > 0) {
        endDate = _startDate.add(Duration(days: durationDays));
      }

      if (widget.existingSchedule != null) {
        await meds.updateSchedule(
          id: widget.existingSchedule!.id,
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          frequency: _frequency,
          specificDays: _specificDays,
          interval: _interval,
          times: _times,
          startDate: _startDate,
          endDate: endDate,
          instructions: _instructionsController.text.trim(),
          filePath: _imageFile?.path,
          fileBytes: bytes,
          fileName: name,
        );
      } else {
        await meds.addSchedule(
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          frequency: _frequency,
          specificDays: _specificDays,
          interval: _interval,
          times: _times,
          startDate: _startDate,
          endDate: endDate,
          instructions: _instructionsController.text.trim(),
          filePath: _imageFile?.path,
          fileBytes: bytes,
          fileName: name,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingSchedule != null
                ? 'Medication Schedule updated successfully!'
                : 'Medication Schedule added successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingSchedule != null
                ? 'Error updating schedule: $e'
                : 'Error adding schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingSchedule != null ? 'Edit Medication Schedule' : 'Add Medicine', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // OCR scanning button
              ElevatedButton.icon(
                onPressed: _scanPrescription,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scan Doctor\'s Prescription (OCR)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.secondary.withValues(alpha: 0.12),
                  foregroundColor: colorScheme.secondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),

              // Inputs card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Medicine Name',
                          prefixIcon: Icon(Icons.medication),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter medicine name' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dosage
                      TextFormField(
                        controller: _dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Dosage (e.g. 1 pill, 5ml)',
                          prefixIcon: Icon(Icons.scale),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter dosage' : null,
                      ),
                      const SizedBox(height: 16),

                      // Instructions
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Instructions (e.g. before food)',
                          prefixIcon: Icon(Icons.assignment_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Duration (Days)
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (Days, empty for ongoing)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final parsed = int.tryParse(val);
                            if (parsed == null || parsed <= 0) {
                              return 'Please enter a valid number of days';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Scheduling frequency settings card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schedule Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Frequency Type
                      DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('Every Day')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'interval', child: Text('Custom Interval')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _frequency = val ?? 'daily';
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Custom Times list
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Intake Times', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Time'),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                final formatted = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                                setState(() {
                                  _times.add(formatted);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: _times.map((time) {
                          return Chip(
                            label: Text(time),
                            onDeleted: _times.length > 1
                                ? () {
                                    setState(() {
                                      _times.remove(time);
                                    });
                                  }
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(widget.existingSchedule != null ? 'Update Medication Schedule' : 'Save Medication Schedule', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
