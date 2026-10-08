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
        return const Color(0xff0284c7);
      case 'BAJA':
        return const Color(0xff64748b);
      case 'DE REFERENCIA':
        return const Color(0xffa855f7);
      case 'NO EXISTE':
        return const Color(0xffeab308);
      case 'NO APTO':
        return const Color(0xfff97316);
      default:
        return const Color(0xff475569);
    }
  }
}
