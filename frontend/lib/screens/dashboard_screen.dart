import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/medication_provider.dart';
import '../providers/health_provider.dart';
import 'add_medicine_screen.dart';
import 'vitals_tracker_screen.dart';
import 'chatbot_screen.dart';
import 'family_screen.dart';
import 'appointments_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load initial values on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meds = Provider.of<MedicationProvider>(context, listen: false);
      final health = Provider.of<HealthProvider>(context, listen: false);
      meds.syncOfflineData(); // Try to sync cached offline operations
      meds.refreshAllData();
      health.fetchVitalsSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final meds = Provider.of<MedicationProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = auth.darkMode;

    final List<Widget> pages = [
      const HomeTimelinePage(),
      const MedicinesListPage(),
      const VitalsTrackerScreen(),
      const CareCirclePage(),
    ];

    final List<String> titles = [
      'Dashboard',
      'My Medications',
      'Health Tracker',
      'Care Circle'
    ];

    return Scaffold(
      appBar: AppBar(
        title: _currentIndex == 0
            ? Image.asset(
                'assets/logo.png',
                height: 40,
                fit: BoxFit.contain,
              )
            : Text(
                titles[_currentIndex],
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Dynamic Sync Icon
          IconButton(
            icon: Icon(Icons.sync_rounded, color: meds.isLoading ? colorScheme.primary : null),
            onPressed: meds.isLoading ? null : () => meds.syncOfflineData(),
          ),
          // Theme Toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => auth.toggleTheme(),
          ),
          // Chat Assistant Shortcut
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatbotScreen()),
            ),
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined),
            activeIcon: Icon(Icons.medication_rounded),
            label: 'Meds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics_rounded),
            label: 'Vitals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline_rounded),
            activeIcon: Icon(Icons.favorite_rounded),
            label: 'Care',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }
}

// ======================== TABS IMPLEMENTATION ========================

// --- Tab 1: Home Dashboard Timeline & compliance ---
class HomeTimelinePage extends StatelessWidget {
  const HomeTimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final meds = Provider.of<MedicationProvider>(context);
    final health = Provider.of<HealthProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = auth.darkMode;
    final colorScheme = Theme.of(context).colorScheme;

    final adherence = meds.complianceStats?['adherenceRate'] ?? 0;

