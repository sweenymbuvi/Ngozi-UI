import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SkinDiseaseHome(),
    );
  }
}

class SkinDiseaseHome extends StatefulWidget {
  @override
  _SkinDiseaseHomeState createState() => _SkinDiseaseHomeState();
}

class _SkinDiseaseHomeState extends State<SkinDiseaseHome> {
  File? _image;
  String? _prediction;
  String? _segmentedImageUrl;

  final picker = ImagePicker();

  Future pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
      await sendToModel(_image!);
    }
  }

  Future sendToModel(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://YOUR-BACKEND-URL/predict'),
    );
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));
    var res = await request.send();
    var response = await res.stream.bytesToString();
    var data = json.decode(response);

    setState(() {
      _prediction = data['prediction'];
      _segmentedImageUrl =
          data['segmentation_url']; // if you return a URL from the backend
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Skin Disease Visual Triage')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickImage,
              child: Text("Upload Skin Image"),
            ),
            SizedBox(height: 16),
            if (_image != null) Image.file(_image!, height: 200),
            if (_prediction != null)
              Text("Prediction: $_prediction", style: TextStyle(fontSize: 18)),
            if (_segmentedImageUrl != null) Image.network(_segmentedImageUrl!),
          ],
        ),
      ),
    );
  }
}
