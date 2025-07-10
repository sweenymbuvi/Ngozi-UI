import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

// Import tflite_flutter for mobile platforms
import 'package:tflite_flutter/tflite_flutter.dart';

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
  bool _isProcessing = false;
  double _confidence = 0.0;
  String _riskLevel = '';

  // TensorFlow Lite variables (only for mobile)
  Interpreter? _interpreter; // Change to Interpreter type
  List<String> _labels = [
    'Actinic keratoses',
    'Basal cell carcinoma',
    'Benign keratosis-like lesions',
    'Dermatofibroma',
    'Melanoma',
    'Melanocytic nevi',
    'Vascular lesions'
  ];

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

    // Load model only on mobile platforms
    if (!kIsWeb) {
      _loadModel();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (!kIsWeb && _interpreter != null) {
      _interpreter!.close();
    }
    super.dispose();
  }

  // Load the TensorFlow Lite model (mobile only)
  Future<void> _loadModel() async {
    if (kIsWeb) return;

    try {
      // Load the model from assets
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print('Model loaded successfully');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  // Preprocess image for model input
  Float32List _preprocessImage(Uint8List imageBytes) {
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    // Resize to model input size (100x75 based on your training)
    img.Image resizedImage = img.copyResize(image, width: 100, height: 75);

    // Convert to Float32List and normalize
    Float32List input = Float32List(1 * 75 * 100 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 75; y++) {
      for (int x = 0; x < 100; x++) {
        // Get pixel - handle different image package versions
        dynamic pixel = resizedImage.getPixel(x, y);

        double r, g, b;
        if (pixel is img.Pixel) {
          // Newer image package versions
          r = pixel.r / 255.0;
          g = pixel.g / 255.0;
          b = pixel.b / 255.0;
        } else {
          // Older image package versions
          int pixelInt = pixel as int;
          r = ((pixelInt >> 16) & 0xFF) / 255.0;
          g = ((pixelInt >> 8) & 0xFF) / 255.0;
          b = (pixelInt & 0xFF) / 255.0;
        }

        input[pixelIndex++] = r;
        input[pixelIndex++] = g;
        input[pixelIndex++] = b;
      }
    }

    return input;
  }

  Future<Map<String, dynamic>> _runInference(Uint8List imageBytes) async {
    if (kIsWeb) {
      // Web fallback - simulate prediction
      return _simulateWebPrediction();
    }

    if (_interpreter == null) {
      throw Exception('Model not loaded');
    }

    // Preprocess image
    Float32List input = _preprocessImage(imageBytes);

    // Prepare input tensor - already in correct shape [1, 75, 100, 3]
    var inputTensor = input.reshape([1, 75, 100, 3]);

    // Prepare output tensor with correct shape [1, 7]
    var output = List.filled(1 * 7, 0.0).reshape([1, 7]);

    // Run inference
    _interpreter!.run(inputTensor, output);

    // Get predictions - output is now in shape [1,7]
    List<double> predictions = output[0]; // Get first (and only) batch

    // Find the class with highest probability
    int maxIndex = 0;
    double maxConfidence = predictions[0];

    for (int i = 1; i < predictions.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        maxIndex = i;
      }
    }

    String predictedClass = _labels[maxIndex];

    // Determine risk level based on prediction and confidence
    String riskLevel = _determineRiskLevel(predictedClass, maxConfidence);

    return {
      'prediction': predictedClass,
      'confidence': maxConfidence,
      'risk_level': riskLevel,
      'all_predictions': predictions,
    };
  }

  // Web fallback simulation
  Future<Map<String, dynamic>> _simulateWebPrediction() async {
    // Simulate processing delay
    await Future.delayed(Duration(seconds: 2));

    // Generate random prediction for demo purposes
    final random = math.Random();
    int randomIndex = random.nextInt(_labels.length);
    double randomConfidence = 0.6 + random.nextDouble() * 0.3; // 60-90%

    String predictedClass = _labels[randomIndex];
    String riskLevel = _determineRiskLevel(predictedClass, randomConfidence);

    return {
      'prediction': predictedClass,
      'confidence': randomConfidence,
      'risk_level': riskLevel,
      'all_predictions': List.generate(
          7,
          (i) =>
              i == randomIndex ? randomConfidence : random.nextDouble() * 0.4),
    };
  }

  // Determine risk level based on prediction and confidence
  String _determineRiskLevel(String prediction, double confidence) {
    // High-risk conditions
    if (prediction == 'Melanoma' || prediction == 'Basal cell carcinoma') {
      return 'High Risk';
    }

    // Medium-risk conditions
    if (prediction == 'Actinic keratoses' ||
        (prediction == 'Benign keratosis-like lesions' && confidence < 0.8)) {
      return 'Medium Risk';
    }

    // Low-risk conditions with high confidence
    if (confidence > 0.8) {
      return 'Low Risk';
    }

    // Default to medium risk for uncertain cases
    return 'Medium Risk';
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
          _confidence = 0.0;
          _riskLevel = '';
        });
      } else {
        // For mobile platforms
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
          _prediction = null;
          _confidence = 0.0;
          _riskLevel = '';
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
          _confidence = 0.0;
          _riskLevel = '';
        });
      } else {
        // For mobile platforms
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
          _prediction = null;
          _confidence = 0.0;
          _riskLevel = '';
        });
      }
      _animationController.forward();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null && _webImage == null) return;

    if (!kIsWeb && _interpreter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model not loaded yet. Please try again.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      Uint8List imageBytes;

      if (kIsWeb && _webImage != null) {
        imageBytes = _webImage!;
      } else if (_image != null) {
        imageBytes = await _image!.readAsBytes();
      } else {
        throw Exception('No image available');
      }

      // Run inference
      Map<String, dynamic> result = await _runInference(imageBytes);

      setState(() {
        _prediction = result['prediction'];
        _confidence = result['confidence'];
        _riskLevel = result['risk_level'];
      });
    } catch (e) {
      print('Error during inference: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing image: $e')),
      );
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
                      kIsWeb ? 'Demo Mode (Web)' : 'AI-Powered Visual Analysis',
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
                        // Platform indicator
                        if (kIsWeb)
                          Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Running in demo mode. Use mobile app for AI analysis.',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

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

  // Rest of your UI building methods remain the same...
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
