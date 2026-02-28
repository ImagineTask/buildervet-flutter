import 'package:flutter/material.dart';

enum ParticipantRole {
  homeowner,
  contractor,
  designer,
  electrician,
  plumber,
  gasEngineer,
  labourer,
  inspector,
  landscapeDesigner,
  other;

  String get label {
    switch (this) {
      case ParticipantRole.homeowner:
        return 'Homeowner';
      case ParticipantRole.contractor:
        return 'Contractor';
      case ParticipantRole.designer:
        return 'Designer';
      case ParticipantRole.electrician:
        return 'Electrician';
      case ParticipantRole.plumber:
        return 'Plumber';
      case ParticipantRole.gasEngineer:
        return 'Gas Engineer';
      case ParticipantRole.labourer:
        return 'Labourer';
      case ParticipantRole.inspector:
        return 'Inspector';
      case ParticipantRole.landscapeDesigner:
        return 'Landscape Designer';
      case ParticipantRole.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ParticipantRole.homeowner:
        return Icons.home;
      case ParticipantRole.contractor:
        return Icons.construction;
      case ParticipantRole.designer:
        return Icons.palette;
      case ParticipantRole.electrician:
        return Icons.electrical_services;
      case ParticipantRole.plumber:
        return Icons.plumbing;
      case ParticipantRole.gasEngineer:
        return Icons.local_fire_department;
      case ParticipantRole.labourer:
        return Icons.engineering;
      case ParticipantRole.inspector:
        return Icons.verified;
      case ParticipantRole.landscapeDesigner:
        return Icons.park;
      case ParticipantRole.other:
        return Icons.person;
    }
  }

  static ParticipantRole fromString(String value) {
    switch (value) {
      case 'homeowner':
        return ParticipantRole.homeowner;
      case 'contractor':
        return ParticipantRole.contractor;
      case 'designer':
        return ParticipantRole.designer;
      case 'electrician':
        return ParticipantRole.electrician;
      case 'plumber':
        return ParticipantRole.plumber;
      case 'gas_engineer':
        return ParticipantRole.gasEngineer;
      case 'labourer':
        return ParticipantRole.labourer;
      case 'inspector':
        return ParticipantRole.inspector;
      case 'landscape_designer':
        return ParticipantRole.landscapeDesigner;
      default:
        return ParticipantRole.other;
    }
  }
}
