import 'package:flutter/material.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/caisse/caisse_page.dart';
import '../features/hospitalisation/hospitalisation_page.dart';
import '../features/prestations/prestations_page.dart';
import '../features/validation/validation_page.dart';
import '../features/referentiel/referentiel_page.dart';
import '../features/reclamation/reclamation_page.dart';

class AppRoutes {
  static const dashboard = '/';
  static const caisse = '/caisse';
  static const hospitalisation = '/hospitalisation';
  static const prestations = '/prestations';
  static const validation = '/validation';
  static const referentiel = '/referentiel';
  static const reclamation = '/reclamation';

  static Map<String, WidgetBuilder> routes = {
    dashboard: (_) => const DashboardPage(),
    caisse: (_) => const CaissePage(),
    hospitalisation: (_) => const HospitalisationPage(),
    prestations: (_) => const PrestationsPage(),
    validation: (_) => const ValidationPage(),
    referentiel: (_) => const ReferentielPage(),
    reclamation: (_) => const ReclamationPage(),
  };
}
