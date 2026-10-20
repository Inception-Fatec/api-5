import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Endpoint do backend ETL (contrato: POST multipart, campo `file`).
const String kEtlUploadUrl = 'http://localhost:8081/api/etl/upload';

// ============================================================================
// DESIGN TOKENS (compartilhados com etl_geodados_screen.dart)
// ============================================================================

class EtlPalette {
  EtlPalette._();

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal800 = Color(0xFF115E59);

  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald800 = Color(0xFF065F46);

  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose200 = Color(0xFFFECDD3);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose700 = Color(0xFFBE123C);
  static const Color rose900 = Color(0xFF881337);

  /// Fundo escurecido atrás dos modais (slate-900 a 60%).
  static const Color barrier = Color(0x990F172A);
}

class EtlText {
  EtlText._();

  static const List<String> _sansFallback = [
    'Roboto',
    'Noto Sans',
    'Ubuntu',
    'DejaVu Sans',
  ];
  static const List<String> _monoFallback = [
    'JetBrains Mono',
    'DejaVu Sans Mono',
    'Liberation Mono',
    'Noto Sans Mono',
  ];

  static TextStyle sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = EtlPalette.slate800,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: _sansFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        decoration: TextDecoration.none,
      );

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = EtlPalette.slate800,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: _monoFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        decoration: TextDecoration.none,
      );
}

/// Formata bytes como "36.2 MB" (ponto decimal, igual ao protótipo).
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int i = -1;
  do {
    value /= 1024;
    i++;
  } while (value >= 1024 && i < units.length - 1);
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[i]}';
}

// ============================================================================
// COMPONENTES COMPARTILHADOS (botões e casca de diálogo)
// ============================================================================

/// Botão primário (teal) com hover, estado desabilitado e carregando.
class EtlPrimaryButton extends StatefulWidget {
  const EtlPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color = EtlPalette.teal600,
    this.hoverColor = EtlPalette.teal700,
    this.fontSize = 12,
    this.iconSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color color;
  final Color hoverColor;
  final double fontSize;
  final double iconSize;
  final EdgeInsets padding;

  @override
  State<EtlPrimaryButton> createState() => _EtlPrimaryButtonState();
}

class _EtlPrimaryButtonState extends State<EtlPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = !enabled
        ? EtlPalette.teal400
        : (_hover ? widget.hoverColor : widget.color);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x330D9488),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            onHover: (v) => setState(() => _hover = v),
            child: Padding(
              padding: widget.padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (widget.icon != null)
                    Icon(widget.icon, size: widget.iconSize, color: Colors.white),
                  if (widget.loading || widget.icon != null)
                    const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: EtlText.sans(
                      widget.fontSize,
                      weight: FontWeight.w600,
                      color: Colors.white,
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

/// Botão secundário (contorno slate) com hover.
class EtlSecondaryButton extends StatefulWidget {
  const EtlSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<EtlSecondaryButton> createState() => _EtlSecondaryButtonState();
}

class _EtlSecondaryButtonState extends State<EtlSecondaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: enabled && _hover ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EtlPalette.slate200),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            onHover: (v) => setState(() => _hover = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                widget.label,
                style: EtlText.sans(
                  12,
                  weight: FontWeight.w600,
                  color: !enabled
                      ? EtlPalette.slate400
                      : (_hover ? EtlPalette.slate900 : EtlPalette.slate600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de ícone quadrado arredondado (ex.: fechar, trocar arquivo).
class EtlIconButton extends StatefulWidget {
  const EtlIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  State<EtlIconButton> createState() => _EtlIconButtonState();
}

class _EtlIconButtonState extends State<EtlIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: enabled && _hover ? EtlPalette.slate100 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            onHover: (v) => setState(() => _hover = v),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                widget.icon,
                size: 20,
                color: !enabled
                    ? EtlPalette.slate300
                    : (_hover ? EtlPalette.slate600 : EtlPalette.slate400),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}

/// Casca padrão dos modais Tecsys: cabeçalho, corpo rolável e rodapé.
class EtlDialogShell extends StatelessWidget {
  const EtlDialogShell({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
    this.maxWidth = 576,
  });

  final Widget header;
  final Widget body;
  final Widget footer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: EtlPalette.slate100),
            boxShadow: const [
              BoxShadow(
                color: Color(0x400F172A),
                blurRadius: 50,
                spreadRadius: -12,
                offset: Offset(0, 25),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: body,
                ),
              ),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho padrão: ícone/conteúdo à esquerda + botão fechar.
class EtlDialogHeader extends StatelessWidget {
  const EtlDialogHeader({
    super.key,
    required this.leading,
    required this.child,
    required this.onClose,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final Widget leading;
  final Widget child;
  final VoidCallback? onClose;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: EtlPalette.slate100)),
      ),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: child),
          const SizedBox(width: 8),
          EtlIconButton(
            icon: Icons.close,
            onPressed: onClose,
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }
}

/// Rodapé padrão (fundo slate-50 com borda superior).
class EtlDialogFooter extends StatelessWidget {
  const EtlDialogFooter({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });

  final List<Widget> children;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: EtlPalette.slate50,
        border: Border(top: BorderSide(color: EtlPalette.slate100)),
      ),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// RESULTADO / ABERTURA DO MODAL
// ============================================================================

/// Retornado por [showUploadModalDialog] quando o backend aceitou o arquivo.
class EtlUploadResult {
  const EtlUploadResult({
    required this.fileName,
    required this.sizeBytes,
    this.serverMessage,
  });

  final String fileName;
  final int sizeBytes;
  final String? serverMessage;
}

/// Abre o modal de upload. Retorna `null` se cancelado ou se falhou.
Future<EtlUploadResult?> showUploadModalDialog(BuildContext context) {
  return showDialog<EtlUploadResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: EtlPalette.barrier,
    builder: (_) => const UploadModalDialog(),
  );
}

