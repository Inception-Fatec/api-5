import 'package:tecsys_app/core/ajuda/ajuda.dart';
import 'package:tecsys_app/features/map/ui/styles/map_styles.dart';

/// Textos de ajuda de todas as telas (#TG-153), num lugar só. São a base do
/// manual do usuário (#TG-93): mudou aqui, mude lá também.
class TextosAjuda {
  TextosAjuda._();

  // ─────────────────────────── Login ───────────────────────────

  static const login = AjudaTela(
    titulo: 'Entrar no sistema',
    objetivo:
        'O acesso é feito com o e-mail e a senha cadastrados por um administrador.',
    passos: [
      'Digite o e-mail e a senha e clique em Entrar.',
      'No primeiro acesso, o sistema pede para trocar a senha provisória por uma senha sua.',
      'A sessão vale por 2 horas. Depois disso, o sistema volta para esta tela e avisa que a sessão expirou.',
    ],
    secoes: [
      AjudaSecao('Problemas comuns', [
        AjudaItem('Senha incorreta',
            'confira maiúsculas e minúsculas. Se esqueceu a senha, clique em "Esqueceu a senha?": '
                'um administrador define uma senha temporária para você.'),
        AjudaItem('Conta desativada',
            'um administrador removeu seu acesso; fale com ele.'),
      ]),
    ],
  );

  static const trocaSenha = AjudaTela(
    titulo: 'Trocar a senha',
    objetivo:
        'No primeiro acesso, a senha provisória precisa ser trocada antes de usar o sistema.',
    passos: [
      'Digite a senha nova (mínimo de 6 caracteres) e repita no campo de confirmação.',
      'Clique em Confirmar. O sistema abre em seguida, já com a senha nova.',
    ],
  );

  static const redefinirSenha = AjudaTela(
    titulo: 'Redefinir a senha',
    objetivo:
        'Troque a sua senha a qualquer momento pelo menu da conta. Se esqueceu a senha, '
        'um administrador define uma senha temporária para você.',
    passos: [
      'Logado: abra o menu da conta e clique em Redefinir Senha.',
      'Digite a senha atual, a senha nova (mínimo de 6 caracteres) e repita a nova.',
      'Clique em Salvar nova senha. A sessão continua aberta, já com a senha nova.',
    ],
    secoes: [
      AjudaSecao('Esqueceu a senha', [
        AjudaItem('Peça a um administrador',
            'ele abre a tela Usuários, clica na chave do seu cartão e define uma senha temporária.'),
        AjudaItem('Entre com a senha temporária',
            'no próximo acesso o sistema pede para você criar uma senha nova antes de continuar.'),
      ]),
    ],
  );

  static const comparacao = AjudaTela(
    titulo: 'Comparar cenários',
    objetivo:
        'Coloca lado a lado os resultados de projetos concluídos para ver qual cenário cobre mais '
        'consumidores e com quantos gateways.',
    passos: [
      'O primeiro projeto marcado (A) é a referência; os outros são comparados com ele.',
      'O Δ mostra a diferença para a referência: verde é melhor (mais cobertura ou menos gateways), '
          'vermelho é pior e cinza é igual.',
      'Toque no mapa de um cenário para abri-lo em tela cheia.',
    ],
    secoes: [
      AjudaSecao('Como ler o Δ', [
        AjudaItem('Cobertura',
            'em pontos percentuais (p.p.): de 80% para 85% é +5,00 p.p.'),
        AjudaItem('Gateways',
            'quantos gateways a mais (+) ou a menos (−) que a referência.'),
      ]),
    ],
  );

  // ─────────────────────────── Projetos ───────────────────────────

