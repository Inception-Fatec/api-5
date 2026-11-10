# Planejamento de Cobertura de RF para Redes de Sensores — Inception

## Sobre o Projeto

Este projeto foi desenvolvido como parte de uma iniciativa da Tecsys, empresa especializada em telecomunicações e eletrônica, com atuação consolidada no mercado B2B de utilities, incluindo sensores e dispositivos de comunicação para redes de distribuição de energia elétrica.

Com o objetivo de otimizar o planejamento de infraestrutura de comunicação por radiofrequência, o projeto propõe o desenvolvimento de uma solução capaz de utilizar informações geográficas de ativos da rede elétrica — obtidas a partir da Base de Dados Geográfica da Distribuidora (BDGD/ANEEL) e, opcionalmente, de coordenadas importadas pelo usuário — em conjunto com parâmetros de cobertura de radiofrequência, para propor a melhor combinação de gateways/ERBs capaz de atender aos pontos de interesse com o mínimo de equipamento necessário.

O cálculo de cobertura considera fatores como frequência, potência de transmissão, sensibilidade de recepção, altura dos equipamentos, distância e relevo do terreno, de forma parametrizável — permitindo a avaliação de diferentes cenários sem valores fixos no código.

## Contexto de Aplicação

A solução foi projetada para atender ao segmento de utilities de energia elétrica, mais especificamente distribuidoras que precisam planejar a infraestrutura de comunicação para monitoramento de ativos da rede. Nesse cenário, o sistema é dimensionado para:

* Trabalhar com grandes volumes de dados geográficos de forma computacionalmente eficiente, sem análise exaustiva de todas as combinações possíveis;
* Permitir a seleção flexível de quais ativos da rede (independente do nível de tensão) servem como candidatos à instalação de gateways e quais servem como pontos a serem cobertos;
* Suportar dados de diferentes distribuidoras e regiões geográficas, sem ficar restrito a um único conjunto de dados;
* Apresentar indicadores que permitam avaliar a qualidade do resultado obtido.

---

## Quickstart

Sobe a stack completa (banco, backend, motor e frontend) com PostGIS local.

**Pré-requisitos:** Docker com o plugin `docker compose`, usuário no grupo `docker`, `openssl`, e as portas 5433, 8080, 8081 e 8082 livres.

**1. Banco de dados: colocar o `bdgd.dump`.**
Obtenha o arquivo com a equipe e salve em `db/bdgd.dump` (ignorado pelo Git). Na primeira subida, `run-db.sh` cria o schema pelas migrations do Flyway e carrega os dados da rede a partir do dump.

**2. Segredo do JWT.**
O backend não sobe sem `API_SECURITY_TOKEN_SECRET` (mínimo de 32 bytes). Crie o arquivo `.env` na raiz do repositório (ignorado pelo Git):

```bash
echo "API_SECURITY_TOKEN_SECRET=$(openssl rand -hex 32)" > .env
```

