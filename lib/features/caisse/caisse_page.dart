import 'package:flutter/material.dart';
import 'acte_consultation_page.dart';
import 'pharmacie_page.dart';
import 'laboratoire_page.dart';
import 'radio_page.dart';

class CaissePage extends StatelessWidget {
  const CaissePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            /// LOGOS EN HAUT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    "assets/logo_ministere.png",
                    height: 45,
                  ),
                  Image.asset(
                    "assets/logo_arch.png",
                    height: 45,
                  ),
                ],
              ),
            ),

            /// SERVICES OCCUPENT TOUT L'ECRAN
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    _serviceBlock(
                      icon: Icons.favorite,
                      title: "Acte et consultation",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ActeConsultationPage(),
                          ),
                        );
                      },
                    ),

                    _serviceBlock(
                      icon: Icons.medication,
                      title: "Pharmacie",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PharmaciePage(),
                          ),
                        );
                      },
                    ),

                    _serviceBlock(
                      icon: Icons.science,
                      title: "Laboratoire",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LaboratoirePage(),
                          ),
                        );
                      },
                    ),

                    _serviceBlock(
                      icon: Icons.camera_alt,
                      title: "Radio",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RadioPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WIDGET BLOC SERVICE (grand, centré)
  Widget _serviceBlock({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFD7EBDD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Icon(
                  icon,
                  size: 38,
                  color: const Color(0xFF4CAF93),
                ),

                const SizedBox(height: 10),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
