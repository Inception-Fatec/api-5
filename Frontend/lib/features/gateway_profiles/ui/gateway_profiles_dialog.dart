import 'package:flutter/material.dart';

import 'package:tecsys_app/core/theme/app_theme.dart';
import 'package:tecsys_app/core/widgets/field_label.dart';
import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile.dart';
import 'package:tecsys_app/features/gateway_profiles/data/gateway_profile_service.dart';

/// Tela "Perfis de gateway" (#TG-79): lista, cria, edita e exclui os perfis
/// técnicos usados no cálculo (#TG-150). Abre por cima do "Novo Projeto".
///
/// Devolve o id do último perfil criado ou editado (para o novo projeto já
/// selecioná-lo), ou null.
class GatewayProfilesDialog extends StatefulWidget {
  const GatewayProfilesDialog({super.key, this.service});

  /// Para os testes; no app usa o serviço padrão.
  final GatewayProfileService? service;

  static Future<int?> mostrar(BuildContext context,
          {GatewayProfileService? service}) =>
      showDialog<int>(
        context: context,
        builder: (_) => GatewayProfilesDialog(service: service),
      );

  @override
  State<GatewayProfilesDialog> createState() => _GatewayProfilesDialogState();
}

class _GatewayProfilesDialogState extends State<GatewayProfilesDialog> {
  late final GatewayProfileService _service =
      widget.service ?? GatewayProfileService();

  List<GatewayProfile>? _perfis;
  String? _erroLista;

  /// Perfil em edição: null = mostrando a lista; id null = perfil novo.
  GatewayProfile? _editando;
  int? _ultimoSalvo;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erroLista = null);
    try {
      final lista = await _service.listar();
      if (mounted) setState(() => _perfis = lista);
    } catch (e) {
      if (mounted) {
        setState(() => _erroLista = 'Não foi possível carregar os perfis. $e');
      }
    }
  }

  Future<void> _excluir(GatewayProfile p) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir perfil'),
        content: Text('Excluir o perfil "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await _service.excluir(p.id!);
      await _carregar();
    } catch (e) {
      // Ex.: perfil usado por projeto ou o perfil padrão (422 com o motivo).
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _aoSalvar(GatewayProfile salvo) {
    _ultimoSalvo = salvo.id;
    setState(() => _editando = null);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: largura < 600 ? largura : 560,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _editando == null
              ? _lista()
              : _FormularioPerfil(
                  inicial: _editando!,
                  service: _service,
                  onCancelar: () => setState(() => _editando = null),
                  onSalvo: _aoSalvar,
                ),
        ),
      ),
    );
  }

  Widget _lista() {
    final perfis = _perfis;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('Perfis de gateway', style: AppTextStyles.cardTitle)),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(_ultimoSalvo),
            ),
          ],
        ),
        const Text(
          'Parâmetros de rádio usados no cálculo de cobertura. '
          'O perfil padrão é usado quando o projeto não escolhe outro.',
          style: AppTextStyles.bodyMuted,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_erroLista != null) ...[
          Text(_erroLista!, style: AppTextStyles.bodySmallError),
          TextButton(onPressed: _carregar, child: const Text('Tentar de novo')),
        ] else if (perfis == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: perfis.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _CartaoPerfil(
                perfil: perfis[i],
                onEditar: () => setState(() => _editando = perfis[i]),
                onExcluir: perfis[i].isDefault ? null : () => _excluir(perfis[i]),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton.icon(
          key: const Key('novo-perfil'),
          onPressed: () =>
              setState(() => _editando = GatewayProfile.referenciaTecsys),
          style: AppButtonStyles.primary(),
          icon: const Icon(Icons.add),
          label: const Text('Novo perfil', style: AppTextStyles.buttonText),
        ),
      ],
    );
  }
}

class _CartaoPerfil extends StatelessWidget {
  const _CartaoPerfil({
    required this.perfil,
    required this.onEditar,
    required this.onExcluir,
  });

  final GatewayProfile perfil;
  final VoidCallback onEditar;
  final VoidCallback? onExcluir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      decoration: AppDecorations.outlinedCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(perfil.name, style: AppTextStyles.sectionLabel),
                    if (perfil.isDefault)
                      const Chip(
                        label: Text('Padrão', style: AppTextStyles.chipLabel),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(perfil.resumo, style: AppTextStyles.micro),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEditar,
          ),
          IconButton(
            tooltip: onExcluir == null
                ? 'O perfil padrão não pode ser excluído'
                : 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: onExcluir,
          ),
        ],
      ),
    );
  }
}