  static const projetos = AjudaTela(
    titulo: 'Projetos',
    objetivo:
        'Cada projeto é um estudo de onde instalar gateways para cobrir os pontos de uma área. '
        'Aqui ficam todos os projetos, do mais recente para o mais antigo.',
    passos: [
      'Clique em Novo Projeto para começar um estudo.',
      'Use a seção Recentes para voltar rápido aos últimos projetos que você mexeu.',
      'Clique em um projeto concluído para abrir o relatório; nos demais status, ele abre no mapa.',
      'Use a busca e o filtro de status para achar um projeto na lista.',
      'Para comparar cenários, clique em Comparar projetos, marque 2 ou mais projetos concluídos e clique em Comparar.',
    ],
    secoes: [
      AjudaSecao('Status do projeto', [
        AjudaItem('Criado / Enviado',
            'o projeto foi salvo e está na fila do cálculo.'),
        AjudaItem('Processando',
            'o motor está calculando. Áreas grandes levam alguns minutos; a tela atualiza sozinha.'),
        AjudaItem(
            'Concluído', 'o cálculo terminou; o relatório está disponível.'),
        AjudaItem('Falha',
            'o cálculo não terminou. O relatório mostra o motivo; ajuste e recalcule.'),
      ]),
    ],
  );

  static const novoProjeto = AjudaTela(
    titulo: 'Novo projeto',
    objetivo:
        'Define o nome, a área de estudo e o perfil de rádio do gateway. Depois, o mapa abre para ajustar os filtros.',
    passos: [
      'Dê um nome ao projeto.',
      'Escolha a distribuidora. Aparecem só as que têm dados carregados (rede da BDGD ou pontos de planilha).',
      'Marque uma ou mais cidades da distribuidora.',
      'Confira o perfil de gateway. O perfil padrão (Tecsys) já vem escolhido; troque se quiser simular outro equipamento.',
      'Clique em Buscar para abrir o mapa.',
    ],
    secoes: [
      AjudaSecao('Campos', [
        AjudaItem(
            'Perfil de gateway',
            'parâmetros de rádio usados no cálculo (frequência, potência, sensibilidade, alturas). '
                'Em "Gerenciar perfis" você cria e edita perfis.'),
      ]),
    ],
  );

  // ─────────────────────────── Mapa ───────────────────────────

  /// Ajuda de cada filtro do mapa (tooltip do botão e texto no topo do painel).
  static const filtroPontosACobrir =
      'O que o cálculo precisa atender. Padrão: consumidores de baixa, média e alta tensão. '
      '"Pontos externos (CSV)" inclui os pontos importados por planilha.';
  static const filtroCandidatos =
      'Onde o motor pode instalar gateways. Padrão: transformadores de média e alta tensão. '
      'Marque consumidores ou "Pontos externos (CSV)" para permitir outros locais.';
  static const filtroAreas =
      'Restringe o estudo às áreas desenhadas no mapa. Sem área, vale a cidade inteira. '
      'Desenhe pelo botão de seleção na lateral direita do mapa.';
  static const filtroBairro =
      'Só os pontos dos bairros digitados. A busca é parcial: "Centro" acha "Centro" e "Jardim Centro".';
  static const filtroTensao =
      'Filtra os pontos pela tensão de atendimento: alta, média, baixa ou todas.';
  static const filtroConjunto =
      'Conjunto elétrico da ANEEL (código CONJ da BDGD), uma região de atendimento da distribuidora.';
  static const filtroSubestacao =
      'Só os pontos atendidos pelas subestações informadas (código da subestação).';
  static const filtroClasse =
      'Classe de consumo: residencial, comercial, industrial, rural, poder público e outras.';
  static const filtroCnae = 'Atividade econômica do consumidor (código CNAE).';
  static const contadorMapa =
      'Pontos a cobrir: consumidores (ou pontos da planilha) que entram no cálculo com os filtros atuais. '
      'Locais para gateway: candidatos onde o motor pode instalar. É o mesmo total que o relatório vai mostrar.';
  static const atalhoPlanilha =
      'Calcula só com os pontos da planilha: eles passam a ser os pontos a cobrir e os candidatos a gateway, '
      'e a rede da distribuidora é ignorada.';

