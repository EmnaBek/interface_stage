import 'package:flutter/material.dart';

class ValidationPage extends StatelessWidget {
  const ValidationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Validation")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _actionCard(
              icon: Icons.check_circle,
              title: "Valider prestation",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.pending_actions,
              title: "Demandes en attente",
              onTap: () {},
            ),
            _actionCard(
              icon: Icons.history_toggle_off,
              title: "Historique validations",
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
