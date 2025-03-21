import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:kilimomkononi/models/field_data_model.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';

class PlotInputForm extends StatefulWidget {
  final String userId;
  final String plotId;
  final String structureType;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const PlotInputForm({
    required this.userId,
    required this.plotId,
    required this.structureType,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<PlotInputForm> createState() => _PlotInputFormState();
}

class _PlotInputFormState extends State<PlotInputForm> {
  final _formKey = GlobalKey<FormState>();
  bool _useAcres = true;
  List<Map<String, String>> _crops = [];
  List<TextEditingController> _cropControllers = [];
  final _areaController = TextEditingController();
  final _nitrogenController = TextEditingController();
  final _phosphorusController = TextEditingController();
  final _potassiumController = TextEditingController();
  List<String> _microNutrients = [];
  List<TextEditingController> _microNutrientControllers = [TextEditingController()];
  final List<Map<String, dynamic>> _interventions = [];
  final List<Map<String, dynamic>> _reminders = [];

  final List<String> _acreFractions = [
    '1/8 Acre', '1/6 Acre', '1/4 Acre', '1/3 Acre', '1/2 Acre', '2/3 Acre',
    '3/4 Acre', '1 Acre', '1 1/2 Acres', '2 Acres', '3 Acres', '4 Acres'
  ];

  final Map<String, List<String>> _cropStages = {
    'Maize': ['Planting (Early Growth)', 'Emergence (Early Growth)', 'Propagation (Early Growth)', 'Tasseling (Mid Growth)', 'Silking (Reproductive)', 'Maturity (Reproductive)'],
    'Beans': ['Planting (Vegetative)', 'Emergence (Vegetative)', 'Flowering (Reproductive)', 'Pod Development (Reproductive)'],
    'Tomatoes': ['Planting (Early Growth)', 'Emergence (Early Growth)', 'Flowering (Reproductive)', 'Fruit Set (Reproductive)', 'Maturation (Reproductive)'],
    'Cassava': ['Planting (Establishment)', 'Emergence (Establishment)', 'Maturity (Maturation)'],
    'Rice': ['Planting (Early Growth)', 'Tillering (Mid Growth)', 'Panicle Initiation (Mid Growth)', 'Grain Filling (Reproductive)', 'Maturity (Reproductive)'],
    'Potatoes': ['Planting (Early Growth)', 'Tuber Initiation (Mid Growth)', 'Bulking (Reproductive)', 'Maturation (Reproductive)'],
    'Wheat': ['Planting (Early Growth)', 'Tillering (Mid Growth)', 'Stem Elongation (Mid Growth)', 'Grain Filling (Reproductive)', 'Maturity (Reproductive)'],
    'Cabbages/Kales': ['Planting (Early Growth)', 'Leaf Development (Mid Growth)', 'Head Formation (Reproductive)', 'Maturation (Reproductive)'],
    'Sugarcane': ['Planting (Early Growth)', 'Tillering (Mid Growth)', 'Cane Elongation (Mid Growth)', 'Ripening (Reproductive)'],
    'Carrots': ['Planting (Early Growth)', 'Emergence (Early Growth)', 'Root Expansion (Mid Growth)', 'Maturation (Reproductive)'],
  };

  final Map<String, Map<String, Map<String, double>>> _optimalNpk = {
    'Maize': {
      'Early Growth': {'N': 45, 'P': 28, 'K': 56},
      'Mid Growth': {'N': 84, 'P': 28, 'K': 56},
      'Reproductive': {'N': 0, 'P': 0, 'K': 28},
    },
    'Beans': {
      'Vegetative': {'N': 28, 'P': 45, 'K': 56},
      'Reproductive': {'N': 28, 'P': 0, 'K': 56},
    },
    'Tomatoes': {
      'Early Growth': {'N': 67, 'P': 78, 'K': 101},
      'Reproductive': {'N': 0, 'P': 0, 'K': 56},
    },
    'Cassava': {
      'Establishment': {'N': 0, 'P': 28, 'K': 0},
      'Maturation': {'N': 0, 'P': 0, 'K': 0},
    },
    'Rice': {
      'Early Growth': {'N': 50, 'P': 40, 'K': 50},
      'Mid Growth': {'N': 0, 'P': 0, 'K': 0},
      'Reproductive': {'N': 0, 'P': 0, 'K': 40},
    },
    'Potatoes': {
      'Early Growth': {'N': 62, 'P': 75, 'K': 115},
      'Mid Growth': {'N': 0, 'P': 0, 'K': 0},
      'Reproductive': {'N': 0, 'P': 0, 'K': 60},
    },
    'Wheat': {
      'Early Growth': {'N': 55, 'P': 55, 'K': 50},
      'Mid Growth': {'N': 0, 'P': 0, 'K': 0},
      'Reproductive': {'N': 0, 'P': 0, 'K': 40},
    },
    'Cabbages/Kales': {
      'Early Growth': {'N': 65, 'P': 70, 'K': 90},
      'Mid Growth': {'N': 0, 'P': 0, 'K': 0},
      'Reproductive': {'N': 0, 'P': 0, 'K': 50},
    },
    'Sugarcane': {
      'Early Growth': {'N': 90, 'P': 70, 'K': 105},
      'Mid Growth': {'N': 0, 'P': 0, 'K': 0},
      'Reproductive': {'N': 0, 'P': 0, 'K': 60},
    },
    'Carrots': {
      'Early Growth': {'N': 50, 'P': 65, 'K': 90},
      'Mid Growth': {'N': 0, 'P': 0, 'K': 0},
      'Reproductive': {'N': 0, 'P': 0, 'K': 50},
    },
  };

  final Map<String, Map<String, String>> _fertilizerRecommendations = {
    'Maize': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Nitrate (34-0-0)',
      'Mid Growth': 'NPK 20-20-20 or 10-20-20',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Beans': {
      'Vegetative': 'Triple Superphosphate (0-46-0) or DAP (18-46-0)',
      'Reproductive': 'Muriate of Potash (0-0-60), Urea (46-0-0)',
    },
    'Tomatoes': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Reproductive': 'NPK 10-20-20 or 12-24-12, Muriate of Potash (0-0-60)',
    },
    'Cassava': {
      'Establishment': 'Triple Superphosphate (0-46-0)',
      'Maturation': '',
    },
    'Rice': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Mid Growth': 'NPK 16-20-0 or 10-26-26',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Potatoes': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Nitrate (34-0-0)',
      'Mid Growth': 'NPK 10-20-20 or 14-28-14',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Wheat': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Mid Growth': 'NPK 18-46-0 (DAP) or 12-24-12',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Cabbages/Kales': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Mid Growth': 'NPK 10-20-20 or 14-28-14',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Sugarcane': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Mid Growth': 'NPK 14-28-14 or 12-24-12',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Carrots': {
      'Early Growth': 'Ammonium Nitrate (34-0-0) or Ammonium Sulfate (21-0-0)',
      'Mid Growth': 'NPK 10-20-20 or 14-28-14',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
  };

