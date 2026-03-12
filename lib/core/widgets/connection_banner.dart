import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ConnectionBanner extends StatelessWidget {
  final bool connected;

  const ConnectionBanner({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.usb, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Connexion taka"),
              Text(
                connected ? "Connecté" : "Non connecté",
                style: TextStyle(
                  color: connected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
