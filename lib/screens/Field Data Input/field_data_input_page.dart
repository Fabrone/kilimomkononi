import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_input_form.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';

enum PageState { loading, noData, dataLoaded }

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
  PageState _pageState = PageState.loading;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _tabController = TabController(length: 1, vsync: this);
    _loadStructure();
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

  Future<void> _loadStructure() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != widget.userId) {
        throw Exception('User not authenticated or userId mismatch');
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedStructure = prefs.getString('farming_structure_${widget.userId}');
      final structureDoc = await FirebaseFirestore.instance
          .collection('user_structure')
          .doc(widget.userId)
          .get();

      if (structureDoc.exists) {
        final data = structureDoc.data()!;
        if (mounted) {
          setState(() {
            _farmingScenario = data['structureType'];
            _plotIds = List<String>.from(data['plotIds']);
            _tabController.dispose();
            _tabController = TabController(length: _plotIds.length, vsync: this);
            _pageState = PageState.dataLoaded;
          });
          await _checkPlotDataStatus();
        }
      } else if (cachedStructure != null) {
        final structure = cachedStructure.split('|');
        if (mounted) {
          setState(() {
            _farmingScenario = structure[0];
            _plotIds = structure[1].split(',').where((id) => id.isNotEmpty).toList();
            _tabController.dispose();
            _tabController = TabController(length: _plotIds.length, vsync: this);
            _pageState = PageState.dataLoaded;
          });
          await _checkPlotDataStatus();
        }
      } else {
        if (mounted) {
          setState(() => _pageState = PageState.noData);
          await _showOnboardingDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading structure: $e')),
        );
        setState(() => _pageState = PageState.noData);
        await _showOnboardingDialog();
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
      if (mounted) {
        setState(() {
          _plotHasData[plotId] = snapshot.docs.isNotEmpty;
        });
      }
    }
  }

  Future<void> _saveStructureToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('farming_structure_${widget.userId}', '$_farmingScenario|${_plotIds.join(',')}');
  }

  Future<void> _saveStructureToFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('user_structure')
          .doc(widget.userId)
          .set({'structureType': _farmingScenario, 'plotIds': _plotIds});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('farming_structure_${widget.userId}'); // Clear cache after saving to Firestore
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving structure: $e')),
        );
      }
    }
  }

  Future<void> _showOnboardingDialog() async {
    String? scenario;
    int? plotCount;
    String? plotLabelPrefix;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Define Your Farming Structure',
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
                if (mounted) {
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
                    _pageState = PageState.dataLoaded;
                  });
                  _saveStructureToCache(); // Cache locally
                  Navigator.pop(dialogContext, true);
                }
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a valid option')),
                );
              }
            },
            child: const Text('OK', style: TextStyle(color: Color.fromARGB(255, 3, 39, 4))),
          ),
        ],
      ),
    );

    if (result != true && mounted) {
      setState(() => _pageState = PageState.noData);
    }
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
      if (_plotHasData.values.every((hasData) => !hasData)) {
        _saveStructureToCache(); // Update cache if no data exists
      } else {
        await _saveStructureToFirestore(); // Update Firestore if data exists
      }
    }
  }

  void _showFieldHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlotSummaryTab(userId: widget.userId, plotIds: [], showAll: true),
      ),
    );
  }

  Widget _buildPlotInputForm(String plotId) {
    switch (_farmingScenario) {
      case 'multiple':
        return MultiplePlotForm(
          userId: widget.userId,
          plotId: plotId,
          structureType: _farmingScenario!,
          notificationsPlugin: _notificationsPlugin,
          onSave: _saveStructureToFirestore,
        );
      case 'intercrop':
        return IntercropForm(
          userId: widget.userId,
          plotId: plotId,
          structureType: _farmingScenario!,
          notificationsPlugin: _notificationsPlugin,
          onSave: _saveStructureToFirestore,
        );
      case 'single':
        return SingleCropForm(
          userId: widget.userId,
          plotId: plotId,
          structureType: _farmingScenario!,
          notificationsPlugin: _notificationsPlugin,
          onSave: _saveStructureToFirestore,
        );
      default:
        throw Exception('Unknown farming scenario: $_farmingScenario');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_pageState) {
      case PageState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case PageState.noData:
        return Scaffold(
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
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome! Let’s set up your farming structure.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showOnboardingDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Define Farming Structure'),
                ),
              ],
            ),
          ),
        );

      case PageState.dataLoaded:
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
                            return _buildPlotInputForm(plotId); // Use helper method to instantiate correct form
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
                            child: const Text('Retrieve History', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _plotHasData.values.every((hasData) => !hasData)
                ? FloatingActionButton(
                    onPressed: () => _deletePlot(_plotIds[_tabController.index]),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.delete),
                  )
                : null,
          ),
        );

      }
  }
}