import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/health_provider.dart';

class VitalsTrackerScreen extends StatefulWidget {
  const VitalsTrackerScreen({super.key});

  @override
  State<VitalsTrackerScreen> createState() => _VitalsTrackerScreenState();
}

class _VitalsTrackerScreenState extends State<VitalsTrackerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _systolicC = TextEditingController();
  final _diastolicC = TextEditingController();
  final _sugarC = TextEditingController();
  final _heartC = TextEditingController();
  final _weightC = TextEditingController();
  
  String _sugarMealType = 'fasting';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final health = Provider.of<HealthProvider>(context, listen: false);
      health.fetchVitals('blood_pressure');
      health.fetchVitals('blood_sugar');
      health.fetchVitals('heart_rate');
      health.fetchVitals('weight');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systolicC.dispose();
    _diastolicC.dispose();
    _sugarC.dispose();
    _heartC.dispose();
    _weightC.dispose();
    super.dispose();
  }

  void _logVitals(String type) async {
    final health = Provider.of<HealthProvider>(context, listen: false);
    Map<String, dynamic> value = {};

    if (type == 'blood_pressure') {
      if (_systolicC.text.isEmpty || _diastolicC.text.isEmpty) return;
      value = {
        'systolic': int.parse(_systolicC.text.trim()),
        'diastolic': int.parse(_diastolicC.text.trim()),
      };
      _systolicC.clear();
      _diastolicC.clear();
    } else if (type == 'blood_sugar') {
      if (_sugarC.text.isEmpty) return;
      value = {
        'value': int.parse(_sugarC.text.trim()),
        'mealType': _sugarMealType,
      };
      _sugarC.clear();
    } else if (type == 'heart_rate') {
      if (_heartC.text.isEmpty) return;
      value = {
        'value': int.parse(_heartC.text.trim()),
      };
      _heartC.clear();
    } else if (type == 'weight') {
      if (_weightC.text.isEmpty) return;
      value = {
        'value': double.parse(_weightC.text.trim()),
        'unit': 'kg',
      };
      _weightC.clear();
    }

    try {
      await health.addVitalsRecord(type, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.replaceAll("_", " ").toUpperCase()} logged successfully!'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log vital: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Tab Header Bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Blood Pressure'),
                Tab(text: 'Blood Sugar'),
                Tab(text: 'Heart Rate'),
                Tab(text: 'Weight'),
              ],
            ),
            
            // Tab body screens
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBPPage(isDark),
                  _buildSugarPage(isDark),
                  _buildPulsePage(isDark),
                  _buildWeightPage(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BP Tracker UI Screen ---
  Widget _buildBPPage(bool isDark) {
    final health = Provider.of<HealthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input Form Box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Blood Pressure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _systolicC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Systolic (e.g. 120)', suffixText: 'mmHg'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _diastolicC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Diastolic (e.g. 80)', suffixText: 'mmHg'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _logVitals('blood_pressure'),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                    child: const Text('Log Record'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Analytical graph container
          const Text('Trend Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          _buildChartContainer(health.bloodPressureRecords, 'blood_pressure', colorScheme),
        ],
      ),
    );
  }

  // --- Blood Sugar Tracker Screen ---
  Widget _buildSugarPage(bool isDark) {
    final health = Provider.of<HealthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Blood Sugar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sugarC,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Sugar Level', suffixText: 'mg/dL'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _sugarMealType,
                          decoration: const InputDecoration(labelText: 'Period'),
                          items: const [
                            DropdownMenuItem(value: 'fasting', child: Text('Fasting')),
                            DropdownMenuItem(value: 'post_prandial', child: Text('Post Meal')),
                            DropdownMenuItem(value: 'random', child: Text('Random')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _sugarMealType = val ?? 'fasting';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _logVitals('blood_sugar'),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                    child: const Text('Log Record'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Trend Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          _buildChartContainer(health.bloodSugarRecords, 'blood_sugar', colorScheme),
        ],
      ),
    );
  }

  // --- Heart Rate Tracker Screen ---
  Widget _buildPulsePage(bool isDark) {
    final health = Provider.of<HealthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Heart Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _heartC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Heart Rate', suffixText: 'bpm'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _logVitals('heart_rate'),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                    child: const Text('Log Record'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Trend Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          _buildChartContainer(health.heartRateRecords, 'heart_rate', colorScheme),
        ],
      ),
    );
  }

  // --- Weight Tracker Screen ---
  Widget _buildWeightPage(bool isDark) {
    final health = Provider.of<HealthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Record Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _weightC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _logVitals('weight'),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                    child: const Text('Log Record'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Trend Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          _buildChartContainer(health.weightRecords, 'weight', colorScheme),
        ],
      ),
    );
  }

  // --- High-Fidelity fl_chart dynamic assembler ---
  Widget _buildChartContainer(dynamic recordsList, String type, ColorScheme colorScheme) {
    if (recordsList == null || recordsList.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: const Text('No records logged yet. Graph trend will plot here.'),
      );
    }

    final spots = <FlSpot>[];
    final systolicSpots = <FlSpot>[]; // Specifically for blood pressure double line

    for (int i = 0; i < recordsList.length; i++) {
      final rec = recordsList[i];
      final val = rec.value;
      if (type == 'blood_pressure') {
        systolicSpots.add(FlSpot(i.toDouble(), (val['systolic'] ?? 120).toDouble()));
        spots.add(FlSpot(i.toDouble(), (val['diastolic'] ?? 80).toDouble()));
      } else {
        spots.add(FlSpot(i.toDouble(), (val['value'] ?? 0).toDouble()));
      }
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (type == 'blood_pressure')
              LineChartBarData(
                spots: systolicSpots,
                isCurved: true,
                color: Colors.red,
                barWidth: 3,
                dotData: const FlDotData(show: true),
              ),
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 3.5,
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}
