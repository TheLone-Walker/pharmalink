import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const primary = Color(0xFF0D6E48); // Deep Medical Emerald
  static const primaryDark = Color(0xFF084930);
  static const primaryLight = Color(0xFF10B981); // Bright Mint
  static const accent = Color(0xFF0284C7); // Clinical Cyan
  static const accentLight = Color(0xFFE0F2FE);
  
  // Backgrounds & Surfaces
  static const scaffoldBg = Color(0xFFF8FAFC); // Slate Ultra-light
  static const cardBg = Colors.white;
  static const lightGreen = Color(0xFFE8F5E9);
  static const lightMint = Color(0xFFECFDF5);
  static const fieldBg = Color(0xFFF8FAFC);
  static const fieldBorder = Color(0xFFE2E8F0);
  static const fieldFocusBorder = Color(0xFF10B981);

  // Text Hierarchy
  static const textDark = Color(0xFF0F172A); // Slate 900
  static const textSubtle = Color(0xFF334155); // Slate 700
  static const textGrey = Color(0xFF64748B); // Slate 500
  static const textMuted = Color(0xFF94A3B8); // Slate 400

  // State & Indicators
  static const white = Colors.white;
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D6E48), Color(0xFF065F46), Color(0xFF047857)],
  );

  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF0D6E48), Color(0xFF0284C7)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, Color(0xFFF8FAFC)],
  );

  // Shadows
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 16,
      spreadRadius: -2,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: const Color(0xFF0D6E48).withOpacity(0.20),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppConstants {
  static const baseUrl = 'http://localhost:3000/api';
  static const socketUrl = 'http://localhost:3000';
  static const double buttonHeight = 52.0;
  static const double fieldRadius = 12.0;
  static const double cardRadius = 24.0;
  static const String appName = 'PharmaLink';
  static const String tagline = 'Modern Digital Healthcare & Pharmacy Delivery';

  static const List<String> cameroonHospitals = [
    'Hôpital Central de Yaoundé',
    'Centre Hospitalier Universitaire (CHU) Yaoundé',
    'Hôpital Général de Yaoundé',
    'Fondation Chantal Biya, Yaoundé',
    'Clinique Bastos, Yaoundé',
    'Hôpital Jamot de Yaoundé',
    'Hôpital Gynéco-Obstétrique et Pédiatrique de Yaoundé (HGOPY)',
    'Hôpital de District de Biyem-Assi',
    'Hôpital de District de Cité Verte',
    'Hôpital de District d\'Efoulan',
    'Hôpital de District de Djoungolo',
    'Hôpital Militaire de Yaoundé',
    'Centre Médical la Cathédrale, Yaoundé',
    'Polyclinique Sainte Anne, Yaoundé',
    'Clinique du Rond-Point, Yaoundé',
    'Clinique Médicale le Jourdain, Yaoundé',
    'Hôpital Protestant de Yaoundé (Djoungolo)',
    'Hôpital de District de Nkolndongo',
    'Hôpital de District d\'Oyom-Abang',
    'Centre Médical d\'Arrondissement de Mvog-Ada',
    'Hôpital Général de Douala',
    'Hôpital Laquintinie de Douala',
    'Hôpital Régional de Bafoussam',
    'Hôpital Régional de Garoua',
    'Hôpital Régional de Bamenda',
  ];

  static const List<String> cameroonMedications = [
    'Artemether 80mg',
    'Artemether-Lumefantrine 20/120mg (Coartem)',
    'Artemether 80/480mg Forte',
    'Artemether Injection 80mg/ml',
    'Artesunate 50mg / Amodiaquine 153mg',
    'Paracetamol 500mg',
    'Paracetamol 1000mg (Efferalgan)',
    'Amoxicillin 500mg',
    'Amoxicillin-Clavulanate 1g (Augmentin)',
    'Ciprofloxacin 500mg',
    'Azithromycin 500mg (Zithromax)',
    'Ibuprofen 400mg',
    'Diclofenac 50mg (Voltaren)',
    'Omeprazole 20mg',
    'Metformin 500mg',
    'Metformin 850mg (Glucophage)',
    'Amlodipine 5mg',
    'Amlodipine 10mg',
    'Cetirizine 10mg (Zyrtec)',
    'Loratadine 10mg',
    'Metronidazole 500mg (Flagyl)',
    'Doxycycline 100mg',
    'Zinc Sulfate 20mg',
    'Oral Rehydration Salts (ORS)',
    'Vitamin C 1000mg',
    'Tramadol 50mg',
    'Salbutamol Inhaler 100mcg (Ventolin)',
    'Glibenclamide 5mg',
    'Captopril 25mg',
    'Losartan 50mg',
    'Furosemide 40mg (Lasix)',
    'Tramadol 50mg / Paracetamol 325mg',
    'Mebendazole 100mg (Vermox)',
    'Albendazole 400mg',
  ];

  static const List<String> cameroonMedicalSpecialties = [
    'General Practitioner',
    'Cardiology',
    'Pediatrics',
    'Gynecology & Obstetrics',
    'Dermatology',
    'Ophthalmology',
    'Neurology',
    'Orthopedics & Traumatology',
    'Gastroenterology',
    'Internal Medicine',
    'Pulmonology / Pneumology',
    'Psychiatry',
    'ENT / Otorhinolaryngology',
    'Urology',
    'Endocrinology',
    'Oncology',
    'Anesthesiology',
    'Radiology',
  ];

  static const List<String> cameroonMedicationCategories = [
    'Antimalarials',
    'Pain Relief & Analgesics',
    'Antibiotics',
    'Anti-inflammatory',
    'Gastric & Ulcer',
    'Diabetes & Metabolism',
    'Cardiovascular & Hypertension',
    'Allergies & Antihistamines',
    'Respiratory & Cough',
    'Vitamins & Supplements',
    'Pediatric Healthcare',
    'First Aid & Antiseptics',
  ];
}
