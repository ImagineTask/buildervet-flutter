import 'package:flutter/material.dart';

class DomainConfig {
  final String domainId;
  final String requesterLabel;
  final String executorLabel;
  final IconData requesterIcon;
  final IconData executorIcon;
  final String searchHint;
  final List<Map<String, String>> aiSuggestions;

  const DomainConfig({
    required this.domainId,
    required this.requesterLabel,
    required this.executorLabel,
    required this.requesterIcon,
    required this.executorIcon,
    required this.searchHint,
    required this.aiSuggestions,
  });
}

class DomainRegistry {
  // Configured domains
  static const homeServices = DomainConfig(
    domainId: 'home_services',
    requesterLabel: 'Homeowner',
    executorLabel: 'Builder',
    requesterIcon: Icons.home_outlined,
    executorIcon: Icons.construction_outlined,
    searchHint: 'Describe a new home project with AI...',
    aiSuggestions: [
      {'label': '🍳 Kitchen renovation', 'prompt': 'I need a full kitchen renovation including new cabinets, plumbing, and electrical'},
      {'label': '🚿 Bathroom refresh', 'prompt': 'I need a bathroom renovation with new shower, tiling, and plumbing'},
      {'label': '🏠 Loft conversion', 'prompt': 'I want to convert my loft into a bedroom with en-suite bathroom'},
      {'label': '🧱 Extension', 'prompt': 'I need a single storey rear extension for a larger kitchen-diner'},
    ],
  );

  static const restaurant = DomainConfig(
    domainId: 'restaurant',
    requesterLabel: 'Boss',
    executorLabel: 'Employee',
    requesterIcon: Icons.storefront_outlined,
    executorIcon: Icons.badge_outlined,
    searchHint: 'Manage restaurant tasks with AI...',
    aiSuggestions: [
      {'label': '👨‍🍳 Hire a Chef', 'prompt': 'We need to hire and onboard a new Head Chef for the evening shifts'},
      {'label': '📋 Menu Update', 'prompt': 'Plan a new seasonal summer menu and organise ingredients ordering'},
      {'label': '🧹 Deep Clean', 'prompt': 'Schedule a full kitchen deep clean before the health inspection this Friday'},
      {'label': '🥳 Private Event', 'prompt': 'Organise staffing and prep for a private birthday party of 50 guests next Saturday'},
    ],
  );

  static const medical = DomainConfig(
    domainId: 'medical',
    requesterLabel: 'Hospital',
    executorLabel: 'Supplier',
    requesterIcon: Icons.local_hospital_outlined,
    executorIcon: Icons.local_shipping_outlined,
    searchHint: 'Generate medical supply and duty tasks...',
    aiSuggestions: [
      {'label': '🩺 Supply Order', 'prompt': 'Order 50 boxes of surgical masks and 20 bottles of sanitizer'},
      {'label': '🚑 Maintenance', 'prompt': 'Schedule quarterly maintenance for the MRI and X-Ray machines'},
    ],
  );

  // Active domain - this could be fetached from SharedPreferences or Firebase
  // For now, we statically assign the Active Domain here. Change to 'restaurant' to test the Restaurant domain.
  static DomainConfig current = restaurant; 

  static void setDomain(DomainConfig config) {
    current = config;
  }
}
