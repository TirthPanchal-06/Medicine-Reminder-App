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

  Future<void> _scanPrescription() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
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
          if (medicines.length > 1) {
            if (mounted) {
              _showMedicineSelectorSheet(medicines);
            }
          } else {
            final firstMed = medicines.first;
            _populateMedicine(Map<String, dynamic>.from(firstMed));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('AI extracted details for: ${firstMed['name']}! Please review.'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI did not find any clear medication details. Please fill manually.'),
                backgroundColor: Colors.orange,
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

  void _populateMedicine(Map<String, dynamic> med) {
    setState(() {
      _nameController.text = med['name'] ?? '';
      _dosageController.text = med['dosage'] ?? '1 pill';
      
      final String rawFreq = med['frequency'] ?? 'daily';
      if (rawFreq == 'weekly') {
        _frequency = 'weekly';
      } else if (rawFreq == 'interval' || rawFreq == 'specific_days') {
        _frequency = 'interval';
      } else {
        _frequency = 'daily';
      }
      
      if (med['instructions'] != null) {
        _instructionsController.text = med['instructions'];
      }

      if (med['times'] != null && med['times'] is List) {
        _times.clear();
        _times.addAll(List<String>.from(med['times']));
      }
    });
  }

  Future<void> _saveSelectedMedicines(List medicines, List<bool> selectedStates) async {
    final meds = Provider.of<MedicationProvider>(context, listen: false);

    // Show progressive saving progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Saving Medications...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Writing schedules to your medicine organizer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        );
      },
    );

    int savedCount = 0;

    try {
      for (int i = 0; i < medicines.length; i++) {
        if (selectedStates[i]) {
          final med = Map<String, dynamic>.from(medicines[i]);
          final String name = med['name'] ?? 'Unknown Medicine';
          final String dosage = med['dosage'] ?? '1 pill';
          final String rawFreq = med['frequency'] ?? 'daily';
          
          String frequency = 'daily';
          if (rawFreq == 'weekly') {
            frequency = 'weekly';
          } else if (rawFreq == 'interval' || rawFreq == 'specific_days') {
            frequency = 'interval';
          }

          final List<String> times = med['times'] != null && med['times'] is List
              ? List<String>.from(med['times'])
              : ['08:00'];
              
          final String instructions = med['instructions'] ?? 'Take as directed';
          
          // Use default 7 days duration
          final durationDays = int.tryParse(_durationController.text.trim()) ?? 7;
          final DateTime startDate = DateTime.now();
          final DateTime endDate = startDate.add(Duration(days: durationDays));

          // Send attachment path if selected
          final filePath = _imageFile?.path;
          Uint8List? bytes;
          String? imgName;
          if (kIsWeb && _imageFile != null) {
            bytes = await _imageFile!.readAsBytes();
            imgName = _imageFile!.name;
          }

          await meds.addSchedule(
            name: name,
            dosage: dosage,
            frequency: frequency,
            specificDays: [],
            interval: 1,
            times: times,
            startDate: startDate,
            endDate: endDate,
            instructions: instructions,
            filePath: filePath,
            fileBytes: bytes,
            fileName: imgName,
          );
          savedCount++;
        }
      }

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      // Close bottom sheet
      if (mounted) Navigator.of(context).pop();
      // Close AddMedicineScreen and go back to dashboard
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully saved $savedCount medications!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save some medications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMedicineSelectorSheet(List medicines) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        List<bool> selectedStates = List.generate(medicines.length, (index) => true);
        
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final int selectedCount = selectedStates.where((s) => s).length;
            final bool isAllSelected = selectedCount == medicines.length;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.psychology, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Save Scanned Medicines',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'AI found ${medicines.length} medications. Check/uncheck to batch save.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // "Select All" toggle bar
                  InkWell(
                    onTap: () {
                      setSheetState(() {
                        final nextState = !isAllSelected;
                        for (int i = 0; i < selectedStates.length; i++) {
                          selectedStates[i] = nextState;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            isAllSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isAllSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isAllSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '$selectedCount of ${medicines.length} selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(medicines.length, (index) {
                          final med = Map<String, dynamic>.from(medicines[index]);
                          final name = med['name'] ?? 'Unknown Medicine';
                          final dosage = med['dosage'] ?? '1 pill';
                          final freq = med['frequency'] ?? 'daily';
                          final inst = med['instructions'] ?? 'Take as directed';
                          final List timesList = med['times'] ?? ['08:00'];
                          final isSelected = selectedStates[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  selectedStates[index] = !selectedStates[index];
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected 
                                        ? colorScheme.primary.withValues(alpha: 0.5) 
                                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                  color: isSelected 
                                      ? colorScheme.primary.withValues(alpha: 0.02) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Custom Checkbox Checkmark
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0, right: 12.0),
                                      child: Icon(
                                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                        size: 24,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              // Tapping detail edit icon lets you view/edit this item individually in the main form!
                                              IconButton(
                                                icon: Icon(Icons.edit_note, color: colorScheme.primary, size: 24),
                                                onPressed: () {
                                                  _populateMedicine(med);
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Loaded $name into editor! You can customize and save.'),
                                                      backgroundColor: const Color(0xFF10B981),
                                                    ),
                                                  );
                                                },
                                                tooltip: 'Edit details manually',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _buildBadge(
                                                context,
                                                Icons.scale,
                                                dosage,
                                                colorScheme.secondary,
                                              ),
                                              _buildBadge(
                                                context,
                                                Icons.repeat,
                                                freq,
                                                colorScheme.tertiary,
                                              ),
                                              _buildBadge(
                                                context,
                                                Icons.schedule,
                                                '${timesList.length} times (${timesList.join(', ')})',
                                                Colors.blue,
                                              ),
                                              if (inst.isNotEmpty && inst != 'Take as directed')
                                                _buildBadge(
                                                  context,
                                                  Icons.info_outline,
                                                  inst,
                                                  Colors.orange,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Submit Button
                  ElevatedButton.icon(
                    onPressed: selectedCount > 0 
                        ? () => _saveSelectedMedicines(medicines, selectedStates) 
                        : null,
                    icon: const Icon(Icons.save_alt),
                    label: Text(
                      selectedCount > 0 
                          ? 'Save $selectedCount Selected Medications' 
                          : 'Select Medications to Save',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                      disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Default duration: 7 Days (Starting Today). Adjust later from dashboard.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
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
