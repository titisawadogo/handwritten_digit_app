import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;

// Custom painter for drawing
class DrawingPainter extends CustomPainter {
  final List<Offset?> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  String result = "";
  String confirmation = '';
  late Interpreter _interpreter;
  List<Offset?> points = [];
  bool isDrawing = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset("assets/mnist_improved.tflite",
          options: options);
      // ignore: avoid_print
      print("Model loaded successfully");
    } catch (e) {
      // ignore: avoid_print
      print("Failed to load model: $e");
    }
  }

  Future<void> recognizeDrawing() async {
    if (points.isEmpty) return;

    try {
      // Convert drawing to image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw white background
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 280, 280),
        Paint()..color = Colors.white,
      );

      // Draw the digit in black
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 28.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < points.length - 1; i++) {
        if (points[i] != null && points[i + 1] != null) {
          canvas.drawLine(points[i]!, points[i + 1]!, paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(280, 280);
      final pngBytes = await img.toByteData(format: ImageByteFormat.png);

      if (pngBytes == null) return;

      // Save to temp file and process
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/drawn_digit.png');
      await tempFile.writeAsBytes(pngBytes.buffer.asUint8List());

      // Process and get prediction
      var input = processImage(tempFile);
      var output = List.filled(1 * 10, 0.0).reshape([1, 10]);

      _interpreter.run(input, output);

      // Find the digit with highest confidence
      int maxIndex = 0;
      double maxValue = output[0][0];
      for (int i = 1; i < output[0].length; i++) {
        if (output[0][i] > maxValue) {
          maxValue = output[0][i];
          maxIndex = i;
        }
      }

      setState(() {
        result = "$maxIndex";

        confirmation = '${(maxValue * 100).toStringAsFixed(1)}%';
      });
    } catch (e) {
      // ignore: avoid_print
      print("Error during recognition: $e");
      setState(() {
        result = "Error recognizing digit";
      });
    }
  }

  List<List<List<List<double>>>> processImage(File file) {
    // Read and decode image
    final bytes = file.readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception("Failed to decode image");

    // Convert to grayscale and resize
    var processed = img.grayscale(image);

    processed = img.copyResize(processed, width: 28, height: 28);

    // Convert to normalized array
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
          "Reconnaissance par écrit",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white,
              ),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    isDrawing = true;
                    points.add(details.localPosition);
                  });
                },
                onPanUpdate: (details) {
                  if (isDrawing) {
                    setState(() {
                      points.add(details.localPosition);
                    });
                  }
                },
                onPanEnd: (details) {
                  setState(() {
                    isDrawing = false;
                    points.add(null);
                  });
                },
                child: CustomPaint(
                  painter: DrawingPainter(points),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Résultat:  ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: recognizeDrawing,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Valider'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    points.clear();
                    result = "";
                    confirmation = "";
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text('Effacer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
