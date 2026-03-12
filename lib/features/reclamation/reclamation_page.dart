import 'package:flutter/material.dart';

class ReclamationPage extends StatelessWidget {
  const ReclamationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Réclamation")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _actionCard(
              icon: Icons.report_problem,
              title: "Nouvelle réclamation",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.list_alt,
              title: "Mes réclamations",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.support_agent,
              title: "Support",
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
