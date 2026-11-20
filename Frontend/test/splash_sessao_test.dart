// Abertura do app: se a sessão salva não puder ser lida (armazenamento
// seguro com erro ou travado), o app mostra o login em vez de carregar
// para sempre.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/features/auth/ui/screens/login_screen.dart';
import 'package:tecsys_app/features/auth/ui/screens/splash_gate.dart';

void main() {
  testWidgets('leitura da sessão com erro → mostra o login', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashGate(restaurar: () async => throw Exception('chave perdida')),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('leitura da sessão travada → mostra o login no tempo limite', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashGate(
        restaurar: () => Completer<void>().future, // nunca termina
        limiteRestauracao: const Duration(seconds: 2),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