    return RefreshIndicator(
      onRefresh: () async {
        await meds.refreshAllData();
        await health.fetchVitalsSummary();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Family sub-profile switcher dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Hello, ${auth.user?.name ?? "User"} 👋',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        isDense: true,
                        padding: EdgeInsets.zero,
                        value: meds.selectedFamilyMemberId,
                        hint: const Text('Profile'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Me')),
                          ...meds.familyMembers.map((member) {
                            return DropdownMenuItem(
                              value: member.id,
                              child: Text(
                                member.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (id) => meds.selectFamilyMember(id),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Adherence compliance card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 75,
                          width: 75,
                          child: CircularProgressIndicator(
                            value: adherence / 100,
                            strokeWidth: 9,
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
                          ),
                        ),
                        Text(
                          '$adherence%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Consistency",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adherence >= 80 ? 'Excellent job staying on track!' : 'Keep logging to maintain your health!',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Today's timeline checklist
            const Text(
              "Today's Schedule",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 10),

            meds.todayDoses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 64, color: colorScheme.secondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text('No medications scheduled for today.', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: meds.todayDoses.length,
                    itemBuilder: (context, index) {
                      final dose = meds.todayDoses[index];
                      final isTaken = dose.status == 'taken';
                      final isSkipped = dose.status == 'skipped';
                      
                      final formattedTime = DateFormat('hh:mm a').format(dose.dueTime.toLocal());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isTaken
                            ? colorScheme.secondary.withValues(alpha: 0.06)
                            : isSkipped
                                ? colorScheme.error.withValues(alpha: 0.04)
                                : null,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: isTaken
                                  ? colorScheme.secondary.withValues(alpha: 0.12)
                                  : isSkipped
                                      ? colorScheme.error.withValues(alpha: 0.12)
                                      : colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTaken
                                  ? Icons.check
                                  : isSkipped
                                      ? Icons.close
                                      : Icons.medication,
                              color: isTaken
                                  ? colorScheme.secondary
                                  : isSkipped
                                      ? colorScheme.error
                                      : colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            dose.medicineName ?? 'Medicine',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: isTaken ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text('${dose.dosage} • $formattedTime\n${dose.instructions}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Check/Log Adherence
                              if (!isTaken)
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                                  onPressed: () => meds.logDose(dose.id, 'taken'),
                                ),
                              if (!isSkipped && !isTaken)
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: colorScheme.error),
                                  onPressed: () => meds.logDose(dose.id, 'skipped'),
                                ),
                              if (isTaken || isSkipped)
                                Text(
                                  isTaken ? 'TAKEN' : 'SKIPPED',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isTaken ? colorScheme.secondary : colorScheme.error,
                                  ),
                                )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // SOS Contact Card Quick Dial
            if (meds.sosContacts.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  final phone = meds.sosContacts.first.phone;
                  final url = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.emergency, color: Colors.white),
                label: Text('EMERGENCY SOS: Call ${meds.sosContacts.first.name}'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Tab 2: Medicine Schedules List ---
class MedicinesListPage extends StatelessWidget {
  const MedicinesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final meds = Provider.of<MedicationProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: meds.schedules.length,
      itemBuilder: (context, index) {
        final medicine = meds.schedules[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
              child: const Icon(Icons.medication),
            ),
            title: Text(
              medicine.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Dosage: ${medicine.dosage}'),
                Text('Frequency: ${medicine.frequency} (${medicine.times.join(", ")})'),
                if (medicine.instructions.isNotEmpty) Text('Notes: ${medicine.instructions}'),
                if (!medicine.isSynced)
                  const Row(
                    children: [
                      Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text('Waiting to sync', style: TextStyle(color: Colors.orange, fontSize: 12))
                    ],
                  )
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddMedicineScreen(existingSchedule: medicine),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => meds.deleteSchedule(medicine.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Tab 4: Care Circle Page ---
class CareCirclePage extends StatelessWidget {
  const CareCirclePage({super.key});

  @override
  Widget build(BuildContext context) {
    final meds = Provider.of<MedicationProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Family Management Box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Family Members',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FamilyScreen()),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  meds.familyMembers.isEmpty
                      ? const Text('Add family members (kids/parents) to track their medications.')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: meds.familyMembers.length,
                          itemBuilder: (context, index) {
                            final m = meds.familyMembers[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.account_circle),
                              title: Text(m.name),
                              subtitle: Text(m.relationship.toUpperCase()),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Doctor Appointments Box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upcoming Appointments',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month_outlined),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  meds.appointments.isEmpty
                      ? const Text('Schedule checkups with your doctor.')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: meds.appointments.take(3).length,
                          itemBuilder: (context, index) {
                            final appt = meds.appointments[index];
                            final formattedDate = DateFormat('MMM dd, hh:mm a').format(appt.dateTime.toLocal());
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.local_hospital_outlined),
                              title: Text(appt.doctorName),
                              subtitle: Text('$formattedDate at ${appt.venue}'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // SOS Contacts Box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emergency Contacts (SOS)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  meds.sosContacts.isEmpty
                      ? const Text('Setup quick-dial emergency support contacts.')
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: meds.sosContacts.length,
                          itemBuilder: (context, index) {
                            final contact = meds.sosContacts[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.phone_in_talk, color: Colors.red),
                              title: Text(contact.name),
                              subtitle: Text('${contact.phone} (${contact.relationship})'),
                            );
                          },
                        ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Simple Dialog to Add SOS Contacts
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final nameC = TextEditingController();
                          final phoneC = TextEditingController();
                          final relC = TextEditingController();
                          return AlertDialog(
                            title: const Text('Add SOS Contact'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
                                TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Phone')),
                                TextField(controller: relC, decoration: const InputDecoration(labelText: 'Relationship')),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  if (nameC.text.isNotEmpty && phoneC.text.isNotEmpty) {
                                    meds.addSOSContact(nameC.text, phoneC.text, relC.text);
                                  }
                                  Navigator.of(ctx).pop();
                                },
                                child: const Text('Add'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                    child: const Text('Configure SOS Contacts'),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Log Out
          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )
        ],
      ),
    );
  }
}
