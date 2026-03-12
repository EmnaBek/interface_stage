import 'package:flutter/material.dart';

class PrestationsPage extends StatelessWidget {
  const PrestationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prestations enregistrées")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _actionCard(
              icon: Icons.add_box,
              title: "Ajouter prestation",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.history,
              title: "Historique des prestations",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.search,
              title: "Rechercher prestation",
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
