import 'package:flutter_test/flutter_test.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';

void main() {
  Map<String, dynamic> json({String? nome}) => {
        'id': 7,
        'name': 'Projeto',
        'dist_code': '391',
        'status': 'SUCESSO',
        'created_by_id': 1,
        if (nome != null) 'created_by_name': nome,
        'created_at': '2026-11-08T10:00:00Z',
      };

  test('usa o created_by_name que vem do backend', () {
    expect(Project.fromJson(json(nome: 'Admin Tecsys')).criadoPorLabel, 'Admin Tecsys');
  });

  test('sem nome (resposta antiga ou vazia) cai para "Usuário #id"', () {
    expect(Project.fromJson(json()).criadoPorLabel, 'Usuário #1');
    expect(Project.fromJson(json(nome: '  ')).criadoPorLabel, 'Usuário #1');
  });
}