// ============================================================================
// REQUISIÇÃO MULTIPART COM PROGRESSO
// ============================================================================

/// `http.MultipartRequest` que reporta bytes enviados (mesmo contrato:
/// POST multipart, campo `file`).
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(
    super.method,
    super.url, {
    required this.onProgress,
  });

  final void Function(int sent, int total) onProgress;

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    final stream = super.finalize();
    var sent = 0;
    final tracked = stream.transform<List<int>>(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          sink.add(chunk);
          onProgress(sent, total);
        },
      ),
    );
    return http.ByteStream(tracked);
  }
}

// ============================================================================
// MODAL DE UPLOAD
// ============================================================================

enum _UploadPhase { idle, uploading, success, error }

class _SelectedZip {
  const _SelectedZip({
    required this.name,
    required this.path,
    required this.size,
  });

  final String name;
  final String path;
  final int size;
}

class UploadModalDialog extends StatefulWidget {
  const UploadModalDialog({super.key});

  @override
  State<UploadModalDialog> createState() => _UploadModalDialogState();
}

class _UploadModalDialogState extends State<UploadModalDialog> {
  _UploadPhase _phase = _UploadPhase.idle;
  _SelectedZip? _file;
  double _progress = 0;
  int _lastPercent = -1;
  String? _errorMessage;
  bool _errorRetryable = false;
  String? _serverMessage;

  bool get _isUploading => _phase == _UploadPhase.uploading;

  // --------------------------------------------------------------- seleção

