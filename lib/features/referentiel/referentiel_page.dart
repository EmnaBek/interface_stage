import 'package:flutter/material.dart';

class ReferentielPage extends StatelessWidget {
  const ReferentielPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Référentiel")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _actionCard(
              icon: Icons.medical_services,
              title: "Liste actes médicaux",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.local_pharmacy,
              title: "Médicaments",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.category,
              title: "Catégories",
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
