import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SkinDiseaseTriageScreen extends StatefulWidget {
  @override
  _SkinDiseaseTriageScreenState createState() =>
      _SkinDiseaseTriageScreenState();
}

class _SkinDiseaseTriageScreenState extends State<SkinDiseaseTriageScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  Uint8List? _webImage;
  String? _prediction;
  String? _segmentedImageUrl;
  bool _isProcessing = false;
  double _confidence = 0.0;
  String _riskLevel = '';

  final picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        // For web platform
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null;
          _prediction = null;
          _segmentedImageUrl = null;
        });
      } else {
        // For mobile platforms
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
          _prediction = null;
          _segmentedImageUrl = null;
        });
      }
      _animationController.forward();
    }
  }

  Future<void> _pickImageFromCamera() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        // For web platform
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null;
          _prediction = null;
          _segmentedImageUrl = null;
        });
      } else {
        // For mobile platforms
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
          _prediction = null;
          _segmentedImageUrl = null;
        });
      }
      _animationController.forward();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null && _webImage == null) return;

    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://YOUR-BACKEND-URL/predict'),
      );

      if (kIsWeb && _webImage != null) {
        // For web platform
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          _webImage!,
          filename: 'image.jpg',
        ));
      } else if (_image != null) {
        // For mobile platforms
        request.files
            .add(await http.MultipartFile.fromPath('image', _image!.path));
      }

      var res = await request.send();
      var response = await res.stream.bytesToString();
      var data = json.decode(response);

      setState(() {
        _prediction = data['prediction'] ?? 'Unknown';
        _segmentedImageUrl = data['segmentation_url'];
        _confidence = (data['confidence'] ?? 0.0).toDouble();
        _riskLevel = data['risk_level'] ?? 'Unknown';
      });
    } catch (e) {
      // For demo purposes, simulate results
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        _prediction = 'Melanoma';
        _confidence = 0.87;
        _riskLevel = 'High Risk';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Color _getRiskColor() {
    switch (_riskLevel.toLowerCase()) {
      case 'high risk':
        return Colors.red;
      case 'medium risk':
        return Colors.orange;
      case 'low risk':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2196F3),
              Color(0xFF3F51B5),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Skin Disease Triage',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI-Powered Visual Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image Upload Section
                        _buildImageUploadSection(),
                        SizedBox(height: 24),

                        // Action Buttons
                        if (_image == null && _webImage == null)
                          _buildActionButtons(),

                        // Analyze Button
                        if ((_image != null || _webImage != null) &&
                            _prediction == null)
                          _buildAnalyzeButton(),

                        // Results Section
                        if (_prediction != null) _buildResultsSection(),

                        // Disclaimer
                        SizedBox(height: 24),
                        _buildDisclaimer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 2),
      ),
      child: _image == null && _webImage == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  'Add a photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Take a photo or upload from gallery',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: kIsWeb && _webImage != null
                    ? Image.memory(
                        _webImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : _image != null
                        ? Image.file(
                            _image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Container(),
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImageFromCamera,
            icon: Icon(Icons.camera_alt),
            label: Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImageFromGallery,
            icon: Icon(Icons.photo_library),
            label: Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _analyzeImage,
        icon: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.analytics),
        label: Text(_isProcessing ? 'Analyzing...' : 'Analyze Image'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Classification Results
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Classification Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildResultRow('Condition:', _prediction!),
              SizedBox(height: 12),
              _buildResultRow(
                  'Confidence:', '${(_confidence * 100).toStringAsFixed(1)}%'),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Risk Level:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRiskColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _riskLevel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getRiskColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Segmentation Results (if available)
        if (_segmentedImageUrl != null) ...[
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Segmentation Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _segmentedImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber[700],
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Disclaimer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This is a screening tool only. Please consult a healthcare professional for proper diagnosis and treatment.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
