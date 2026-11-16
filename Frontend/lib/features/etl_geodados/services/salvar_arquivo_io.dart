import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Mobile e desktop: o usuário escolhe onde salvar.
///
/// No file_picker 8.3.7 o `bytes` do `saveFile` só é gravado no Android e
/// no iOS; no desktop (Windows, Linux, macOS) ele apenas devolve o caminho
/// escolhido, então o arquivo é gravado aqui.
Future<bool> salvarArquivo({
  required String nome,
  required Uint8List bytes,
  String mime = 'text/csv',
}) async {
  final String extensao = nome.contains('.') ? nome.split('.').last : '';
  final String? caminho = await FilePicker.platform.saveFile(
    dialogTitle: 'Salvar $nome',
    fileName: nome,
    type: extensao.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: extensao.isEmpty ? null : <String>[extensao],
    bytes: bytes,
  );
  if (caminho == null) return false;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(caminho).writeAsBytes(bytes, flush: true);
  }
  return true;
}
