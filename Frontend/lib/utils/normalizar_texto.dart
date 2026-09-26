
String normalizarTexto(String texto) {
  const comAcento = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
  const semAcento = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  var resultado = texto;
  for (var i = 0; i < comAcento.length; i++) {
    resultado = resultado.replaceAll(comAcento[i], semAcento[i]);
  }
  return resultado;
}