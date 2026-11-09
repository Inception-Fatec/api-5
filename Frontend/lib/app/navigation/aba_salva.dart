export 'aba_salva_stub.dart' if (dart.library.js_interop) 'aba_salva_web.dart';

/// Chaves das abas do [AppShell], na mesma ordem de `NavItems.forRole`
/// (sem a Conta): é o que fica salvo para o F5 voltar na mesma aba (#TG-145).
List<String> chavesDasAbas({required bool isAdmin}) => [
      'projetos',
      if (isAdmin) 'usuarios',
      if (isAdmin) 'etl',
    ];

/// Aba para abrir ao iniciar: a salva, se o perfil puder vê-la (RN04);
/// senão a primeira (Projetos).
int indiceInicialDaAba(String? salva, {required bool isAdmin}) {
  final i = chavesDasAbas(isAdmin: isAdmin).indexOf(salva ?? '');
  return i < 0 ? 0 : i;
}
