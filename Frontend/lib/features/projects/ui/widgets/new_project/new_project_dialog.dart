import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/field_label.dart';
import 'package:tecsys_app/features/projects/data/models/novo_projeto_resultado.dart';
import 'package:tecsys_app/features/projects/state/new_project_dialog_controller.dart';
import 'package:tecsys_app/features/projects/ui/styles/new_project_dialog_styles.dart';
import 'package:tecsys_app/features/projects/ui/widgets/new_project/new_project_cities_field.dart';

/// Popup "Novo Projeto": nome, distribuidora e cidades. Ao confirmar
/// devolve um [NovoProjetoResultado] (ou null se o usuário fechar).
class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key});

  static Future<NovoProjetoResultado?> mostrar(BuildContext context) {
    return showDialog<NovoProjetoResultado>(
      context: context,
      builder: (context) => const NewProjectDialog(),
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
    _controller.carregarCidades();
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
            builder: (context, _) => Column(
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
                Container(
                  width: double.infinity,
                  padding: NewProjectDialogStyles.fieldPadding,
                  decoration: NewProjectDialogStyles.readonlyFieldDecoration,
                  child: Text(
                    _controller.distribuidoraLabel,
                    style: AppTextStyles.input,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const FieldLabel('Cidade(s)'),
                NewProjectCitiesField(controller: _controller),
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
    );
  }
}
