import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:tecsys_app/features/reports/data/models/coverage_report.dart';
import 'package:tecsys_app/features/reports/ui/report_efficiency.dart';
import 'package:tecsys_app/features/reports/ui/report_formatters.dart';
import 'package:tecsys_app/features/reports/ui/report_texts.dart';

/// A fonte padrão do PDF (Helvetica) cobre Latin-1 (acentos do português)
/// mas não travessão/marcador; troca esses caracteres por equivalentes.
String pdfSafe(String text) => text
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('•', '-')
    .replaceAll('…', '...');

/// Monta o PDF do relatório (resumo, leitura do resultado, parâmetros,
/// dados do cálculo e a lista COMPLETA de gateways). Sem o mapa: a
/// captura do mapa fica para uma próxima versão.
Future<Uint8List> buildReportPdf({
  required String projectName,
  required String distribuidora,
  required String date,
  required CoverageReport report,

  /// Foto do mapa (PNG), se foi possível capturar.
  Uint8List? mapImage,
}) async {
  final doc = pw.Document(title: pdfSafe('Relatório de cobertura - $projectName'));
  final s = report.summary;
  const accent = PdfColor.fromInt(0xFF006A60);
  const muted = PdfColor.fromInt(0xFF5F6B7A);
  const line = PdfColor.fromInt(0xFFE4E8EF);

  pw.Widget heading(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(pdfSafe(t),
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: accent)),
      );

  pw.Widget kv(String k, String v) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(pdfSafe(k), style: const pw.TextStyle(fontSize: 10, color: muted)),
            pw.Text(pdfSafe(v),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  pw.Widget cell(String t, {bool bold = false, pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: pw.Text(pdfSafe(t),
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  final params = filterEntries(report.filters);
  final insights = buildInsights(report);
  final milestones = coverageMilestones(report.gateways);
  final steps = coverageSteps(report.gateways);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Pagina ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: muted)),
    ),
    build: (ctx) => [
      pw.Text('RELATORIO DE COBERTURA',
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: accent)),
      pw.SizedBox(height: 2),
      pw.Text(pdfSafe(projectName),
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(pdfSafe('$distribuidora - $date'),
          style: const pw.TextStyle(fontSize: 10, color: muted)),
      heading('Resumo'),
      pw.Text(formatPercent(s.coveragePercentage),
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
      pw.Text(
          '${formatInt(s.coveredPoints)} de ${formatInt(s.totalPoints)} pontos atendidos - '
          '${coverageLabel(s.coveragePercentage)}',
          style: const pw.TextStyle(fontSize: 10, color: muted)),
      if (mapImage != null) ...[
        heading('Mancha de cobertura'),
        pw.Container(
          decoration: const pw.BoxDecoration(
              border: pw.Border.fromBorderSide(
                  pw.BorderSide(color: line, width: 0.5))),
          child: pw.Image(pw.MemoryImage(mapImage),
              width: 523, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
            'Roxo: area atendida (relevo considerado). Marcadores: gateways propostos. '
            'Vermelho: pontos sem cobertura. Mapa base: OpenStreetMap contributors.',
            style: const pw.TextStyle(fontSize: 8, color: muted)),
      ],
      if (insights.isNotEmpty) ...[
        heading('Leitura do resultado'),
        for (final i in insights)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text('- ${pdfSafe(i.text)}',
                style: const pw.TextStyle(fontSize: 10)),
          ),
      ],
      if (milestones.isNotEmpty || steps.isNotEmpty) ...[
        heading('Quantos gateways valem a pena'),
        for (final m in milestones)
          kv('Meta de ${formatInt(m.target.round())}%',
              '${formatInt(m.gatewayCount)} gateways (${formatDecimal(100 * m.shareOfGateways)}% da rede)'),
        if (steps.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.4),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(1.4),
            },
            border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: line, width: 0.5)),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F3F9)),
                children: [
                  cell('Gateways', bold: true),
                  cell('Cobertura acum.', bold: true, align: pw.TextAlign.right),
                  cell('Ganho (p.p.)', bold: true, align: pw.TextAlign.right),
                  cell('Pontos novos', bold: true, align: pw.TextAlign.right),
                ],
              ),
              for (final st in steps)
                pw.TableRow(children: [
                  cell(st.label.replaceAll('–', '-')),
                  cell(formatPercent(st.cumulativePercent),
                      align: pw.TextAlign.right),
                  cell('+${formatDecimal(st.gainPercent)}',
                      align: pw.TextAlign.right),
                  cell(formatInt(st.newPoints), align: pw.TextAlign.right),
                ]),
            ],
          ),
        ],
      ],
      heading('Parametros do estudo'),
      pw.Text(pdfSafe(reportIntro(s)), style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 4),
      if (params.isEmpty)
        pw.Text('Os parametros usados neste calculo nao foram informados pelo servidor.',
            style: const pw.TextStyle(fontSize: 9, color: muted))
      else
        for (final p in params) kv(p.label, p.value),
      heading('Dados do calculo'),
      for (final r in dataRows(s)) kv(r.label, r.value),
      heading('Gateways propostos (${formatInt(report.gateways.length)})'),
      if (report.gateways.isEmpty)
        pw.Text('Nenhum gateway adiciona cobertura neste estudo.',
            style: const pw.TextStyle(fontSize: 10))
      else
        pw.Table(
          columnWidths: const {
            0: pw.FixedColumnWidth(26),
            1: pw.FlexColumnWidth(2.6),
            2: pw.FlexColumnWidth(2.4),
            3: pw.FlexColumnWidth(1.2),
            4: pw.FlexColumnWidth(1.4),
          },
          border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: line, width: 0.5)),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F3F9)),
              children: [
                cell('#', bold: true),
                cell('Gateway', bold: true),
                cell('Coordenadas (lat, lon)', bold: true),
                cell('Pontos novos', bold: true, align: pw.TextAlign.right),
                cell('Cobertura acum.', bold: true, align: pw.TextAlign.right),
              ],
            ),
            for (final g in report.gateways)
              pw.TableRow(children: [
                cell('${g.order}'),
                cell('${gatewayTypeLabel(g.type)} ${g.id}'),
                cell(formatCoordinates(
                    g.position.latitude, g.position.longitude)),
                cell('+${formatInt(g.newPointsCovered)}',
                    align: pw.TextAlign.right),
                cell(formatPercent(g.cumulativeCoveragePercentage),
                    align: pw.TextAlign.right),
              ]),
          ],
        ),
    ],
  ));

  return doc.save();
}
