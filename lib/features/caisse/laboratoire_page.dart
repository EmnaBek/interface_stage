import 'package:flutter/material.dart';

class LaboratoirePage extends StatelessWidget {
  const LaboratoirePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laboratoire")),
      body: const Center(child: Text("Module laboratoire")),
    );
  }
}
