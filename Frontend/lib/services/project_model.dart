import 'package:flutter/material.dart';


class Project {
  final int id;
  final String name;
  final String distCode;
  final String status;
  final int createdById;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.name,
    required this.distCode,
    required this.status,
    required this.createdById,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      distCode: json['dist_code'] as String? ?? '',
      status: json['status'] as String? ?? 'CRIADO',
      createdById: json['created_by_id'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get criadoPorLabel => 'Usuário #$createdById';

  String get dataFormatada =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}
class ProjectStatusStyle {
  static String label(String status) {
    switch (status) {
      case 'CRIADO':
        return 'Criado';
      case 'ENVIADO':
        return 'Enviado';
      case 'PROCESSANDO':
        return 'Processando';
      case 'SUCESSO':
        return 'Concluído';
      case 'FALHA':
        return 'Falha';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'SUCESSO':
        return const Color(0xFF1E9E5A);
      case 'FALHA':
        return const Color(0xFFD64545);
      case 'PROCESSANDO':
        return const Color(0xFFE0A72E);
      case 'ENVIADO':
        return const Color(0xFF3A7BD5);
      case 'CRIADO':
      default:
        return const Color(0xFF8A93A6);
    }
  }
}