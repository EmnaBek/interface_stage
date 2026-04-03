import 'package:flutter/material.dart';
import '../../../core/widgets/dashboard_tile.dart';
import '../../../core/widgets/connection_banner.dart';
import '../../../app/routes.dart';
import '../../../core/session/user_session.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _hasAutoOpenedScanner = false;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasAutoOpenedScanner) return;
    _hasAutoOpenedScanner = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.qrTokenValidation);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              
              /// LOGOS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset("assets/logo_ministere.png", height: 40),
                  Image.asset("assets/logo_arch.png", height: 40),
                ],
              ),

              const SizedBox(height: 16),

              /// CENTER TITLE
              ValueListenableBuilder<String?>(
                valueListenable: UserSession.displayName,
                builder: (BuildContext context, String? displayName, Widget? _) {
                  final String title = (displayName != null && displayName.trim().isNotEmpty)
                      ? displayName.trim()
                      : 'CS Ahomey Lokpo';
                  return Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),


              const SizedBox(height: 16),

              /// CONNECTION
              const ConnectionBanner(connected: true),

              const SizedBox(height: 20),

              /// GRID FEATURES
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: [

                    DashboardTile(
                      icon: Icons.receipt_long,
                      title: "Caisse",
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.caisse),
                    ),

                    DashboardTile(
                      icon: Icons.local_hospital,
                      title: "Hospitalisation",
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.hospitalisation),
                    ),

                    DashboardTile(
                      icon: Icons.assignment,
                      title: "Prestations enregistrées",
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.prestations),
                    ),

                    DashboardTile(
                      icon: Icons.check_circle,
                      title: "Validation",
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.validation),
                    ),

                    DashboardTile(
                      icon: Icons.menu_book,
                      title: "Référentiel",
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.referentiel),
                    ),

                    DashboardTile(
                      icon: Icons.warning,
                      title: "Réclamation",
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.reclamation),
                    ),

                    DashboardTile(
                      icon: Icons.qr_code_scanner,
                      title: "Scan QR Token",
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.qrTokenValidation),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
