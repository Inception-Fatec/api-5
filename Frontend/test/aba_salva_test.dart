// #TG-145: o F5 volta na aba em que o usuário estava, respeitando o RN04.

import 'package:flutter_test/flutter_test.dart';

import 'package:tecsys_app/app/navigation/aba_salva.dart';

void main() {
  test('ADM volta na aba salva', () {
    expect(indiceInicialDaAba('projetos', isAdmin: true), 0);
    expect(indiceInicialDaAba('usuarios', isAdmin: true), 1);
    expect(indiceInicialDaAba('etl', isAdmin: true), 2);
  });

  test('sem aba salva ou aba desconhecida abre Projetos', () {
    expect(indiceInicialDaAba(null, isAdmin: true), 0);
    expect(indiceInicialDaAba('qualquer', isAdmin: true), 0);
  });

  test('perfil sem acesso à aba salva (RN04) abre Projetos', () {
    expect(indiceInicialDaAba('usuarios', isAdmin: false), 0);
    expect(indiceInicialDaAba('etl', isAdmin: false), 0);
  });

  test('chaves seguem a ordem das abas do perfil', () {
    expect(chavesDasAbas(isAdmin: true), ['projetos', 'usuarios', 'etl']);
    expect(chavesDasAbas(isAdmin: false), ['projetos']);
  });
}