  final Map<String, String> _nutrientStatus = {};

  @override
  void initState() {
    super.initState();
    _initializeCropFields();
  }

  void _initializeCropFields() {
    if (widget.structureType == 'intercrop' && _crops.isEmpty) {
      setState(() {
        _crops = [
          {'type': '', 'stage': ''},
          {'type': '', 'stage': ''},
        ];
        _cropControllers = [
          TextEditingController(),
          TextEditingController(),
        ];
      });
    } else if (_crops.isEmpty) {
      setState(() {
        _crops = [{'type': '', 'stage': ''}];
        _cropControllers = [TextEditingController()];
      });
    }
  }

  Future<void> _saveForm() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _microNutrients = _microNutrientControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

      for (int i = 0; i < _cropControllers.length; i++) {
        if (_cropControllers[i].text.isNotEmpty) {
          _crops[i]['type'] = _cropControllers[i].text;
        }
      }
      _crops = _crops.where((crop) => crop['type']!.isNotEmpty).toList();

      double? areaInAcres;
      if (_areaController.text.isNotEmpty) {
        if (_useAcres) {
          final text = _areaController.text;
          if (_acreFractions.contains(text)) {
            areaInAcres = _convertFractionToAcres(text);
          } else {
            areaInAcres = double.tryParse(text);
          }
        } else {
          areaInAcres = double.parse(_areaController.text) / 4046.86;
        }
      }

