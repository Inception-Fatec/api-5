/// Leitura tolerante dos números que vêm do backend (número ou texto),
/// usada pelos modelos do ETL.
library;

/// Inteiro de um número ou texto; `null` se não der para ler.
int? jsonInt(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Número decimal de um número ou texto; 0 se não der para ler.
double jsonDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}
