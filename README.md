# Planejamento de Cobertura de RF para Redes de Sensores — Inception


## Sobre o Projeto
Este projeto foi desenvolvido como parte de uma iniciativa da Tecsys, empresa especializada em telecomunicações e eletrônica, com atuação consolidada no mercado B2B de utilities, incluindo sensores e dispositivos de comunicação para redes de distribuição de energia elétrica.

Com o objetivo de otimizar o planejamento de infraestrutura de comunicação por radiofrequência, o projeto propõe o desenvolvimento de uma solução capaz de utilizar informações geográficas de ativos da rede elétrica — obtidas a partir da Base de Dados Geográfica da Distribuidora (BDGD/ANEEL) e, opcionalmente, de coordenadas importadas pelo usuário — em conjunto com parâmetros de cobertura de radiofrequência, para propor a melhor combinação de gateways/ERBs capaz de atender aos pontos de interesse com o mínimo de equipamento necessário.

O cálculo de cobertura considera fatores como frequência, potência de transmissão, sensibilidade de recepção, altura dos equipamentos, distância e relevo do terreno, de forma parametrizável — permitindo a avaliação de diferentes cenários sem valores fixos no código.

## Contexto de Aplicação
A solução foi projetada para atender ao segmento de utilities de energia elétrica, mais especificamente distribuidoras que precisam planejar a infraestrutura de comunicação para monitoramento de ativos da rede [2]. Nesse cenário, o sistema é dimensionado para:

* Trabalhar com grandes volumes de dados geográficos de forma computacionalmente eficiente, sem análise exaustiva de todas as combinações possíveis;
* Permitir a seleção flexível de quais ativos da rede (independente do nível de tensão) servem como candidatos à instalação de gateways e quais servem como pontos a serem cobertos;
* Suportar dados de diferentes distribuidoras e regiões geográficas, sem ficar restrito a um único conjunto de dados;
* Apresentar indicadores que permitam avaliar a qualidade do resultado obtido.

---

## Requisitos Funcionais (RF)
* **01 - Consumo de Dados BDGD:** Importação de ativos da rede elétrica a partir da BDGD/ANEEL (CSV e Geodatabase) e de coordenadas via CSV externo.
* **02 - Consumo de Dados de Relevo:** Obtenção de dados de elevação do terreno para a região analisada.
* **03 - Motor de Decisão (nº máximo de gateways):** Dado um número máximo de gateways, calcular a melhor cobertura possível dentro dessa quantidade.
* **04 - Peso/Criticidade por Ponto:** Priorização de pontos de maior importância na análise de cobertura.
* **05 - Mapa Interativo:** Visualização geográfica dos pontos, candidatos, mancha de cobertura e topologia da rede.
* **06 - Indicadores de Resultado:** Apresentação de indicadores técnicos (percentual de cobertura, quantidade de gateways, dispositivos atendidos, capacidade utilizada) e comparação entre cenários.
* **07 - Importação de Pontos via CSV:** Cadastro de coordenadas externas à BDGD para uso como candidato, ponto a cobrir ou ponto de interesse.
* **08 - Persistência de Projetos:** Salvamento e retomada de projetos e cenários analisados.
* **09 - Desempenho com Grande Volume de Dados:** Processamento eficiente do app e do motor de decisão mesmo em regiões com grande quantidade de candidatos e pontos.

## Requisitos Não Funcionais (RNF)
* **Manual de Instalação e Manual do Usuário:** Documentação disponibilizada no Git.
* **Parametrização:** Nenhum valor de cálculo de RF (frequência, potência, sensibilidade, altura) deve ficar fixo no código.
* **Processamento Eficiente:** Capacidade de processar conjuntos extensos de dados geográficos sem análise exaustiva de todas as combinações possíveis
* **Suporte a Múltiplas Distribuidoras:** A aplicação não deve ficar restrita a um único conjunto de dados ou região geográfica.

---

## Estrutura de Épicos (Backlog no Taiga)

