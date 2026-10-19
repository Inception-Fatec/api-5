import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/utils/distributors.dart';
import 'package:tecsys_app/core/widgets/card_avatar.dart';
import 'package:tecsys_app/core/widgets/card_info_row.dart';
import 'package:tecsys_app/core/widgets/list_card.dart';
import 'package:tecsys_app/core/widgets/status_badge.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/projects/ui/styles/project_status_style.dart';
import 'package:tecsys_app/features/projects/ui/widgets/projects/confirm_delete_project_dialog.dart';

/// Card de um projeto na lista (abrir detalhe, excluir): o [ListCard]
/// padrão, o mesmo dos usuários, com a cor do status nos ícones.
/// Não conhece store nem navegação: tudo vem por parâmetro.
class ProjectCard extends StatefulWidget {
  final Project data;
  final String creatorName;
  final VoidCallback onOpen;

  /// Exclui de verdade; se lançar, o card avisa que falhou.
  final Future<void> Function() onDelete;

  const ProjectCard({
    super.key,
    required this.data,
    required this.creatorName,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _excluindo = false;

  Future<void> _confirmarExclusao() async {
    final confirmar = await confirmDeleteProject(context, widget.data.name);
    if (!confirmar || !mounted) return;

    setState(() => _excluindo = true);
    try {
      await widget.onDelete();
      // Se der certo o card some sozinho (a lista do store muda e a
      // tela reconstrói) - não precisa fazer mais nada aqui.
    } catch (_) {
      if (!mounted) return;
      setState(() => _excluindo = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Não foi possível excluir o projeto agora.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final statusColor = ProjectStatusStyle.color(data.status);

    return ListCard(
      dimmed: _excluindo,
      onTap: _excluindo ? null : widget.onOpen,
      onDelete: _excluindo ? null : _confirmarExclusao,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CardAvatar(color: statusColor, icon: Icons.folder_outlined),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(nomeDistribuidora(data.distCode),
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardCompany),
          ),
        ],
      ),
      badge: StatusBadge(
        label: ProjectStatusStyle.label(data.status),
        color: statusColor,
        softColor: ProjectStatusStyle.softColor(data.status),
      ),
      title: data.name,
      subtitle: 'ID #${data.id}',
      infoRows: [
        CardInfoRow(
            icon: Icons.calendar_today_outlined,
            text: data.dataFormatada,
            color: statusColor),
        CardInfoRow(
            icon: Icons.person_outline,
            text: widget.creatorName,
            color: statusColor),
      ],
    );
  }
}
