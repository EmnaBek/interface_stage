import 'package:flutter/material.dart';

class PharmaciePage extends StatelessWidget {
  const PharmaciePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pharmacie")),
      body: const Center(child: Text("Module pharmacie")),
    );
  }
}
