import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math' as math;

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({super.key});

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  String result = "";
  String confirmation = "";
  late Interpreter _interpreter;
  late List<String> labels;
  XFile? _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadMLModel();
  }

  Future<void> loadMLModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset("assets/mnist_improved.tflite",
          options: options);
      // ignore: avoid_print
      print("Model loaded successfully");

      String labelsData = await rootBundle.loadString('assets/labels.txt');
      labels = labelsData.split('\n').map((e) => e.trim()).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Failed to load model or labels: $e");
    }
  }

  Future<void> _imageFromGallery() async {
    var image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 400,
      maxWidth: 400,
      imageQuality: 100,
    );
    if (image == null) return;

    setState(() {
      _image = image;
    });

    runModelOnImage(File(_image!.path));
  }

  void runModelOnImage(File image) async {
    try {
      var results = await Future.wait([
        _getPrediction(_processImageNormal(image), "Normal"),
        _getPrediction(_processImageHighContrast(image), "High Contrast"),
        _getPrediction(_processImageAdaptive(image), "Adaptive"),
      ]);

      var bestResult =
          results.reduce((a, b) => a.confidence > b.confidence ? a : b);

      setState(() {
        result = "${bestResult.digit}";

        confirmation = "${(bestResult.confidence * 100).toStringAsFixed(1)}%";
      });
    } catch (e) {
      // ignore: avoid_print
      print("Error during inference: $e");
      setState(() {
        result = "Error during inference: $e";
      });
    }
  }

  Future<({int digit, double confidence, String method})> _getPrediction(
      List<List<List<List<double>>>> input, String method) async {
    var output = List.filled(1 * 10, 0.0).reshape([1, 10]);
    _interpreter.run(input, output);

    int maxIndex = 0;
    double maxValue = output[0][0];
    for (int i = 1; i < output[0].length; i++) {
      if (output[0][i] > maxValue) {
        maxValue = output[0][i];
        maxIndex = i;
      }
    }

    return (digit: maxIndex, confidence: maxValue, method: method);
  }

  List<List<List<List<double>>>> _processImageNormal(File image) {
    final rawImage = File(image.path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(rawImage);
    if (originalImage == null) throw Exception("Failed to decode image");

    var grayscaled = img.grayscale(originalImage);

    var resized = img.copyResize(grayscaled, width: 28, height: 28);

    return _createInputArray(resized);
  }

  List<List<List<List<double>>>> _processImageHighContrast(File image) {
    final rawImage = File(image.path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(rawImage);
    if (originalImage == null) throw Exception("Failed to decode image");

    var grayscaled = img.grayscale(originalImage);

    var contrasted = img.contrast(grayscaled, 200);
    if (contrasted == null) throw Exception("Failed to adjust contrast");

    var resized = img.copyResize(contrasted, width: 28, height: 28);

    return _createInputArray(resized);
  }

  List<List<List<List<double>>>> _processImageAdaptive(File image) {
    final rawImage = File(image.path).readAsBytesSync();
    img.Image? originalImage = img.decodeImage(rawImage);
    if (originalImage == null) throw Exception("Failed to decode image");

    var grayscaled = img.grayscale(originalImage);

    var enhanced = img.contrast(grayscaled, 150);
    if (enhanced == null) throw Exception("Failed to enhance contrast");

    int minX = enhanced.width, minY = enhanced.height;
    int maxX = 0, maxY = 0;
    // ignore: unused_local_variable
    double totalIntensity = 0;
    // ignore: unused_local_variable
    int pixelCount = 0;
    bool foundDigit = false;

    int threshold = 160; // Higher threshold to catch more of the digit

    for (int y = 0; y < enhanced.height; y++) {
      for (int x = 0; x < enhanced.width; x++) {
        int intensity = enhanced.getPixel(x, y) & 0xFF;
        totalIntensity += intensity;
        pixelCount++;

        if (intensity < threshold) {
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
          foundDigit = true;
        }
      }
    }

    if (!foundDigit) {
      threshold = 180;
      minX = enhanced.width;
      minY = enhanced.height;
      maxX = 0;
      maxY = 0;

      for (int y = 0; y < enhanced.height; y++) {
        for (int x = 0; x < enhanced.width; x++) {
          int intensity = enhanced.getPixel(x, y) & 0xFF;
          if (intensity < threshold) {
            minX = math.min(minX, x);
            minY = math.min(minY, y);
            maxX = math.max(maxX, x);
            maxY = math.max(maxY, y);
            foundDigit = true;
          }
        }
      }
    }

    int padding = 30;
    minX = math.max(0, minX - padding);
    minY = math.max(0, minY - padding);
    maxX = math.min(enhanced.width - 1, maxX + padding);
    maxY = math.min(enhanced.height - 1, maxY + padding);

    var cropped =
        img.copyCrop(enhanced, minX, minY, maxX - minX + 1, maxY - minY + 1);

    for (int y = 0; y < cropped.height; y++) {
      for (int x = 0; x < cropped.width; x++) {
        int intensity = cropped.getPixel(x, y) & 0xFF;
        // More gradual thresholding
        int newValue = intensity < threshold
            ? math.max(0, (intensity * 0.5).round())
            : math.min(255, (intensity * 1.2).round());
        cropped.setPixel(x, y, newValue | (newValue << 8) | (newValue << 16));
      }
    }

    var resized = img.copyResize(cropped, width: 28, height: 28);

    return _createInputArray(resized);
  }

  List<List<List<List<double>>>> _createInputArray(img.Image processed) {
    return List.generate(
      1,
      (b) => List.generate(
        28,
        (y) => List.generate(
          28,
          (x) => List.generate(
            1,
            (c) {
              int pixel = processed.getPixel(x, y);
              double value = (pixel & 0xFF) / 255.0;
              return 1.0 - value; // Invert for MNIST format
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Reconnaissance par image",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(_image!.path),
                    height: 280,
                    width: 280,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                  color: Colors.white,
                ),
                child: const Center(
                    child: Icon(
                  Icons.image_not_supported_rounded,
                  size: 80,
                  color: Colors.black38,
                )),
              ),
            const SizedBox(height: 20),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Résultat:  ',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      result,
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Confirmation à:  ',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      confirmation,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _imageFromGallery,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Selectionner une image'),
            ),
          ],
        ),
      ),
    );
  }
}
