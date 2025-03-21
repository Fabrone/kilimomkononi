import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_input_form.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';

class FieldDataInputPage extends StatefulWidget {
  final String userId;

  const FieldDataInputPage({required this.userId, super.key});

  @override
  State<FieldDataInputPage> createState() => _FieldDataInputPageState();
}

class _FieldDataInputPageState extends State<FieldDataInputPage> with SingleTickerProviderStateMixin {
  String? _farmingScenario;
  List<String> _plotIds = [];
  late TabController _tabController;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Map<String, bool> _plotHasData = {};

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _loadFarmingStructure();
    _tabController = TabController(length: _plotIds.isEmpty ? 1 : _plotIds.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _loadFarmingStructure() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final structureDoc = await FirebaseFirestore.instance
          .collection('user_structure')
          .doc(widget.userId)
          .get();
      if (!structureDoc.exists) {
        await _showOnboardingDialog();
      } else {
        final data = structureDoc.data()!;
        setState(() {
          _farmingScenario = data['structureType'];
          _plotIds = List<String>.from(data['plotIds']);
          _tabController.dispose();
          _tabController = TabController(length: _plotIds.length, vsync: this);
        });
        _checkPlotDataStatus();
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error loading structure: $e')));
      }
    }
  }

  Future<void> _checkPlotDataStatus() async {
    for (var plotId in _plotIds) {
      final snapshot = await FirebaseFirestore.instance
          .collection('fielddata')
          .doc(widget.userId)
          .collection('plots')
          .doc(plotId)
          .collection('entries')
          .get();
      setState(() {
        _plotHasData[plotId] = snapshot.docs.isNotEmpty;
      });
    }
  }

  Future<void> _showOnboardingDialog() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String? scenario;
    int? plotCount;
    String? plotLabelPrefix;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Choose Your Farming Structure',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 3, 39, 4)),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: scenario,
                  decoration: const InputDecoration(
                    labelText: 'Farming Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'multiple', child: Text('Multiple Plots')),
                    DropdownMenuItem(value: 'intercrop', child: Text('Intercropping')),
                    DropdownMenuItem(value: 'single', child: Text('Single Crop')),
                  ],
                  onChanged: (value) => setState(() => scenario = value),
                ),
                if (scenario == 'multiple') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Number of Plots',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => plotCount = int.tryParse(value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Plot Label Prefix',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) => plotLabelPrefix = value.isNotEmpty ? value : 'Plot',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (scenario != null && (scenario != 'multiple' || (plotCount != null && plotCount! > 0))) {
                setState(() {
                  _farmingScenario = scenario;
                  if (scenario == 'multiple') {
                    _plotIds = List.generate(
                      plotCount!,
                      (i) => '${plotLabelPrefix ?? 'Plot'} ${i + 1}',
                    );
                  } else if (scenario == 'intercrop') {
                    _plotIds = ['Intercrop'];
                  } else {
                    _plotIds = ['SingleCrop'];
                  }
                  _tabController.dispose();
                  _tabController = TabController(length: _plotIds.length, vsync: this);
                });
                FirebaseFirestore.instance
                    .collection('user_structure')
                    .doc(widget.userId)
                    .set({'structureType': scenario, 'plotIds': _plotIds});
                Navigator.pop(dialogContext);
              } else if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Please select a valid option')),
                );
              }
            },
            child: const Text('OK', style: TextStyle(color: Color.fromARGB(255, 3, 39, 4))),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlot(String plotId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete $plotId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _plotIds.remove(plotId);
        _plotHasData.remove(plotId);
        _tabController.dispose();
        _tabController = TabController(length: _plotIds.length, vsync: this);
      });
      await FirebaseFirestore.instance
          .collection('user_structure')
          .doc(widget.userId)
          .update({'plotIds': _plotIds});
      await FirebaseFirestore.instance
          .collection('fielddata')
          .doc(widget.userId)
          .collection('plots')
          .doc(plotId)
          .delete();
    }
  }

  void _showFieldHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlotSummaryTab(
          userId: widget.userId,
          plotIds: [],
          showAll: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_farmingScenario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: _plotIds.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Field Data Input',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            if (_plotIds.isNotEmpty)
              Container(
                color: const Color.fromARGB(255, 240, 244, 243),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: const Color.fromRGBO(67, 145, 67, 1),
                  tabs: _plotIds.map((plotId) => Tab(text: plotId)).toList(),
                ),
              ),
            Expanded(
              child: _plotIds.isEmpty
                  ? const Center(child: Text('No plots defined yet.'))
                  : TabBarView(
                      controller: _tabController,
                      children: _plotIds.map((plotId) {
                        return Stack(
                          children: [
                            PlotInputForm(
                              userId: widget.userId,
                              plotId: plotId,
                              structureType: _farmingScenario!,
                              notificationsPlugin: _notificationsPlugin,
                            ),
                            if (_plotHasData[plotId] == null || !_plotHasData[plotId]!)
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: FloatingActionButton(
                                  onPressed: () => _deletePlot(plotId),
                                  backgroundColor: Colors.red,
                                  child: const Icon(Icons.delete),
                                ),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ElevatedButton(
                        onPressed: _showOnboardingDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Redefine Structure', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ElevatedButton(
                        onPressed: _showFieldHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Retrieve Field History', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}