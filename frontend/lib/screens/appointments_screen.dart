import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/medication_provider.dart';
import '../models/appointment_model.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorC = TextEditingController();
  final _specialtyC = TextEditingController();
  final _venueC = TextEditingController();
  final _notesC = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _doctorC.dispose();
    _specialtyC.dispose();
    _venueC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final meds = Provider.of<MedicationProvider>(context, listen: false);
    
    // Combine Date and Time
    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await meds.addAppointment(
        _doctorC.text.trim(),
        _specialtyC.text.trim(),
        combinedDateTime,
        _venueC.text.trim(),
        _notesC.text.trim(),
      );

      if (mounted) {
        _doctorC.clear();
        _specialtyC.clear();
        _venueC.clear();
        _notesC.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment scheduled successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule appointment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment?'),
        content: const Text('Are you sure you want to cancel this doctor checkup reminder? This will remove all local notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final meds = Provider.of<MedicationProvider>(context, listen: false);
              try {
                await meds.deleteAppointment(appointmentId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment cancelled successfully!'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel appointment: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _editAppointment(AppointmentModel appt) {
    final editFormKey = GlobalKey<FormState>();
    final doctorC = TextEditingController(text: appt.doctorName);
    final specialtyC = TextEditingController(text: appt.specialty);
    final venueC = TextEditingController(text: appt.venue);
    final notesC = TextEditingController(text: appt.notes);

    DateTime selectedDate = appt.dateTime.toLocal();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(appt.dateTime.toLocal());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Appointment'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: doctorC,
                      decoration: const InputDecoration(
                        labelText: 'Doctor Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Please enter doctor name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: specialtyC,
                      decoration: const InputDecoration(
                        labelText: 'Specialty',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setDialogState(() => selectedDate = date);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(selectedTime.format(context)),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (time != null) {
                                setDialogState(() => selectedTime = time);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: venueC,
                      decoration: const InputDecoration(
                        labelText: 'Venue / Location',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesC,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!editFormKey.currentState!.validate()) return;
                
                final combinedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                Navigator.pop(context);

                final meds = Provider.of<MedicationProvider>(context, listen: false);
                try {
                  await meds.updateAppointment(
                    id: appt.id,
                    doctorName: doctorC.text.trim(),
                    specialty: specialtyC.text.trim(),
                    dateTime: combinedDateTime,
                    venue: venueC.text.trim(),
                    notes: notesC.text.trim(),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appointment updated successfully!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update appointment: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meds = Provider.of<MedicationProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // List of upcoming checkups
            const Text('Checkup Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 10),
            meds.appointments.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No upcoming doctor checkups registered. Schedule one below.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: meds.appointments.length,
                    itemBuilder: (context, index) {
                      final appt = meds.appointments[index];
                      final formattedDate = DateFormat('EEEE, MMM dd - hh:mm a').format(appt.dateTime.toLocal());
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.calendar_today),
                          ),
                          title: Text('Dr. ${appt.doctorName} (${appt.specialty})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('When: $formattedDate\nWhere: ${appt.venue}\nNotes: ${appt.notes}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editAppointment(appt),
                                tooltip: 'Edit Appointment',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(appt.id),
                                tooltip: 'Cancel Appointment',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // Form to Add Checkup
            const Text('Schedule Appointment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Doctor Name
                      TextFormField(
                        controller: _doctorC,
                        decoration: const InputDecoration(labelText: 'Doctor Name (without Dr.)', prefixIcon: Icon(Icons.person_outline)),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter doctor name' : null,
                      ),
                      const SizedBox(height: 14),

                      // Specialty
                      TextFormField(
                        controller: _specialtyC,
                        decoration: const InputDecoration(labelText: 'Specialty (e.g. Cardiologist)', prefixIcon: Icon(Icons.local_hospital_outlined)),
                      ),
                      const SizedBox(height: 14),

                      // Date & Time Picker Triggers
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.date_range),
                              label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  setState(() => _selectedDate = date);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: Text(_selectedTime.format(context)),
                              onPressed: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setState(() => _selectedTime = time);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Venue
                      TextFormField(
                        controller: _venueC,
                        decoration: const InputDecoration(labelText: 'Venue / Clinic Location', prefixIcon: Icon(Icons.place_outlined)),
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      TextFormField(
                        controller: _notesC,
                        decoration: const InputDecoration(labelText: 'Notes / Symptoms details', prefixIcon: Icon(Icons.notes)),
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Schedule Checkup'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