| RF | Rank | Prioridade | User Story | Estimativa | Sprint |
| --- | --- | --- | --- | --- | --- |
| **02, 05, 09** | 1 | Alta | **[Épico 1: Ingestão de Dados]** Como planejador de rede, quero realizar a leitura de dados da ANEEL/BDGD, importar CSVs externos e consumir a API de relevo para alimentar a base de dados do sistema. | 8 | **1** |
| **04, 09** | 2 | Alta | **[Épico 28: Backend & API]** Como desenvolvedor, quero estruturar os serviços REST, regras de negócio e integração com o banco espacial para dar suporte operacional ao sistema. | 8 | **1** |
| **09** | 3 | Alta | **[Épico 24: Interface Web]** Como usuário, quero acessar uma interface web intuitiva para navegar e controlar as funcionalidades do sistema de planejamento. | 5 | **1** |
| **02, 04, 09** | 4 | Alta | **[Épico 2: Motor de Decisão]** Como planejador de rede, quero executar a otimização matemática de cobertura RF respeitando o teto de gateways e o raio de cobertura para determinar o melhor posicionamento da infraestrutura. | 13 | **2** |
| **03, 09** | 5 | Média | **[Épico 3: Mapa Interativo]** Como usuário, quero visualizar os ativos e manchas de cobertura em um mapa geoespacial interativo e comparar cenários para analisar espacialmente o planejamento. | 8 | **2** |
| **09** | 6 | Média | **[Épico 5: Persistência de Projetos]** Como usuário, quero salvar, carregar e versionar cenários de planejamento para manter o histórico dos meus estudos. | 5 | **2** |
| **02, 09** | 7 | Média | **[Épico 4: Relatório & Indicadores]** Como gestor, quero gerar métricas operacionais (% de cobertura, uso de capacidade e pontos não atendidos) para avaliar o desempenho do planejamento. | 8 | **3** |
| **09** | 8 | Média | **[Épico 20: UI/UX & Desempenho]** Como usuário, quero uma renderização fluida de grandes volumes de pontos geográficos na interface para navegar pelo mapa sem travamentos. | 5 | **3** |


---

## Definition of Ready (DoR)
Para que uma User Story seja considerada pronta para entrar em uma Sprint, ela deve obrigatoriamente cumprir os seguintes critérios:

* [x] **User Story Clara:** A história de usuário descreve o "quem", "o quê" e o "porquê" (valor de negócio).
* [x] **Regras de Negócio Detalhadas:** As regras associadas à funcionalidade estão descritas.
* [x] **Dados Definidos:** Os dados a armazenar foram definidos, com tipos e validações.
* [x] **Mensagens Definidas:** Mensagens de confirmação, erro e aviso foram especificadas.
* [x] **Esboço de Tela:** Um esboço da(s) tela(s) envolvida(s) foi criado.

## Definition of Done (DoD)
* [x] Código passou por Code Review.
* [x] Pull Request aprovado por outros membros da equipe.
* [x] Testes de regressão executados, sem impacto em funcionalidades existentes.
* [x] Manual do usuário atualizado (quando aplicável).
* [x] Manual de instalação atualizado (quando aplicável).
---

##  Entregas de Sprints

| Sprint | Previsão de entrega | Status | Histórico |
|:--:|:----------:|:-------------------|:-------------------------------------------------:|
| 01 | 07/09/2026 a 27/09/2026 | Em breve | [Ver relatório]() |
| 02 | 05/10/2026 a 25/10/2026 | Em breve | [Ver relatório]() |
| 03 | 02/11/2026 a 22/11/2026 | Em breve | [Ver relatório]() |


---

##  Equipe

|    Função     | Nome                                  |                                                                                                                                                      LinkedIn & GitHub                                                                                                                                                      |
| :-----------: | :------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  Scrum Master  | Matheus Ramos               |   [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/matheusfcrms/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/KwMajor)   |
| Product Owner   | Matheus Karnas      |         [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/matheuskarnas/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/matheuskarnas)        |
| Team Member   | Gabriel Lima |      [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/gabriel-fernando-bb430b330/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/Gabriel-Fernando-Lima)     |
|  Team Member  | Lavinia Piratello               |   [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/lavinia-piratello-6a82101b1/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/laviniappiratello)   |
|  Team Member  | Lucas Araujo                 |         [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/lucas-araujo-448115329/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/LucasAraujo1016)        |
|  Team Member  | Lucas Guerra     |           [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/lucas-guerra000/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/lucasguerra12)   |
|  Team Member  | Lucas Martins               |   [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/lucasmscarmo/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/LucasMSCarmo)   |
|  Team Member  | Giovanni Kanjiscuk              |   [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/giovanni-kanjiscuk/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/GKanjiscuk)   |
|  Team Member  | Nicoly Guedes              |   [![Linkedin Badge](https://img.shields.io/badge/Linkedin-blue?style=flat-square&logo=Linkedin&logoColor=white)](https://www.linkedin.com/in/nicoly-guedes-dev/) [![GitHub Badge](https://img.shields.io/badge/GitHub-111217?style=flat-square&logo=github&logoColor=white)](https://github.com/nicolygz)   |