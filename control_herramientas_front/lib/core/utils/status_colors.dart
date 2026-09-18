import 'package:flutter/material.dart';

class StatusColors {
  static Color getColor(String state) {
    switch (state.trim().toUpperCase()) {
      case 'APROBADO':
      case 'APTO':
        return const Color(0xff10b981);
      case 'VENCIDO':
        return const Color(0xffef4444);
      case 'REPARACION':
        return const Color(0xfff59e0b);
      case 'EN USO':
        return const Color(0xff06b6d4);
      case 'BAJA':
        return Colors.grey;
      case 'DE REFERENCIA':
        return Colors.purpleAccent;
      case 'NO EXISTE':
        return const Color(0xFFFFD54F);
      case 'NO APTO':
        return Colors.orangeAccent;
      default:
        return Colors.blueGrey;
    }
  }
}
