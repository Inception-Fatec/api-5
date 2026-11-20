/// Lê as datas que o backend manda: "dd/MM/yyyy HH:mm:ss" (horário de
/// Brasília, o formato dos DTOs de projeto) ou ISO 8601. Null se não der.
DateTime? lerDataBackend(String? texto) {
  if (texto == null || texto.trim().isEmpty) return null;
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})(?: (\d{2}):(\d{2})(?::(\d{2}))?)?$')
      .firstMatch(texto.trim());
  if (br == null) return DateTime.tryParse(texto.trim())?.toLocal();
  int n(int g) => int.tryParse(br.group(g) ?? '') ?? 0;
  return DateTime(n(3), n(2), n(1), n(4), n(5), n(6));
}
