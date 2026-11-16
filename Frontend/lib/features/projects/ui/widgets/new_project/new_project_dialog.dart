import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/field_label.dart';
import 'package:tecsys_app/features/gateway_profiles/ui/gateway_profiles_dialog.dart';
import 'package:tecsys_app/features/projects/data/models/novo_projeto_resultado.dart';
import 'package:tecsys_app/features/projects/state/new_project_dialog_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/new_project_dialog_styles.dart';
import 'package:tecsys_app/features/projects/ui/widgets/new_project/new_project_cities_field.dart';

/// Popup "Novo Projeto": nome, distribuidora e cidades. Ao confirmar
/// devolve um [NovoProjetoResultado] (ou null se o usuário fechar).
class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key, this.nomeInicial});

  /// Nome já preenchido (ex.: ao refazer um projeto que falhou).
  final String? nomeInicial;

  static Future<NovoProjetoResultado?> mostrar(BuildContext context,
      {String? nomeInicial}) {
    return showDialog<NovoProjetoResultado>(
      context: context,
      builder: (context) => NewProjectDialog(nomeInicial: nomeInicial),
    );
  }

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final _controller = NewProjectDialogController();
  final _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nomeController.text = widget.nomeInicial ?? '';
    _controller.carregar();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final resultado = _controller.confirmar(_nomeController.text);
    if (resultado != null) Navigator.of(context).pop(resultado);
  }

  /// Lista para escolher a distribuidora; nenhuma vem escolhida (#TG-147).
  Widget _campoDistribuidora() {
    final lista = _controller.distribuidoras;
    return DropdownButtonFormField<String>(
      initialValue: _controller.distCode,
      isExpanded: true,
      style: AppTextStyles.input,
      hint: const Text('Selecione a distribuidora', style: AppTextStyles.bodyMuted),
      decoration: AppDecorations.filledInput(
        contentPadding: NewProjectDialogStyles.fieldPadding,
        borderRadius: AppRadius.sm,
      ),
      items: [
        for (final d in lista)
          DropdownMenuItem(value: d.codigo, child: Text(d.rotulo)),
      ],
      onChanged: lista.isEmpty
          ? null
          : (codigo) {
              if (codigo != null) _controller.escolherDistribuidora(codigo);
            },
    );
  }

  /// Perfil de gateway (#TG-79): o padrão já vem escolhido. "Gerenciar"
  /// abre a tela de perfis; o perfil criado lá volta selecionado.
  Widget _campoPerfil() {
    final perfis = _controller.perfis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: FieldLabel('Perfil de gateway')),
            TextButton.icon(
              key: const Key('gerenciar-perfis'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () async {
                final id = await GatewayProfilesDialog.mostrar(context);
                await _controller.carregarPerfis(selecionar: id);
              },
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Gerenciar perfis'),
            ),
          ],
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('perfil-${_controller.perfilId}-${perfis.length}'),
          initialValue: _controller.perfilId,
          isExpanded: true,
          style: AppTextStyles.input,
          hint: Text(
              _controller.erroPerfis
                  ? 'Perfis indisponíveis: será usado o perfil padrão'
                  : 'Carregando perfis...',
              style: AppTextStyles.bodyMuted),
          decoration: AppDecorations.filledInput(
            contentPadding: NewProjectDialogStyles.fieldPadding,
            borderRadius: AppRadius.sm,
          ),
          selectedItemBuilder: (_) => [
            for (final p in perfis)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(p.isDefault ? '${p.name} (padrão)' : p.name,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          items: [
            for (final p in perfis)
              DropdownMenuItem(
                value: p.id,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.isDefault ? '${p.name} (padrão)' : p.name,
                        overflow: TextOverflow.ellipsis),
                    Text(p.resumo,
                        style: AppTextStyles.micro,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
          ],
          onChanged: perfis.isEmpty ? null : _controller.escolherPerfil,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: SizedBox(
        width: NewProjectDialogStyles.widthFor(larguraTela),
        child: Padding(
          padding: NewProjectDialogStyles.padding,
          child: ListenableBuilder(
            listenable: _controller,
            // Rola quando o teclado encolhe o diálogo.
            builder: (context, _) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Novo Projeto',
                            style: NewProjectDialogStyles.title),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const FieldLabel('Nome do Projeto'),
                  TextField(
                    controller: _nomeController,
                    autofocus: true,
                    decoration: AppDecorations.filledInput(
                      hint: 'ex: Cobertura RF - Zona Leste SJC',
                      hintStyle: AppTextStyles.bodyMuted,
                      contentPadding: NewProjectDialogStyles.fieldPadding,
                      borderRadius: AppRadius.sm,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const FieldLabel('Empresa / Distribuidora'),
                  _campoDistribuidora(),
                  const SizedBox(height: AppSpacing.md),
                  const FieldLabel('Cidade(s)'),
                  NewProjectCitiesField(controller: _controller),
                  const SizedBox(height: AppSpacing.md),
                  _campoPerfil(),
                  if (_controller.erro != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(_controller.erro!, style: AppTextStyles.captionError),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: NewProjectDialogStyles.submitHeight,
                    child: ElevatedButton(
                      onPressed: _controller.carregando ? null : _confirmar,
                      style: AppButtonStyles.primary(),
                      child:
                          const Text('Buscar', style: AppTextStyles.buttonText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