O motor de decisão obtém o relevo do Copernicus GLO-30 (AWS Open Data) e **não requer chave de API** (a chave da OpenTopography foi removida na #TG-139).

**3. Subir a stack.**

```bash
./scripts/up-local.sh
```

| Serviço | URL |
|---|---|
| Aplicação (frontend) | http://localhost:8080 |
| API (backend) | http://localhost:8081 (Swagger: `/swagger-ui.html`) |
| Motor de decisão | http://127.0.0.1:8082 (interno; sem autenticação) |
| Banco | `postgres://tecsys:tecsys@localhost:5433/tecsys` |

Login inicial: `admin@tecsys.com.br` / `admin123` (criado pela migration V9; trocar em qualquer ambiente compartilhado).
Para parar: `./scripts/up-local.sh --stop` (os dados permanecem no volume `tecsys-pgdata`).

Variantes (banco no Supabase, subida por serviço, `docker compose`) e solução de problemas: [`scripts/README.md`](scripts/README.md).

---

## Arquitetura

### Visão geral

```mermaid
flowchart LR
    FE["Frontend<br/>Flutter Web (nginx :8080)"] -->|"REST /api/v1 + JWT"| BE["Backend<br/>Spring Boot :8081"]
    BE -->|JDBC| DB[("PostgreSQL 17<br/>+ PostGIS :5433")]
    BE -->|"POST /api/calculate<br/>{project_id}"| MT["Motor de decisão<br/>Spring Boot :8082"]
    MT -->|JDBC| DB
    MT -->|"tiles GLO-30<br/>cache, mirror, S3"| DEM[("Copernicus DEM<br/>AWS Open Data")]
    BE -->|"subprocesso<br/>etl_cli.py"| ETL["ETL<br/>Python (modules/)"]
    ETL -->|SQLAlchemy| DB
    ETL -->|malhas municipais| IBGE["API de malhas do IBGE"]
    ETL -->|"CSV ucat_pj, ucmt_pj"| ANEEL["ANEEL dados abertos"]
```

| Camada | Diretório | Tecnologia | Responsabilidade |
|---|---|---|---|
| Frontend | [`Frontend/`](Frontend/README.md) | Flutter (Web) | Autenticação, projetos, mapa, relatório, tela de ETL |
| Backend | [`Backend/tecsys/`](Backend/tecsys/README.md) | Java 17, Spring Boot 3.3 | API REST, JWT, regras de negócio, orquestração do ETL e do motor |
| Motor | [`MOTOR/`](MOTOR/README.md) | Java 17, Spring Boot, OR-Tools | Cálculo de cobertura e otimização do número de gateways |
| Banco | [`db/`](db/DOCKER.md) | PostgreSQL 17 + PostGIS 3.6 | Rede elétrica, projetos, resultados; schema versionado pelo Flyway (no backend) |
| ETL | [`modules/`](modules/README.md) | Python 3.12, GeoPandas | Carga da BDGD (geodatabase e CSVs da ANEEL) no banco |
| Scripts | [`scripts/`](scripts/README.md) | Bash, Docker | Subida e parada dos serviços |

O frontend fala apenas com o backend. O backend é o único que chama o motor e o único que dispara o ETL. O motor e o ETL gravam diretamente no banco.

### Fluxo de um cálculo, de ponta a ponta

1. **Autenticação.** `POST /api/v1/auth/login` retorna um JWT (HMAC-SHA256, validade de 2 h). O frontend guarda o token em armazenamento seguro e o envia em `Authorization: Bearer`.
2. **Definição do projeto.** O usuário escolhe distribuidora e municípios (`GET /api/v1/distribuidoras`, `GET /api/v1/distribuidoras/{dist}/municipios`), filtros (camadas, classe, CNAE, bairro) e, opcionalmente, um polígono no mapa.
3. **Pré-visualização.** O mapa consulta `POST /api/v1/points/filter`. Com zoom afastado, o backend devolve bolhas agrupadas por grade (`ST_SnapToGrid` no PostGIS); com zoom próximo, devolve os pontos individuais dentro da viewport.
4. **Disparo.** `POST /api/v1/simulation/run` (`name`, `dist_code`, `geometry`, `filter_params`). O backend grava o projeto (`CRIADO`), grava em `project_history` o polígono e os filtros, muda o status para `ENVIADO` e chama o motor de forma assíncrona (`POST /api/calculate` com `{"project_id": N}`; a resposta é descartada).
5. **Cálculo.** O motor lê os critérios em `project_history` (aguarda até 5 s o commit do backend), valida que há área, município, conjunto ou subestação, e marca `PROCESSANDO`. Em seguida:
   1. carrega pontos a cobrir (`ucbt`, `ucmt_pj`, `ucat_pj`) e candidatos a gateway (`untrmt`, `untrat`) e agrupa pontos coincidentes em "locais";
   2. obtém o relevo (cache, mirror, catálogo, S3) e o lê como float32;
   3. calcula a visada de cada candidato (viewshed por raios, com curvatura da Terra) e monta a matriz esparsa de cobertura;
   4. resolve a cobertura de conjuntos (guloso, busca local, solver exato HiGHS ou LNS conforme o tamanho);
   5. grava `summary`, `gateways` e `points` em `project_coverage` e marca `SUCESSO`. Qualquer erro, inclusive `Error` da JVM, marca `FALHA`.
6. **Resultado.** O frontend acompanha o status por polling na lista de projetos. Em `SUCESSO`, lê `GET /api/v1/reports/projects/{id}/coverage` e exibe relatório, indicadores e mapa, com exportação em PDF.

### Fluxo de carga de dados (ETL)

Executado pelo perfil `ADM` na tela **ETL & Geodados**: upload da `.gdb` (ou `.zip`) → inspeção (distribuidora e municípios disponíveis) → escolha dos municípios → carga. Detalhes em [`modules/README.md`](modules/README.md).

---

## Módulos

| Módulo | Documentação |
|---|---|
| Backend | [`Backend/tecsys/README.md`](Backend/tecsys/README.md), [`Backend/tecsys/DOCKER.md`](Backend/tecsys/DOCKER.md) |
| Motor de decisão | [`MOTOR/README.md`](MOTOR/README.md), [`docs/MOTOR_RELEVO_AWS.md`](docs/MOTOR_RELEVO_AWS.md) |
| Frontend | [`Frontend/README.md`](Frontend/README.md), [`Frontend/DOCKER.md`](Frontend/DOCKER.md) |
| ETL | [`modules/README.md`](modules/README.md) |
| Banco | [`db/DOCKER.md`](db/DOCKER.md) |
| Scripts | [`scripts/README.md`](scripts/README.md) |

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
* **Processamento Eficiente:** Capacidade de processar conjuntos extensos de dados geográficos sem análise exaustiva de todas as combinações possíveis.
* **Suporte a Múltiplas Distribuidoras:** A aplicação não deve ficar restrita a um único conjunto de dados ou região geográfica.

---

## Estrutura de Épicos (Backlog no Taiga)

| RF | Rank | Prioridade | User Story | Estimativa | Sprint |
| --- | --- | --- | --- | --- | --- |
| **02, 05, 09** | 1 | Alta | **[Épico 1: Ingestão de Dados]** Como planejador de rede, quero realizar a leitura de dados da ANEEL/BDGD, importar CSVs externos e consumir a API de relevo para alimentar a base de dados do sistema. | 8 | **1** |
| **04, 09** | 2 | Alta | **[Épico 28: Backend & API]** Como desenvolvedor, quero estruturar os serviços REST, regras de negócio e integração com o banco espacial para dar suporte operacional ao sistema. | 8 | **1** |
| **09** | 3 | Alta | **[Épico 24: Interface Web]** Como usuário, quero acessar uma interface web intuitiva para navegar e controlar as funcionalidades do sistema de planejamento. | 5 | **1** |
| **02, 03, 04, 09** | 4 | Alta | **[Épico 2: Motor de Decisão]** Como planejador de rede, quero executar a otimização matemática de cobertura RF respeitando o teto de gateways e o raio de cobertura para determinar o melhor posicionamento da infraestrutura. | 13 | **2** |
| **05, 09** | 5 | Média | **[Épico 3: Mapa Interativo]** Como usuário, quero visualizar os ativos e manchas de cobertura em um mapa geoespacial interativo e comparar cenários para analisar espacialmente o planejamento. | 8 | **2** |
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

## Entregas de Sprints

| Sprint | Período | Status | Código |
|:--:|:----------:|:-------------------|:-------------------:|
| 01 | 07/09/2026 a 27/09/2026 | Concluída | [`sprint-1`](https://github.com/Inception-Fatec/api-5/tree/sprint-1) |
| 02 | 05/10/2026 a 25/10/2026 | Concluída | [`sprint-2`](https://github.com/Inception-Fatec/api-5/tree/sprint-2) |
| 03 | 02/11/2026 a 22/11/2026 | Em andamento | [`dev`](https://github.com/Inception-Fatec/api-5/tree/dev) |

---

## Documentação complementar (Taiga)

* [Contexto para IA](https://tree.taiga.io/project/matheuskarnas-tecsys/wiki/contexto-para-ia): visão consolidada do projeto, convenções e decisões para uso em assistentes de código.
* [Problemas conhecidos](https://tree.taiga.io/project/matheuskarnas-tecsys/wiki/problemas-conhecidos): defeitos e limitações em aberto, com contorno quando existir.

Documentos de referência em [`docs/`](docs/): desafio do parceiro, documento consolidado da BDGD, modelo de banco de dados PostGIS e [`MOTOR_RELEVO_AWS.md`](docs/MOTOR_RELEVO_AWS.md).

---

## Equipe

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