  static final mapa = AjudaTela(
    titulo: 'Mapa do projeto',
    objetivo:
        'Aqui você escolhe quais pontos entram no cálculo e onde os gateways podem ser instalados. '
        'Ao salvar, o motor calcula o menor número de gateways que cobre esses pontos.',
    passos: const [
      'Confira a distribuidora e as cidades no topo. Clique nas cidades para incluir ou tirar uma.',
      'Acompanhe o contador abaixo delas: ele mostra quantos pontos vão ser cobertos e quantos locais podem receber gateway.',
      'Refine com os filtros (pontos a cobrir, candidatos, áreas, bairro, tensão, conjunto, subestação, classe e CNAE).',
      'Se quiser limitar a uma região, desenhe uma ou mais áreas no mapa.',
      'Clique em Salvar Projeto (ou Recalcular, num projeto aberto). O cálculo roda em segundo plano.',
    ],
    secoes: [
      const AjudaSecao('Contador no topo',
          [AjudaItem('Pontos a cobrir · locais para gateway', contadorMapa)]),
      const AjudaSecao('Filtros', [
        AjudaItem('Pontos a cobrir', filtroPontosACobrir),
        AjudaItem('Candidatos a gateway', filtroCandidatos),
        AjudaItem('Áreas', filtroAreas),
        AjudaItem('Bairro', filtroBairro),
        AjudaItem('Nível de tensão', filtroTensao),
        AjudaItem('Conjunto', filtroConjunto),
        AjudaItem('Subestação', filtroSubestacao),
        AjudaItem('Classe', filtroClasse),
        AjudaItem('CNAE', filtroCnae),
      ]),
      AjudaSecao('Legenda: mapa afastado (bolhas)', [
        const AjudaItem(
            'Bolha',
            'agrupa os pontos a cobrir de uma região; o número é quantos pontos ela tem. '
                'Clique na bolha (ou dê zoom) para ver os pontos.'),
        for (final (_, cor, faixa) in MapStyles.clusterFaixas)
          AjudaItem(faixa, 'pontos a cobrir na bolha', cor: cor),
      ]),
      const AjudaSecao('Legenda: mapa de perto (pontos)', [
        AjudaItem('Ponto de alta tensão', 'consumidor atendido em alta tensão.',
            cor: MapStyles.corTensaoAlta),
        AjudaItem(
            'Ponto de média tensão', 'consumidor atendido em média tensão.',
            cor: MapStyles.corTensaoMedia),
        AjudaItem('Ponto de baixa tensão',
            'consumidor de baixa tensão (casas e comércios). Um ponto pode reunir vários consumidores no mesmo endereço.',
            cor: MapStyles.corTensaoBaixa),
        AjudaItem('Candidato a gateway',
            'local onde o motor pode instalar um gateway (por padrão, transformadores).',
            cor: MapStyles.corCandidato, marca: AjudaMarca.losango),
        AjudaItem('Rede elétrica',
            'linhas e equipamentos da rede, só para referência; não entram no cálculo.',
            cor: MapStyles.corRede, marca: AjudaMarca.quadrado),
        AjudaItem('Área desenhada',
            'região escolhida para o estudo; os pontos dentro dela ficam destacados.',
            cor: MapStyles.corArea, marca: AjudaMarca.quadrado),
        AjudaItem('Ver detalhes',
            'clique em um ponto para ver classe, bairro, subestação e outros dados.'),
      ]),
      const AjudaSecao('Desenhar uma área', [
        AjudaItem(
            'Polígono',
            'clique no mapa para marcar cada vértice; feche clicando no 1º vértice, com duplo clique ou em Concluir. '
                'Desfazer (Backspace) remove o último ponto; Esc cancela.'),
        AjudaItem(
            'Retângulo', 'escolha "Retângulo" na barra e arraste no mapa.'),
        AjudaItem('Várias áreas',
            'desenhe quantas quiser. No filtro Áreas você vê o total de cada uma, foca ou remove.'),
      ]),
      const AjudaSecao('Rede independente (planilha)', [
        AjudaItem('Só a planilha',
            'quando a cidade não tem rede da distribuidora carregada, o mapa já abre usando só os pontos do CSV.'),
        AjudaItem('Usar só os pontos da planilha', atalhoPlanilha),
      ]),
      const AjudaSecao('Botões na lateral direita', [
        AjudaItem('+ e −', 'aproximar e afastar.'),
        AjudaItem('Seleção de área', 'liga o modo de desenho de área.'),
        AjudaItem('Lixeira', 'aparece com uma área selecionada; apaga só ela.'),
        AjudaItem('Relevo',
            'mostra o relevo do terreno por cima do mapa (só visual; o cálculo sempre considera o relevo).'),
      ]),
    ],
  );

