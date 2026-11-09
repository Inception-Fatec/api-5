// Testes de fumaça do app (#TG-108): substituem o teste de exemplo do
// contador que o Flutter cria, que sempre falhava porque o app não tem
// contador.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/auth/data/services/auth_service.dart';
import 'package:tecsys_app/features/auth/data/services/token_storage.dart';
import 'package:tecsys_app/main.dart';

/// JWT só com o payload (a assinatura não é conferida no front).
String jwt({required int exp}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': 'teste@tecsys.com.br', 'exp': exp})}.assinatura';
}

int agoraEmSegundos() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Future<void> abrirApp(WidgetTester tester) async {
  await tester.pumpWidget(const TecsysApp());
  await tester.pumpAndSettle();
}

void expectTelaDeLogin() {
  expect(find.text('E-mail'), findsOneWidget);
  expect(find.text('Senha'), findsOneWidget);
  expect(find.text('Entrar'), findsOneWidget);
  expect(find.text('Esqueceu a senha?'), findsOneWidget);
}

void main() {
  testWidgets('sem sessão salva, o app abre na tela de login', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await abrirApp(tester);

    expectTelaDeLogin();
  });

  testWidgets('com token vencido, o app abre no login e apaga a sessão salva', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': jwt(exp: agoraEmSegundos() - 60),
      'auth_role': 'ADM',
      'auth_email': 'admin@tecsys.com.br',
    });

    await abrirApp(tester);

    expectTelaDeLogin();
    expect(await TokenStorage.instance.readToken(), isNull);
    expect(AuthService.instance.isAuthenticated, isFalse);
  });

  group('AuthService.tokenExpirado', () {
    test('token com exp no passado está vencido', () {
      expect(AuthService.tokenExpirado(jwt(exp: agoraEmSegundos() - 60)), isTrue);
    });

    test('token com exp no futuro é válido', () {
      expect(AuthService.tokenExpirado(jwt(exp: agoraEmSegundos() + 3600)), isFalse);
    });

    test('token ilegível conta como vencido', () {
      expect(AuthService.tokenExpirado('isso-nao-e-um-jwt'), isTrue);
    });
  });
}