      try {
        final fieldData = FieldData(
          userId: widget.userId,
          plotId: widget.plotId,
          crops: _crops,
          area: areaInAcres,
          npk: {
            'N': _nitrogenController.text.isNotEmpty ? double.parse(_nitrogenController.text) : null,
            'P': _phosphorusController.text.isNotEmpty ? double.parse(_phosphorusController.text) : null,
            'K': _potassiumController.text.isNotEmpty ? double.parse(_potassiumController.text) : null,
          },
          microNutrients: _microNutrients,
          interventions: _interventions,
          reminders: _reminders,
          timestamp: Timestamp.now(),
          structureType: widget.structureType,
        );
        await FirebaseFirestore.instance
            .collection('fielddata')
            .doc(widget.userId)
            .collection('plots')
            .doc(widget.plotId)
            .collection('entries')
            .add(fieldData.toMap());
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('New data saved successfully')));
          _resetForm();
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error saving data: $e')));
        }
      }
    }
  }

  void _resetForm() {
    setState(() {
      _areaController.clear();
      _nitrogenController.clear();
      _phosphorusController.clear();
      _potassiumController.clear();
      _microNutrients.clear();
      _microNutrientControllers = [TextEditingController()];
      _interventions.clear();
      _reminders.clear();
      _nutrientStatus.clear();
      _initializeCropFields();
    });
  }

  double _convertFractionToAcres(String fraction) {
    if (fraction.contains('Acre')) {
      final parts = fraction.split(' ');
      if (parts.length == 1) return 1.0;
      if (parts[0].contains('/')) {
        final frac = parts[0].split('/');
        return double.parse(frac[0]) / double.parse(frac[1]);
      }
      return double.parse(parts[0]);
    }
    return double.parse(fraction);
  }

  Future<void> _scheduleReminder(DateTime date, String activity) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    const androidDetails = AndroidNotificationDetails(
      'field_data_channel',
      'Field Data Reminders',
      channelDescription: 'Reminders for field activities',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    final tzDateTime = tz.TZDateTime.from(date, tz.local);
    final tzDayBefore = tz.TZDateTime.from(date.subtract(const Duration(days: 1)), tz.local);

    try {
      await widget.notificationsPlugin.zonedSchedule(
        (widget.userId + widget.plotId + date.toString()).hashCode,
        'Reminder for ${widget.plotId}',
        activity,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      await widget.notificationsPlugin.zonedSchedule(
        ('${widget.userId}${widget.plotId}${date}dayBefore').hashCode,
        'Upcoming Reminder for ${widget.plotId}',
        'Reminder: $activity is due tomorrow!',
        tzDayBefore,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Reminders scheduled successfully')));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error scheduling reminder: $e')));
      }
    }
  }

  void _compareNutrients(String crop, String stage) {
    final growthStage = stage.split('(')[1].replaceAll(')', '');
    final optimal = _optimalNpk[crop]?[growthStage];
    if (optimal == null) return;

    setState(() {
      _nutrientStatus.clear();
      final n = _nitrogenController.text.isNotEmpty ? double.parse(_nitrogenController.text) : 0;
      final p = _phosphorusController.text.isNotEmpty ? double.parse(_phosphorusController.text) : 0;
      final k = _potassiumController.text.isNotEmpty ? double.parse(_potassiumController.text) : 0;

      _nutrientStatus['N'] = n < optimal['N']! ? 'Lower' : n > optimal['N']! ? 'Higher' : 'Optimal';
      _nutrientStatus['P'] = p < optimal['P']! ? 'Lower' : p > optimal['P']! ? 'Higher' : 'Optimal';
      _nutrientStatus['K'] = k < optimal['K']! ? 'Lower' : k > optimal['K']! ? 'Higher' : 'Optimal';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Crop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._cropControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              TextEditingController controller = entry.value;
              return Column(
                children: [
                  TextFormField(
                    controller: controller,
                    decoration: _inputDecoration('Crop Type'),
                    validator: (value) => widget.structureType == 'intercrop' && idx < 2 && (value == null || value.isEmpty) ? 'Required for Intercrop' : null,
                    onChanged: (value) {
                      if (idx < _crops.length) {
                        _crops[idx]['type'] = value;
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildCropStageField(idx),
                  const SizedBox(height: 8),
                ],
              );
            }),
            if (widget.structureType == 'intercrop')
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _crops.add({'type': '', 'stage': ''});
                    _cropControllers.add(TextEditingController());
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('+ Additional Crop'),
              ),
            const SizedBox(height: 16),

            const Text('Plot Area', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _useAcres
                ? Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                      return _acreFractions.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      _areaController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _areaController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _inputDecoration('Area (Acres)'),
                        keyboardType: TextInputType.text,
                        validator: (value) => value != null && value.isNotEmpty && !_acreFractions.contains(value) && double.tryParse(value) == null ? 'Enter a valid number or fraction' : null,
                      );
                    },
                  )
                : TextFormField(
                    controller: _areaController,
                    decoration: _inputDecoration('Area (SQM)'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null ? 'Enter a valid number' : null,
                  ),
            SwitchListTile(
              title: const Text('Use Acres'),
              value: _useAcres,
              onChanged: (value) => setState(() => _useAcres = value),
              activeColor: Colors.green[300],
            ),
            const SizedBox(height: 16),

            const Text('Soil Nutrient Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._buildNutrientFields(),
            const SizedBox(height: 16),

            const Text('Micro-Nutrients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Column(
              children: [
                ..._microNutrientControllers.map((controller) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextFormField(
                    controller: controller,
                    decoration: _inputDecoration('Micro-Nutrient'),
                    onFieldSubmitted: (value) {
                      if (value.isNotEmpty && !_microNutrients.contains(value)) {
                        setState(() => _microNutrients.add(value));
                      }
                    },
                  ),
                )),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _microNutrientControllers.add(TextEditingController()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Another Micro-Nutrient'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _microNutrients.map((m) => Chip(
                label: Text(m),
                onDeleted: () => setState(() => _microNutrients.remove(m)),
              )).toList(),
            ),
            const SizedBox(height: 16),

            const Text('Interventions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final intervention = await _showInterventionDialog();
                if (intervention != null) setState(() => _interventions.add(intervention));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Intervention'),
            ),
            const SizedBox(height: 8),
            ..._interventions.map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('${i['type']} - ${i['quantity']} ${i['unit']}'),
                subtitle: Text((i['date'] as Timestamp).toDate().toString().substring(0, 10)),
              ),
            )),
            const SizedBox(height: 16),

            const Text('Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final reminder = await _showReminderDialog();
                if (reminder != null) {
                  setState(() => _reminders.add(reminder));
                  await _scheduleReminder(reminder['date'].toDate(), reminder['activity']);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Reminder'),
            ),
            const SizedBox(height: 8),
            ..._reminders.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(r['activity']),
                subtitle: Text(r['date'].toDate().toString().substring(0, 10)),
              ),
            )),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _saveForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save New Entry', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlotSummaryTab(userId: widget.userId, plotIds: [widget.plotId]),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Summary'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNutrientFields() {
    final crop = _crops.isNotEmpty && _crops[0]['type']!.isNotEmpty ? _crops[0]['type'] : '';
    final stage = _crops.isNotEmpty && _crops[0]['stage']!.isNotEmpty ? _crops[0]['stage'] : '';
    final growthStage = stage!.isNotEmpty ? stage.split('(')[1].replaceAll(')', '') : '';
    final optimal = _optimalNpk[crop]?[growthStage] ?? {'N': 0.0, 'P': 0.0, 'K': 0.0};
    final fertilizer = _fertilizerRecommendations[crop]?[growthStage] ?? '';

    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _nitrogenController,
                decoration: _inputDecoration('Nitrogen (N)'),
                keyboardType: TextInputType.number,
                validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null ? 'Enter a valid number' : null,
                onChanged: (_) => _compareNutrients(crop!, stage),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Text(
                'Optimal: ${optimal['N']}',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
      if (_nutrientStatus['N'] != null)
        Text(
          'N Status: ${_nutrientStatus['N']}',
          style: TextStyle(
            color: _nutrientStatus['N'] == 'Lower' ? Colors.red : _nutrientStatus['N'] == 'Higher' ? Colors.orange : Colors.green,
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _phosphorusController,
                decoration: _inputDecoration('Phosphorus (P)'),
                keyboardType: TextInputType.number,
                validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null ? 'Enter a valid number' : null,
                onChanged: (_) => _compareNutrients(crop!, stage),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Text(
                'Optimal: ${optimal['P']}',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
      if (_nutrientStatus['P'] != null)
        Text(
          'P Status: ${_nutrientStatus['P']}',
          style: TextStyle(
            color: _nutrientStatus['P'] == 'Lower' ? Colors.red : _nutrientStatus['P'] == 'Higher' ? Colors.orange : Colors.green,
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _potassiumController,
                decoration: _inputDecoration('Potassium (K)'),
                keyboardType: TextInputType.number,
                validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null ? 'Enter a valid number' : null,
                onChanged: (_) => _compareNutrients(crop!, stage),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Text(
                'Optimal: ${optimal['K']}',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
      if (_nutrientStatus['K'] != null)
        Text(
          'K Status: ${_nutrientStatus['K']}',
          style: TextStyle(
            color: _nutrientStatus['K'] == 'Lower' ? Colors.red : _nutrientStatus['K'] == 'Higher' ? Colors.orange : Colors.green,
          ),
        ),
      if (fertilizer.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Recommended Fertilizer: $fertilizer',
            style: const TextStyle(fontSize: 14, color: Colors.blue),
          ),
        ),
    ];
  }

  Widget _buildCropStageField(int index) {
    final crop = _crops[index]['type'];
    final stages = _cropStages[crop] ?? ['Planting', 'Emergence', 'Propagation'];

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return stages;
        }
        return stages.where((stage) => stage.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        setState(() {
          if (index < _crops.length) {
            _crops[index]['stage'] = selection;
            _compareNutrients(crop!, selection);
          }
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: _inputDecoration('Crop Stage'),
          onFieldSubmitted: (value) {
            if (value.isNotEmpty && index < _crops.length) {
              setState(() {
                _crops[index]['stage'] = value;
                _compareNutrients(crop!, value);
              });
            }
            onFieldSubmitted();
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  Future<Map<String, dynamic>?> _showInterventionDialog() async {
    String? type;
    String? quantityText;
    String? unit;
    DateTime? date = DateTime.now();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Intervention'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: _inputDecoration('Intervention Type'),
                  onChanged: (value) => type = value,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  decoration: _inputDecoration('Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantityText = value,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitController,
                  decoration: _inputDecoration('Unit'),
                  onChanged: (value) => unit = value,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Date: ${date!.toString().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final quantity = quantityText != null && quantityText!.isNotEmpty ? double.tryParse(quantityText!) : null;
              if (type != null && type!.isNotEmpty) {
                Navigator.pop(context, {
                  'type': type,
                  'quantity': quantity,
                  'unit': unit,
                  'date': Timestamp.fromDate(date!),
                });
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showReminderDialog() async {
    DateTime? date = DateTime.now().add(const Duration(days: 7));
    String? activity;
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Reminder'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: _inputDecoration('Activity'),
                onChanged: (v) => activity = v,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Date: ${date!.toString().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date!,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && mounted) setState(() => date = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'date': Timestamp.fromDate(date!),
              'activity': activity,
            }),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}