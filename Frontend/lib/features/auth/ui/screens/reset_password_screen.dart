import 'package:flutter/material.dart';

import 'package:tecsys_app/core/ajuda/ajuda.dart';
import 'package:tecsys_app/core/ajuda/textos_ajuda.dart';
import 'package:tecsys_app/core/network/api_exception.dart';
import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/features/auth/data/services/auth_service.dart';
import 'package:tecsys_app/features/auth/ui/widgets/auth_scaffold.dart';
import 'package:tecsys_app/features/auth/ui/widgets/auth_text_field.dart';

/// Troca a própria senha (POST /auth/update-password).
typedef RedefinirSenha = Future<void> Function(String atual, String nova);

/// "Redefinir Senha", no mesmo cartão do login ([AuthScaffold]).
///
/// - Pelo menu da conta (logado): troca a própria senha informando a atual.
/// - Pelo "Esqueceu a senha?" do login ([fromLogin]): o Tecsys não envia
///   e-mail, então a tela explica o caminho — um administrador define uma
///   senha temporária em Usuários e o sistema pede uma senha nova no próximo
///   acesso (o mesmo fluxo do primeiro acesso).
class ResetPasswordScreen extends StatefulWidget {
  final bool fromLogin;

  /// Para os testes; por padrão chama o backend.
  final RedefinirSenha? onRedefinir;

  const ResetPasswordScreen({super.key, this.fromLogin = false, this.onRedefinir});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  /// Mesmas regras do backend (UpdatePasswordDto e AuthService), checadas
  /// antes para o aviso aparecer na hora.
  String? _validar() {
    if (_atual.text.isEmpty) return 'Informe a senha atual.';
    if (_nova.text.length < 6) {
      return 'A nova senha deve ter no mínimo 6 caracteres.';
    }
    if (_nova.text != _confirmacao.text) return 'As senhas não coincidem.';
    if (_nova.text == _atual.text) {
      return 'A nova senha precisa ser diferente da atual.';
    }
    return null;
  }

  Future<void> _salvar() async {
    final erro = _validar();
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final redefinir =
          widget.onRedefinir ?? AuthService.instance.updatePassword;
      await redefinir(_atual.text, _nova.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Senha redefinida com sucesso.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível conectar ao servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esqueceu = widget.fromLogin;
    return AuthScaffold(
      card: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hub, color: AppColors.primary, size: 32),
              SizedBox(width: 8),
              Text('Tecsys',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              AjudaBotao(ajuda: TextosAjuda.redefinirSenha),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.lock_reset,
                  size: 28, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            esqueceu ? 'Esqueceu a senha?' : 'Redefinir senha',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            esqueceu
                ? 'Por segurança, a senha do Tecsys é redefinida por um '
                    'administrador do sistema.'
                : 'Confirme a senha atual e escolha uma senha nova.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (esqueceu) const _PassosEsqueceu() else ..._formulario(),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const Key('redefinir-senha-acao'),
              onPressed: esqueceu
                  ? () => Navigator.of(context).pop()
                  : (_salvando ? null : _salvar),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(esqueceu ? 'Voltar para o login' : 'Salvar nova senha',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          if (!esqueceu) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    size: 18, color: AppColors.textSecondary),
                label: const Text('Voltar',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _formulario() => [
        AuthTextField(
          key: const Key('campo-senha-atual'),
          label: 'Senha atual',
          hint: '••••••••',
          obscureText: true,
          controller: _atual,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          key: const Key('campo-nova-senha'),
          label: 'Nova senha',
          hint: 'Mínimo de 6 caracteres',
          obscureText: true,
          controller: _nova,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          key: const Key('campo-confirmar-senha'),
          label: 'Confirmar nova senha',
          hint: '••••••••',
          obscureText: true,
          controller: _confirmacao,
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ];
}

/// Sem e-mail no Tecsys: o caminho de quem esqueceu a senha.
class _PassosEsqueceu extends StatelessWidget {
  const _PassosEsqueceu();

  static const _passos = [
    'Peça a um administrador do Tecsys para redefinir a sua senha na tela Usuários.',
    'Ele vai passar uma senha temporária para você.',
    'Entre com ela: o sistema pede para você criar uma senha nova antes de continuar.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _passos.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.primary,
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(_passos[i],
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