  Future<void> _pickFile() async {
    if (_isUploading) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
        withData: false,
        dialogTitle: 'Selecionar Geodatabase (.zip)',
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final picked = result.files.single;
      if (!picked.name.toLowerCase().endsWith('.zip')) {
        _showError(
          'O arquivo "${picked.name}" possui formato inválido. Aceita-se '
          'apenas arquivos com extensão .zip contendo o Geodatabase (.gdb).',
          retryable: false,
        );
        return;
      }
      final path = picked.path;
      if (path == null) {
        _showError(
          'Não foi possível acessar o caminho do arquivo selecionado.',
          retryable: false,
        );
        return;
      }

      setState(() {
        _file = _SelectedZip(name: picked.name, path: path, size: picked.size);
        _phase = _UploadPhase.idle;
        _errorMessage = null;
        _progress = 0;
        _lastPercent = -1;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(
        'Não foi possível abrir o seletor de arquivos: $e',
        retryable: false,
      );
    }
  }

  // ---------------------------------------------------------------- upload

  Future<void> _startUpload() async {
    final file = _file;
    if (file == null || _isUploading) return;

    setState(() {
      _phase = _UploadPhase.uploading;
      _progress = 0;
      _lastPercent = -1;
      _errorMessage = null;
    });

    try {
      final request = _ProgressMultipartRequest(
        'POST',
        Uri.parse(kEtlUploadUrl),
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final percent = (sent * 100) ~/ total;
          if (percent == _lastPercent) return;
          _lastPercent = percent;
          setState(() => _progress = sent / total);
        },
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path, filename: file.name),
      );

      final streamed = await request.send().timeout(const Duration(minutes: 15));
      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _progress = 1;
          _serverMessage = _extractServerMessage(response.body);
          _phase = _UploadPhase.success;
        });
      } else {
        _showError(_describeHttpError(response), retryable: true);
      }
    } on SocketException {
      if (!mounted) return;
      _showError(
        'Falha na conexão com o servidor de processamento ETL '
        '($kEtlUploadUrl). Verifique se o backend está em execução e tente '
        'novamente.',
        retryable: true,
      );
    } on http.ClientException catch (e) {
      if (!mounted) return;
      _showError(
        'Falha na comunicação com o servidor ETL: ${e.message}',
        retryable: true,
      );
    } on TimeoutException {
      if (!mounted) return;
      _showError(
        'O servidor demorou demais para responder. Tente novamente em '
        'instantes.',
        retryable: true,
      );
    } on FileSystemException {
      if (!mounted) return;
      _showError(
        'Não foi possível ler o arquivo selecionado. Verifique se ele ainda '
        'existe e se há permissão de leitura.',
        retryable: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Erro inesperado durante o envio: $e', retryable: true);
    }
  }

  String? _extractServerMessage(String body) {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        for (final key in const [
          'message',
          'mensagem',
          'error',
          'erro',
          'detail',
          'detalhe',
        ]) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
        return null;
      }
      if (decoded is String && decoded.trim().isNotEmpty) return decoded.trim();
      return null;
    } catch (_) {
      // Corpo não-JSON: usa texto curto, ignora páginas HTML/respostas longas.
      if (text.length <= 240 && !text.startsWith('<')) return text;
      return null;
    }
  }

  String _describeHttpError(http.Response response) {
    final detail = _extractServerMessage(response.body);
    final code = response.statusCode;
    final String base;
    if (code == 400 || code == 415 || code == 422) {
      base = 'O servidor rejeitou o arquivo. Certifique-se de que o .zip '
          'contém uma estrutura de Geodatabase (.gdb) íntegra.';
    } else if (code == 413) {
      base = 'O arquivo excede o tamanho máximo aceito pelo servidor.';
    } else if (code >= 500) {
      base = 'O servidor ETL encontrou um erro ao processar o arquivo.';
    } else {
      base = 'O servidor respondeu com um erro inesperado.';
    }
    return detail == null ? '$base (HTTP $code)' : '$base\n$detail (HTTP $code)';
  }

  void _showError(String message, {required bool retryable}) {
    setState(() {
      _phase = _UploadPhase.error;
      _errorMessage = message;
      _errorRetryable = retryable;
    });
  }

  void _retry() {
    if (_errorRetryable && _file != null) {
      _startUpload();
    } else {
      setState(() {
        _phase = _UploadPhase.idle;
        _errorMessage = null;
      });
    }
  }

  void _close() {
    final file = _file;
    if (_phase == _UploadPhase.success && file != null) {
      Navigator.of(context).pop(
        EtlUploadResult(
          fileName: file.name,
          sizeBytes: file.size,
          serverMessage: _serverMessage,
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading,
      child: EtlDialogShell(
        maxWidth: 576,
        header: EtlDialogHeader(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: EtlPalette.teal50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 24,
              color: EtlPalette.teal600,
            ),
          ),
          onClose: _isUploading ? null : _close,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Geodatabase (.zip)',
                style: EtlText.sans(
                  18,
                  weight: FontWeight.w700,
                  color: EtlPalette.slate900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Envie o arquivo espelhado para extração, transformação e '
                'carga (ETL)',
                style: EtlText.sans(12, color: EtlPalette.slate500),
              ),
            ],
          ),
        ),
        body: _buildBody(),
        footer: _buildFooter(),
      ),
    );
  }

  Widget _buildBody() {
    final Widget content;
    switch (_phase) {
      case _UploadPhase.success:
        content = const _SuccessPanel();
        break;
      case _UploadPhase.error:
        content = _ErrorPanel(message: _errorMessage ?? 'Erro desconhecido.');
        break;
      case _UploadPhase.idle:
      case _UploadPhase.uploading:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Dropzone(enabled: !_isUploading, onTap: _pickFile),
            if (_file != null) ...[
              const SizedBox(height: 16),
              _SelectedFileCard(
                file: _file!,
                uploading: _isUploading,
                onChange: _isUploading ? null : _pickFile,
              ),
            ],
            if (_isUploading) ...[
              const SizedBox(height: 16),
              _ProgressCard(progress: _progress),
            ],
          ],
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _InfoCallout(),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_phase == _UploadPhase.uploading
              ? _UploadPhase.idle
              : _phase), child: content),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final VoidCallback? primaryAction;
    final String primaryLabel;
    final IconData primaryIcon;
    Color color = EtlPalette.teal600;
    Color hover = EtlPalette.teal700;

    switch (_phase) {
      case _UploadPhase.idle:
        primaryLabel = 'Iniciar Upload';
        primaryIcon = Icons.cloud_upload_outlined;
        primaryAction = _file != null ? _startUpload : null;
        break;
      case _UploadPhase.uploading:
        primaryLabel = 'Enviando...';
        primaryIcon = Icons.cloud_upload_outlined;
        primaryAction = null;
        break;
      case _UploadPhase.success:
        primaryLabel = 'Concluir';
        primaryIcon = Icons.check;
        primaryAction = _close;
        color = EtlPalette.emerald600;
        hover = EtlPalette.emerald700;
        break;
      case _UploadPhase.error:
        primaryLabel = 'Tentar Novamente';
        primaryIcon = Icons.refresh;
        primaryAction = _retry;
        break;
    }

    return EtlDialogFooter(
      children: [
        if (_phase != _UploadPhase.success)
          EtlSecondaryButton(
            label: 'Cancelar',
            onPressed: _isUploading ? null : _close,
          ),
        EtlPrimaryButton(
          label: primaryLabel,
          icon: primaryIcon,
          loading: _isUploading,
          color: color,
          hoverColor: hover,
          onPressed: primaryAction,
        ),
      ],
    );
  }
}

