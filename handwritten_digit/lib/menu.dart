import 'package:flutter/material.dart';
import 'package:handwritten_digit/drawing_screen.dart';
import 'package:handwritten_digit/image_upload_screen.dart';
import 'package:lottie/lottie.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              'Handwritten digit recognition App',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Par Thierry Sawadogo',
              style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/hi.json', width: 350, height: 350),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Choisissez une option:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () {
                //ImageUploadPage
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const ImageUploadPage()));
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text("Reconnaissance par import d'image"),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () {
                //DrawingScreen
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const DrawingPage()));
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text("Reconnaissance par écrit"),
            )
          ],
        ),
      ),
    );
  }
}
