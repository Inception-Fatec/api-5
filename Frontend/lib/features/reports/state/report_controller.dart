import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tecsys_app/core/network/api_exception.dart';
import 'package:tecsys_app/features/projects/data/models/project_model.dart';
import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/data/services/report_service.dart';

/// Estados da tela de relatório.
enum ReportStatus {
  /// Buscando/decodificando o relatório.
  loading,

  /// Relatório carregado, com pelo menos um ponto.
  ready,

  /// O motor respondeu 200 mas sem pontos ("tudo zerado").
  empty,

  /// O projeto ainda não terminou o cálculo (CRIADO/ENVIADO/PROCESSANDO,
  /// segundo o status atual no servidor).
  calculating,

  /// O cálculo do projeto falhou (status FALHA).
  calculationFailed,

  /// 401/403: sessão expirada ou sem permissão.
  unauthorized,

  /// Qualquer outro erro (rede, 4xx/5xx, corpo inválido).
  error,
}

/// Estado da tela de relatório de um projeto: carrega, expõe o estado
/// de tela (loading/erro/vazio...) e qual gateway está em foco no mapa.
/// Sem lógica de UI — a tela só observa.
class ReportController extends ChangeNotifier {
  ReportController({
    required this.project,
    ReportService? service,
    this.refreshCooldown = const Duration(seconds: 15),
  }) : _service = service ?? ApiReportService();

  /// Tempo mínimo entre dois toques em "Atualizar" (evita martelar o
  /// servidor enquanto o motor calcula).
  final Duration refreshCooldown;

  final Project project;
  final ReportService _service;

  ReportStatus _status = ReportStatus.loading;
  CoverageReport? _report;
  String? _errorMessage;
  bool _disposed = false;

  Timer? _timer;
  Duration? _pollInterval;
  bool _polling = false;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

  ReportGateway? _focusedGateway;
  int _focusVersion = 0;

  ReportStatus get status => _status;
  CoverageReport? get report => _report;

  /// Mensagem pronta para exibir quando [status] é [ReportStatus.error].
  String? get errorMessage => _errorMessage;

  /// Gateway que o usuário tocou na lista (o mapa deve centralizar nele).
  ReportGateway? get focusedGateway => _focusedGateway;

  /// Muda a cada pedido de foco, mesmo para o mesmo gateway — é como o
  /// mapa sabe que deve recentralizar de novo.
  int get focusVersion => _focusVersion;

  Future<void> carregar() async {
    _errorMessage = null;
    _emit(ReportStatus.loading);
    try {
      if (_service.requiresCompletedProject) {
        // Status fresco do servidor: a lista de projetos pode estar
        // desatualizada (o motor grava SUCESSO/FALHA direto no banco).
        final status =
            await _service.statusAtual(project.id) ?? project.status;
        if (status == 'FALHA') {
          _emit(ReportStatus.calculationFailed);
          return;
        }
        if (status != 'SUCESSO') {
          _emit(ReportStatus.calculating);
          return;
        }
      }

      final report = await _service.carregar(project.id);
      _report = report;
      _emit(report.isEmpty ? ReportStatus.empty : ReportStatus.ready);
    } on ApiException catch (e) {
      _report = null;
      if (e.statusCode == 401 || e.statusCode == 403) {
        _emit(ReportStatus.unauthorized);
      } else {
        _errorMessage = e.message;
        _emit(ReportStatus.error);
      }
    } catch (_) {
      _report = null;
      _errorMessage = 'Não foi possível carregar o relatório.';
      _emit(ReportStatus.error);
    }
  }

  /// "Tentar novamente" — ignora toques enquanto já está carregando.
  Future<void> tentarNovamente() {
    if (_status == ReportStatus.loading) return Future.value();
    return carregar();
  }

  /// Segundos restantes até "Atualizar" voltar a funcionar (0 = livre).
  int get cooldownRestante => _cooldownLeft;

  /// "Atualizar" liberado: sem cooldown e sem consulta em andamento.
  bool get podeAtualizar => _cooldownLeft == 0 && !_polling;

  /// "Atualizar" da tela de cálculo em andamento: consulta o status do
  /// servidor uma vez e inicia o cooldown. Toques durante o cooldown são
  /// ignorados (nenhuma requisição).
  Future<void> atualizar() async {
    if (_disposed || _status != ReportStatus.calculating || !podeAtualizar) {
      return;
    }
    _startCooldown();
    await _verificarStatus();
  }

  void _startCooldown() {
    final seconds = refreshCooldown.inSeconds;
    if (seconds <= 0) return;
    _cooldownLeft = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _cooldownLeft--;
      if (_cooldownLeft <= 0) {
        _cooldownLeft = 0;
        t.cancel();
        _cooldownTimer = null;
      }
      if (!_disposed) notifyListeners();
    });
    if (!_disposed) notifyListeners();
  }

  void focarGateway(ReportGateway gateway) {
    _focusedGateway = gateway;
    _focusVersion++;
    if (!_disposed) notifyListeners();
  }

  /// Enquanto o projeto estiver calculando, consulta o status do servidor
  /// a cada [interval] e carrega o relatório quando virar SUCESSO (ou
  /// mostra a falha). Para sozinho em qualquer outro estado.
  void iniciarAtualizacaoAutomatica(
      {Duration interval = const Duration(seconds: 5)}) {
    _pollInterval = interval;
    _syncTimer();
  }

  void _syncTimer() {
    final interval = _pollInterval;
    if (interval == null || _disposed) return;
    if (_status == ReportStatus.calculating) {
      _timer ??= Timer.periodic(interval, (_) => _tick());
    } else if (_status != ReportStatus.loading) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _tick() => _verificarStatus();

  Future<void> _verificarStatus() async {
    if (_disposed || _polling || _status != ReportStatus.calculating) return;
    _polling = true;
    try {
      final status = await _service.statusAtual(project.id);
      if (_disposed || _status != ReportStatus.calculating) return;
      if (status == 'SUCESSO') {
        await carregar();
      } else if (status == 'FALHA') {
        _emit(ReportStatus.calculationFailed);
      }
    } catch (_) {
      // Falha pontual de rede: tenta de novo no próximo ciclo.
    } finally {
      _polling = false;
    }
  }

  void _emit(ReportStatus status) {
    _status = status;
    _syncTimer();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    super.dispose();
  }
}
