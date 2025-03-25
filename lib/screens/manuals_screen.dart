import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:kilimomkononi/home.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:open_file/open_file.dart';

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  String? _selectedPdfPath;
  bool _isLoading = false;
  String? _downloadedFilePath; 

  @override
  void dispose() {
    _cleanupTemporaryFile();
    super.dispose();
  }

  void _cleanupTemporaryFile() {
    if (_selectedPdfPath != null) {
      File(_selectedPdfPath!).deleteSync();
      _selectedPdfPath = null;
    }
  }

  Future<void> _readOnline(String url, String filename) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      setState(() => _selectedPdfPath = file.path);
    } catch (e) {
      _showErrorSnackBar('Error loading manual: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadFile(String url, String filename) async {
    setState(() => _isLoading = true);
    try {
      // Request storage permission (for Android)
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          _showErrorSnackBar('Storage permission denied. Cannot download file.');
          return;
        }
      }

      // Fetch the file from URL
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;

      // Save to Downloads directory
      final dir = Directory('/storage/emulated/0/Download'); // Android Downloads folder
      if (!await dir.exists()) {
        await dir.create(recursive: true); // Create if it doesn't exist
      }
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Update the downloaded file path
      setState(() => _downloadedFilePath = file.path);

      // Show success message and offer to open the file
      _showSuccessSnackBar('Manual downloaded to $_downloadedFilePath');
      _openDownloadedFile(); // Optional: Open the file after download
    } catch (e) {
      _showErrorSnackBar('Error downloading manual: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openDownloadedFile() {
    if (_downloadedFilePath != null) {
      OpenFile.open(_downloadedFilePath!); // Opens the file with the default app
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendRequest(String message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('Please log in to send a request');
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    final fullName = userDoc['fullName'] ?? 'Anonymous';
    await FirebaseFirestore.instance.collection('ManualRequests').add({
      'userId': user.uid,
      'fullName': fullName,
      'message': message,
      'timestamp': Timestamp.now(),
      'responded': false,
    });
    _showSuccessSnackBar('Request sent successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage())),
        ),
        title: const Text('Farming Manuals', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        elevation: 2,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildWelcomeAnimation(),
                _buildManualsList(),
                _buildRequestSection(),
                if (_selectedPdfPath != null) _buildPdfViewer(),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 3, 39, 4))),
        ],
      ),
    );
  }

  Widget _buildWelcomeAnimation() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.green[50],
      child: AnimatedTextKit(
        animatedTexts: [
          TyperAnimatedText(
            'Welcome to Farming Manuals!\nExplore expert-approved guides by agricultural specialists to boost your farming skills.',
            textStyle: const TextStyle(fontSize: 18, color: Color.fromARGB(255, 3, 39, 4), fontWeight: FontWeight.bold),
            speed: const Duration(milliseconds: 50),
          ),
        ],
        totalRepeatCount: 1,
      ),
    );
  }

  Widget _buildManualsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Manuals').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final manuals = snapshot.data!.docs;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(16.0),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: manuals.length,
            itemBuilder: (context, index) {
              final manual = manuals[index].data() as Map<String, dynamic>;
              final title = manual['title'] ?? 'Untitled';
              final filename = manual['filename'] ?? '';
              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Color.fromARGB(255, 3, 39, 4)),
                      onPressed: () async {
                        final url = await FirebaseStorage.instance.ref('manuals/$filename').getDownloadURL();
                        _readOnline(url, filename);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, color: Color.fromARGB(255, 3, 39, 4)),
                      onPressed: () async {
                        final url = await FirebaseStorage.instance.ref('manuals/$filename').getDownloadURL();
                        _downloadFile(url, filename);
                      },
                    ),
                  ],
                ),
                title: Text(title),
                trailing: const Icon(Icons.book, color: Color.fromARGB(255, 3, 39, 4)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPdfViewer() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SizedBox(
            height: 400,
            child: PDFView(
              filePath: _selectedPdfPath!,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: false,
              pageFling: false,
              onError: (error) => _showErrorSnackBar('Error viewing PDF: $error'),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadFile(_selectedPdfPath!, 'manual_${DateTime.now().millisecondsSinceEpoch}.pdf'),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 3, 39, 4), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Need a specific manual not available here? Request Admin to add here:',
                style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 3, 39, 4)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.message, color: Color.fromARGB(255, 3, 39, 4)),
              onPressed: () => _showRequestDialog(),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request a Manual'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter your request'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _sendRequest(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}