  // ─────────────────────────── Relatório ───────────────────────────

  static const relatorio = AjudaTela(
    titulo: 'Relatório de cobertura',
    objetivo:
        'Resultado do cálculo: quantos gateways instalar, onde, e quantos consumidores ficam atendidos.',
    passos: [
      'Leia o resumo no topo: cobertura e número de gateways.',
      'Veja no mapa a mancha de cobertura e os gateways propostos.',
      'Confira a lista de gateways, na ordem em que mais acrescentam cobertura.',
      'Exporte em PDF pelo botão no canto superior direito.',
      'Para mudar filtros, área ou perfil, use "Editar no mapa e recalcular". Cada recálculo vira uma nova versão (botão Versões).',
    ],
    secoes: [
      AjudaSecao('Indicadores', [
        AjudaItem('Cobertura',
            'porcentagem dos consumidores analisados que algum gateway alcança.'),
        AjudaItem('Gateways',
            'menor número de gateways encontrado para essa cobertura.'),
        AjudaItem('Sem cobertura',
            'consumidores que nenhum candidato alcança (relevo, distância). Avalie novos candidatos nessa região.'),
        AjudaItem('Curva de eficiência',
            'quanto cada gateway acrescenta. Os primeiros costumam cobrir a maior parte; os últimos, poucos consumidores.'),
        AjudaItem('Premissas do cálculo',
            'perfil de gateway, valores de rádio, alturas e relevo usados no cálculo.'),
      ]),
      AjudaSecao('Mapa do relatório', [
        AjudaItem(
            'Mancha roxa', 'área onde o sinal chega, considerando o relevo.'),
        AjudaItem('Marcador', 'gateway proposto. Clique para ver os dados.'),
        AjudaItem('Ponto vermelho', 'consumidor sem cobertura.'),
      ]),
    ],
  );

  // ─────────────────────────── Perfis de gateway ───────────────────────────

  /// Explicação de cada campo do perfil (tooltip ao lado do campo).
  static const campoFrequencia =
      'Faixa de rádio do equipamento. LoRa no Brasil: 915 MHz.';
  static const campoPotencia =
      'Força com que o gateway transmite. Quanto maior, mais longe o sinal chega. Comum: 14 a 27 dBm (padrão Tecsys: 21).';
  static const campoGanho =
      'Reforço que a antena dá ao sinal. Comum: 0 a 6 dBi (padrão Tecsys: 0).';
  static const campoSensibilidade =
      'Sinal mais fraco que o rádio ainda consegue ouvir. Quanto MAIS NEGATIVO, melhor o rádio. '
      'LoRa: -110 a -140 dBm (padrão Tecsys: -120).';
  static const campoAlturaGateway =
      'Altura da antena do gateway no poste. Mais alto enxerga mais longe (o horizonte de rádio aumenta). Padrão: 6 m.';
  static const campoAlturaSensor =
      'Altura em que o sensor fica instalado. Padrão: 5 m.';
  static const campoPerda =
      'Quanto árvores e construções enfraquecem o sinal. 0 = campo aberto; 10 a 30 dB em área urbana. '
      'Com perda, a potência e a sensibilidade passam a mudar o alcance.';