/// Formulário de criar/editar: cada campo mostra o próprio erro (#TG-79).
class _FormularioPerfil extends StatefulWidget {
  const _FormularioPerfil({
    required this.inicial,
    required this.service,
    required this.onCancelar,
    required this.onSalvo,
  });

  final GatewayProfile inicial;
  final GatewayProfileService service;
  final VoidCallback onCancelar;
  final ValueChanged<GatewayProfile> onSalvo;

  @override
  State<_FormularioPerfil> createState() => _FormularioPerfilState();
}

class _FormularioPerfilState extends State<_FormularioPerfil> {
  late final Map<CampoPerfil, TextEditingController> _campos = {
    for (final c in CampoPerfil.values)
      c: TextEditingController(text: _valorInicial(c)),
  };
  final Map<CampoPerfil, String?> _erros = {};
  String? _erroEnvio;
  bool _salvando = false;

  bool get _novo => widget.inicial.id == null;

  String _valorInicial(CampoPerfil c) {
    final p = widget.inicial;
    String n(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toString().replaceAll('.', ',');
    return switch (c) {
      CampoPerfil.nome => p.name,
      CampoPerfil.frequencia => n(p.frequencyMhz),
      CampoPerfil.potencia => n(p.txPowerDbm),
      CampoPerfil.ganho => n(p.antennaGainDbi),
      CampoPerfil.sensibilidade => n(p.rxSensitivityDbm),
      CampoPerfil.alturaGateway => n(p.antennaHeightM),
      CampoPerfil.alturaSensor => n(p.sensorHeightM),
      CampoPerfil.perda => n(p.extraLossDb),
    };
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() {
      for (final c in CampoPerfil.values) {
        _erros[c] = c.validar(_campos[c]!.text);
      }
      _erroEnvio = null;
    });
    if (_erros.values.any((e) => e != null)) return;

    double v(CampoPerfil c) => CampoPerfil.lerNumero(_campos[c]!.text)!;
    final perfil = GatewayProfile(
      id: widget.inicial.id,
      name: _campos[CampoPerfil.nome]!.text.trim(),
      frequencyMhz: v(CampoPerfil.frequencia),
      txPowerDbm: v(CampoPerfil.potencia),
      antennaGainDbi: v(CampoPerfil.ganho),
      rxSensitivityDbm: v(CampoPerfil.sensibilidade),
      antennaHeightM: v(CampoPerfil.alturaGateway),
      sensorHeightM: v(CampoPerfil.alturaSensor),
      extraLossDb: v(CampoPerfil.perda),
      maxDevices: widget.inicial.maxDevices,
      isDefault: widget.inicial.isDefault,
    );

    setState(() => _salvando = true);
    try {
      final salvo = _novo
          ? await widget.service.criar(perfil)
          : await widget.service.editar(perfil.id!, perfil);
      if (mounted) widget.onSalvo(salvo);
    } catch (e) {
      // Ex.: nome repetido (o banco exige nome único).
      if (mounted) {
        setState(() {
          _salvando = false;
          _erroEnvio = 'Não foi possível salvar: $e';
        });
      }
    }
  }

  Widget _campo(CampoPerfil c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(c.unidade.isEmpty ? c.rotulo : '${c.rotulo} (${c.unidade})'),
          TextField(
            key: Key('campo-${c.name}'),
            controller: _campos[c],
            keyboardType: c == CampoPerfil.nome
                ? TextInputType.text
                : const TextInputType.numberWithOptions(
                    signed: true, decimal: true),
            onChanged: (_) {
              if (_erros[c] != null) setState(() => _erros[c] = null);
            },
            decoration: AppDecorations.filledInput(
              borderRadius: AppRadius.sm,
            ).copyWith(errorText: _erros[c]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back),
              onPressed: _salvando ? null : widget.onCancelar,
            ),
            Expanded(
              child: Text(_novo ? 'Novo perfil' : 'Editar perfil',
                  style: AppTextStyles.cardTitle),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in CampoPerfil.values) _campo(c),
                const Text(
                  'Perda adicional: atenuação de vegetação e construções. '
                  'Use 0 para espaço livre; em área urbana, valores entre 10 e 30 dB '
                  'fazem a potência e a sensibilidade influírem no alcance.',
                  style: AppTextStyles.micro,
                ),
              ],
            ),
          ),
        ),
        if (_erroEnvio != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_erroEnvio!, style: AppTextStyles.bodySmallError),
        ],
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
          key: const Key('salvar-perfil'),
          onPressed: _salvando ? null : _salvar,
          style: AppButtonStyles.primary(),
          child: Text(_salvando ? 'Salvando...' : 'Salvar',
              style: AppTextStyles.buttonText),
        ),
      ],
    );
  }
}