// ============================================================================
// PEÇAS VISUAIS DO MODAL
// ============================================================================

class _InfoCallout extends StatelessWidget {
  const _InfoCallout();

  @override
  Widget build(BuildContext context) {
    final base = EtlText.sans(12, color: EtlPalette.slate600, height: 1.6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x99F0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.teal100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 18, color: EtlPalette.teal600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  TextSpan(
                    text: 'Diretrizes do Arquivo:',
                    style: base.copyWith(
                      fontWeight: FontWeight.w600,
                      color: EtlPalette.slate800,
                    ),
                  ),
                  const TextSpan(
                    text: ' O File Geodatabase (.gdb) deve ser enviado '
                        'exclusivamente compactado em formato ',
                  ),
                  TextSpan(
                    text: '.zip',
                    style: EtlText.mono(
                      12,
                      weight: FontWeight.w700,
                      color: EtlPalette.teal800,
                      height: 1.6,
                    ),
                  ),
                  const TextSpan(
                    text: '. O ETL irá ler schemas, camadas vetoriais e '
                        'tabelas alfanuméricas.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropzone extends StatefulWidget {
  const _Dropzone({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_Dropzone> createState() => _DropzoneState();
}

class _DropzoneState extends State<_Dropzone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && _hover;
    return Opacity(
      opacity: widget.enabled ? 1 : 0.55,
      child: MouseRegion(
        cursor:
            widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: CustomPaint(
            foregroundPainter: _DashedRRectPainter(
              color: active ? EtlPalette.teal500 : EtlPalette.slate300,
              radius: 16,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0x33F0FDFA)
                    : const Color(0x80F8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: active ? 1.05 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF5EEAD4)
                              : EtlPalette.slate200,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D0F172A),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.upload_outlined,
                        size: 22,
                        color: EtlPalette.teal600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Clique para selecionar o arquivo .zip',
                    textAlign: TextAlign.center,
                    style: EtlText.sans(
                      12,
                      weight: FontWeight.w600,
                      color: EtlPalette.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Formato exclusivo aceito: .zip (File Geodatabase)',
                    textAlign: TextAlign.center,
                    style: EtlText.sans(11, color: EtlPalette.slate400),
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

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

class _SelectedFileCard extends StatelessWidget {
  const _SelectedFileCard({
    required this.file,
    required this.uploading,
    required this.onChange,
  });

  final _SelectedZip file;
  final bool uploading;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final meta = EtlText.sans(12, color: EtlPalette.slate500);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x99F8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: EtlPalette.teal600,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330D9488),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.folder_zip_outlined,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EtlText.sans(
                          14,
                          weight: FontWeight.w600,
                          color: EtlPalette.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: EtlPalette.emerald100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Válido',
                        style: EtlText.sans(
                          10,
                          weight: FontWeight.w600,
                          color: EtlPalette.emerald800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      '.zip (.gdb compactado)',
                      style: EtlText.mono(12, color: EtlPalette.teal700),
                    ),
                    Text('•', style: meta),
                    Text(formatFileSize(file.size), style: meta),
                    Text('•', style: meta),
                    Text(
                      uploading ? 'Enviando...' : 'Pronto para processamento',
                      style: meta,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EtlIconButton(
            icon: Icons.sync,
            tooltip: 'Alterar arquivo',
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).floor().clamp(0, 100);
    final status = progress >= 1
        ? 'Validando geometrias e índices espaciais...'
        : 'Enviando arquivo para o servidor...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EtlPalette.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: EtlPalette.teal600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EtlText.sans(
                    12,
                    weight: FontWeight.w600,
                    color: EtlPalette.slate700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: EtlText.sans(
                  12,
                  weight: FontWeight.w700,
                  color: EtlPalette.teal700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: EtlPalette.slate200,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: EtlPalette.teal600,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel();

  @override
  Widget build(BuildContext context) {
    final small = EtlText.sans(12, color: EtlPalette.slate700);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0x99ECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.emerald200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: EtlPalette.emerald100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 30,
              color: EtlPalette.emerald600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload Concluído com Sucesso!',
            textAlign: TextAlign.center,
            style: EtlText.sans(
              16,
              weight: FontWeight.w700,
              color: EtlPalette.slate900,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Text(
              'O arquivo compactado foi recebido pelo pipeline ETL com '
              'sucesso. O processamento das camadas geoespaciais foi iniciado.',
              textAlign: TextAlign.center,
              style: EtlText.sans(12, color: EtlPalette.slate600, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EtlPalette.emerald100),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: EtlPalette.emerald500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pipeline Ativo',
                      style: EtlText.sans(
                        12,
                        weight: FontWeight.w500,
                        color: EtlPalette.emerald700,
                      ),
                    ),
                  ],
                ),
                Text('•', style: small),
                Text.rich(
                  TextSpan(
                    style: small,
                    children: [
                      const TextSpan(text: 'Status: '),
                      TextSpan(
                        text: 'Recebido pelo pipeline ETL',
                        style: small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: EtlPalette.slate800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB3FFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EtlPalette.rose200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: EtlPalette.rose100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 24,
              color: EtlPalette.rose600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Falha no Envio do Arquivo',
                  style: EtlText.sans(
                    14,
                    weight: FontWeight.w700,
                    color: EtlPalette.rose900,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  message,
                  style: EtlText.sans(
                    12,
                    color: EtlPalette.rose700,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}