  static const perfis = AjudaTela(
    titulo: 'Perfis de gateway',
    objetivo:
        'Um perfil guarda os parâmetros de rádio de um modelo de gateway. O projeto usa o perfil escolhido no cálculo do alcance.',
    passos: [
      'Para criar, clique em Novo perfil (ou em Duplicar no perfil padrão) e preencha os campos.',
      'O perfil padrão (Tecsys) não pode ser alterado: duplique e ajuste a cópia.',
      'Um perfil usado em algum projeto não pode ser excluído.',
    ],
    secoes: [
      AjudaSecao('Campos', [
        AjudaItem('Frequência (MHz)', campoFrequencia),
        AjudaItem('Potência de transmissão (dBm)', campoPotencia),
        AjudaItem('Ganho da antena (dBi)', campoGanho),
        AjudaItem('Sensibilidade de recepção (dBm)', campoSensibilidade),
        AjudaItem('Altura da antena do gateway (m)', campoAlturaGateway),
        AjudaItem('Altura do sensor (m)', campoAlturaSensor),
        AjudaItem('Perda adicional (dB)', campoPerda),
      ]),
      AjudaSecao('Como o alcance é calculado', [
        AjudaItem('Força do sinal',
            'potência − sensibilidade + ganho − perda. Quanto maior, mais longe o sinal chega.'),
        AjudaItem('Horizonte de rádio',
            'por causa da curvatura da Terra, antenas baixas não se enxergam além de alguns km (≈19 km com 6 m e 5 m).'),
        AjudaItem('Alcance usado',
            'o menor dos dois. Além disso, o relevo bloqueia o sinal onde há morros no caminho.'),
      ]),
    ],
  );

  // ─────────────────────────── ETL ───────────────────────────

  static const etl = AjudaTela(
    titulo: 'ETL & Geodados',
    objetivo:
        'Carrega no sistema os dados da rede elétrica (BDGD da ANEEL) e pontos próprios por planilha CSV. Só administradores.',
    passos: [
      'Clique em Enviar arquivo e arraste um .zip da BDGD ou um .csv de pontos. O sistema descobre o tipo pelo arquivo.',
      '.zip: o sistema lê o arquivo, lista as cidades e você escolhe quais carregar (com ou sem baixa tensão).',
      '.csv: escolha a distribuidora e o município, confira a prévia e importe. Para uma rede sem BDGD, use "+ Outra distribuidora".',
      'Acompanhe o andamento e o resultado no histórico de cargas.',
    ],
    secoes: [
      AjudaSecao('Planilha CSV', [
        AjudaItem('Colunas',
            'id;latitude;longitude;papel;descricao (separadas por ponto e vírgula). Baixe o modelo no próprio modal.'),
        AjudaItem('papel',
            'candidato (local para gateway), ponto_a_cobrir (sensor que precisa de sinal) ou interesse (só referência).'),
        AjudaItem('Linhas rejeitadas',
            'aparecem no resumo com o motivo (ex.: latitude fora da faixa, id repetido).'),
      ]),
      AjudaSecao('Histórico', [
        AjudaItem('Detalhes',
            'mostra o que foi carregado em cada tabela, os avisos e, no CSV, os pontos importados.'),
        AjudaItem('Cancelar',
            'descarta um envio que ainda espera a escolha das cidades.'),
      ]),
    ],
  );

  // ─────────────────────────── Usuários ───────────────────────────

  static const usuarios = AjudaTela(
    titulo: 'Usuários',
    objetivo:
        'Cadastro de quem acessa o sistema e o que cada um pode fazer. Só administradores.',
    passos: [
      'Clique em Novo Usuário e informe nome, e-mail, perfil e uma senha inicial.',
      'Passe o e-mail e a senha inicial para a pessoa. No primeiro acesso, ela troca a senha.',
      'Use a busca e o filtro de perfil para achar um usuário.',
      'Esqueceu a senha? Clique na chave do cartão do usuário e defina uma senha temporária. '
          'No próximo acesso, ele cria uma senha nova.',
    ],
    secoes: [
      AjudaSecao('Perfis', [
        AjudaItem('Administrador',
            'acessa tudo, inclusive ETL & Geodados e Usuários.'),
        AjudaItem('Usuário',
            'cria e consulta projetos, relatórios e perfis de gateway.'),
      ]),
    ],
  );
}
