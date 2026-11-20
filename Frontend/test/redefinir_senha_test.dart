// Redefinir senha: troca pelo próprio usuário (menu da conta), tela de
// "Esqueceu a senha?" do login e a ação do administrador em Usuários.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/core/network/api_exception.dart';
import 'package:tecsys_app/features/auth/ui/screens/reset_password_screen.dart';
import 'package:tecsys_app/features/users/data/models/user_model.dart';
import 'package:tecsys_app/features/users/ui/widgets/users/users_list_view.dart';

Future<void> _abrir(WidgetTester tester, ResetPasswordScreen tela) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => tela)),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _preencher(WidgetTester tester, String chave, String texto) =>
    tester.enterText(
        find.descendant(of: find.byKey(Key(chave)), matching: find.byType(TextField)),
        texto);

Future<void> _salvar(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('redefinir-senha-acao')));
  await tester.pumpAndSettle();
}

void main() {
  group('logado: troca a própria senha', () {
    testWidgets('valida antes de chamar o servidor', (tester) async {
      var chamadas = 0;
      await _abrir(tester, ResetPasswordScreen(onRedefinir: (_, __) async => chamadas++));

      await _salvar(tester);
      expect(find.text('Informe a senha atual.'), findsOneWidget);

      await _preencher(tester, 'campo-senha-atual', 'antiga1');
      await _preencher(tester, 'campo-nova-senha', '123');
      await _salvar(tester);
      expect(find.text('A nova senha deve ter no mínimo 6 caracteres.'), findsOneWidget);

      await _preencher(tester, 'campo-nova-senha', 'nova123');
      await _preencher(tester, 'campo-confirmar-senha', 'outra12');
      await _salvar(tester);
      expect(find.text('As senhas não coincidem.'), findsOneWidget);

      await _preencher(tester, 'campo-nova-senha', 'antiga1');
      await _preencher(tester, 'campo-confirmar-senha', 'antiga1');
      await _salvar(tester);
      expect(find.text('A nova senha precisa ser diferente da atual.'), findsOneWidget);

      expect(chamadas, 0);
    });

    testWidgets('senha válida: envia atual e nova, fecha e avisa', (tester) async {
      String? atual, nova;
      await _abrir(tester, ResetPasswordScreen(onRedefinir: (a, n) async {
        atual = a;
        nova = n;
      }));
      await _preencher(tester, 'campo-senha-atual', 'antiga1');
      await _preencher(tester, 'campo-nova-senha', 'nova123');
      await _preencher(tester, 'campo-confirmar-senha', 'nova123');
      await _salvar(tester);

      expect((atual, nova), ('antiga1', 'nova123'));
      expect(find.byType(ResetPasswordScreen), findsNothing);
      expect(find.text('Senha redefinida com sucesso.'), findsOneWidget);
    });

    testWidgets('senha atual errada: mostra a mensagem do servidor', (tester) async {
      await _abrir(tester, ResetPasswordScreen(onRedefinir: (_, __) async {
        throw ApiException(422, 'A senha atual está incorreta.');
      }));
      await _preencher(tester, 'campo-senha-atual', 'errada1');
      await _preencher(tester, 'campo-nova-senha', 'nova123');
      await _preencher(tester, 'campo-confirmar-senha', 'nova123');
      await _salvar(tester);

      expect(find.text('A senha atual está incorreta.'), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });
  });

  testWidgets('esqueceu a senha (login): explica o caminho pelo administrador', (tester) async {
    await _abrir(tester, const ResetPasswordScreen(fromLogin: true));
    expect(find.text('Esqueceu a senha?'), findsOneWidget);
    expect(find.textContaining('administrador'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Send Reset Link'), findsNothing);

    await _salvar(tester); // "Voltar para o login"
    expect(find.byType(ResetPasswordScreen), findsNothing);
  });

  testWidgets('Usuários: chave de redefinir senha só no perfil Usuário', (tester) async {
    const usuario = AppUser(id: 2, name: 'Ana', email: 'ana@tecsys.com', role: UserRoleType.user);
    const admin = AppUser(id: 3, name: 'Bia', email: 'bia@tecsys.com', role: UserRoleType.adm);
    AppUser? pedido;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: UsersListView(
            members: const [usuario, admin],
            hasAnyUser: true,
            grid: false,
            onDelete: (_) {},
            onResetPassword: (m) => pedido = m,
          ),
        ),
      ),
    ));

    expect(find.byKey(const Key('redefinir-senha-2')), findsOneWidget);
    expect(find.byKey(const Key('redefinir-senha-3')), findsNothing);
    await tester.tap(find.byKey(const Key('redefinir-senha-2')));
    expect(pedido?.id, 2);
  });
}
