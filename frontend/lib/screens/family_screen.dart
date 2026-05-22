import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/medication_provider.dart';
import '../models/family_member_model.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _ageC = TextEditingController();
  final _historyC = TextEditingController();

  String _relationship = 'child';
  String _gender = 'male';
  FamilyMemberModel? _editingMember;

  @override
  void dispose() {
    _nameC.dispose();
    _ageC.dispose();
    _historyC.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final meds = Provider.of<MedicationProvider>(context, listen: false);
    final name = _nameC.text.trim();
    final relationship = _relationship;
    final age = int.tryParse(_ageC.text.trim()) ?? 0;
    final gender = _gender;
    final medicalHistory = _historyC.text.trim();

    try {
      if (_editingMember != null) {
        await meds.updateFamilyMember(
          _editingMember!.id,
          name,
          relationship,
          age,
          gender,
          medicalHistory,
        );
        if (mounted) {
          setState(() {
            _editingMember = null;
            _nameC.clear();
            _ageC.clear();
            _historyC.clear();
            _relationship = 'child';
            _gender = 'male';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Family Member updated successfully!'), backgroundColor: Color(0xFF10B981)),
          );
        }
      } else {
        await meds.addFamilyMember(
          name,
          relationship,
          age,
          gender,
          medicalHistory,
        );
        if (mounted) {
          _nameC.clear();
          _ageC.clear();
          _historyC.clear();
          setState(() {
            _relationship = 'child';
            _gender = 'male';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Family Member added successfully!'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, MedicationProvider meds, FamilyMemberModel m) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Family Member?'),
        content: Text('Are you sure you want to delete ${m.name}? This will also deactivate all linked medicine schedules.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await meds.deleteFamilyMember(m.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Family Member removed successfully!'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete profile: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meds = Provider.of<MedicationProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Members', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // List of family members
            const Text('Registered Profiles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            const SizedBox(height: 10),
            meds.familyMembers.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No dependents added yet. Fill in the form below to add parents or children.'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: meds.familyMembers.length,
                    itemBuilder: (context, index) {
                      final m = meds.familyMembers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person),
                          ),
                          title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${m.relationship.toUpperCase()} • ${m.age} yrs • ${m.gender}\nHistory: ${m.medicalHistory}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                tooltip: 'Edit profile',
                                onPressed: () {
                                  setState(() {
                                    _editingMember = m;
                                    _nameC.text = m.name;
                                    _ageC.text = m.age?.toString() ?? '';
                                    _relationship = m.relationship;
                                    _gender = m.gender ?? 'other';
                                    _historyC.text = m.medicalHistory;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete profile',
                                onPressed: () => _confirmDelete(context, meds, m),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // Form to Add/Edit member
            Text(
              _editingMember != null ? 'Edit Family Member' : 'Add Family Member',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameC,
                        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 14),

                      // Age
                      TextFormField(
                        controller: _ageC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
                        validator: (val) => val == null || val.isEmpty ? 'Please enter age' : null,
                      ),
                      const SizedBox(height: 14),

                      // Relationship selector
                      DropdownButtonFormField<String>(
                        value: _relationship,
                        decoration: const InputDecoration(labelText: 'Relationship'),
                        items: const [
                          DropdownMenuItem(value: 'parent', child: Text('Parent')),
                          DropdownMenuItem(value: 'child', child: Text('Child')),
                          DropdownMenuItem(value: 'spouse', child: Text('Spouse')),
                          DropdownMenuItem(value: 'sibling', child: Text('Sibling')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (val) => setState(() => _relationship = val ?? 'other'),
                      ),
                      const SizedBox(height: 14),

                      // Gender selector
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (val) => setState(() => _gender = val ?? 'other'),
                      ),
                      const SizedBox(height: 14),

                      // Medical History
                      TextFormField(
                        controller: _historyC,
                        decoration: const InputDecoration(labelText: 'Medical History / Notes', prefixIcon: Icon(Icons.history)),
                      ),
                      const SizedBox(height: 20),

                      // Submit & Cancel button row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_editingMember != null) ...[
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _editingMember = null;
                                  _nameC.clear();
                                  _ageC.clear();
                                  _historyC.clear();
                                  _relationship = 'child';
                                  _gender = 'male';
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                          ],
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingMember != null ? Colors.blue : colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_editingMember != null ? 'Save Changes' : 'Add Family Member'),
                          ),
                        ],
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
