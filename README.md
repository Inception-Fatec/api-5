 # Planejamento de Cobertura de RF para Redes de Sensores — Inception


## Sobre o Projeto

Este projeto foi desenvolvido como parte de uma iniciativa da Tecsys, empresa especializada em telecomunicações e eletrônica, com atuação consolidada no mercado B2B de utilities, incluindo sensores e dispositivos de comunicação para redes de distribuição de energia elétrica.


Com o objetivo de otimizar o planejamento de infraestrutura de comunicação por radiofrequência, o projeto propõe o desenvolvimento de uma solução capaz de utilizar informações geográficas de ativos da rede elétrica — obtidas a partir da Base de Dados Geográfica da Distribuidora (BDGD/ANEEL) e, opcionalmente, de coordenadas importadas pelo usuário — em conjunto com parâmetros de cobertura de radiofrequência, para propor a melhor combinação de gateways/ERBs capaz de atender aos pontos de interesse com o mínimo de equipamento necessário.


O cálculo de cobertura considera fatores como frequência, potência de transmissão, sensibilidade de recepção, altura dos equipamentos, distância e relevo do terreno, de forma parametrizável — permitindo a avaliação de diferentes cenários sem valores fixos no código.


## Contexto de Aplicação

A solução foi projetada para atender ao segmento de utilities de energia elétrica, mais especificamente distribuidoras que precisam planejar a infraestrutura de comunicação para monitoramento de ativos da rede. Nesse cenário, o sistema é dimensionado para:


    Trabalhar com grandes volumes de dados geográficos de forma computacionalmente eficiente, sem análise exaustiva de todas as combinações possíveis; 


    Permitir a seleção flexível de quais ativos da rede (independente do nível de tensão) servem como candidatos à instalação de gateways e quais servem como pontos a serem cobertos; 


    Suportar dados de diferentes distribuidoras e regiões geográficas, sem ficar restrito a um único conjunto de dados; 


    Apresentar indicadores que permitam avaliar a qualidade do resultado obtido. 



---


## Arquitetura e Fluxo de Cálculo


A solução adota uma arquitetura desacoplada em microsserviços e módulos de processamento espacial:

### Fluxo de Cálculo de Ponta a Ponta:

    **Configuração do Cenário:** O usuário define na interface web (Frontend) os parâmetros de RF (frequência, potência, sensibilidade, alturas), seleciona os ativos candidatos e fixa o teto máximo de gateways.
    **Recebimento e Validação:** O Backend valida o token JWT stateless da requisição e envia os parâmetros para o Motor de Decisão.
    **Análise de Visada (Topografia):** O Motor recupera o arquivo raster de elevação (GeoTIFF) obtido via OpenTopography e calcula a visada (Line of Sight) considerando o relevo do terreno entre candidatos e pontos.
    **Otimização de Cobertura (Set Cover):** Com a matriz de visada e alcance calculada, o Motor executa o algoritmo guloso (*Set Cover*) otimizado sobre estruturas **BitSet** para selecionar a combinação ótima de gateways.
    **Persistência e Exibição:** O Backend persiste o resultado no banco PostgreSQL/PostGIS. O Frontend consulta os dados e renderiza as manchas de cobertura e clusters de pontos calculados por grade no PostGIS. 


---


## Como Rodar em 3 Passos


### Pré-requisitos

    Docker e Docker Compose instalados.
    Dump da base de dados (`bdgd.dump`) na raiz do módulo de banco (`db/`).
    Chave de API da OpenTopography. 


### Passo 1: Configurar a Base de Dados

Insira o arquivo `bdgd.dump` dentro do diretório `db/` e configure a chave da OpenTopography no arquivo `.env` da raiz do projeto.


### Passo 2: Executar o Script de Subida

No terminal da raiz do projeto, execute:

```bash

chmod +x ./scripts/up-local.sh

./scripts/up-local.sh
### Passo 3: Acessar a Aplicação
- **Frontend Web:** `http://localhost:8080`
- **Backend API:** `http://localhost:3000`
- **Motor de Decisão:** `http://localhost:5000`

### Documentação detalhada por módulo:
- [Backend API (`Backend/tecsys/README.md`)](./Backend/tecsys/README.md)
- [Motor de Decisão (`MOTOR/README.md`)](./MOTOR/README.md)
- [Frontend Flutter (`Frontend/README.md`)](./Frontend/README.md)
- [Módulo ETL (`modules/README.md`)](./modules/README.md)
- [Scripts de Automação (`scripts/README.md`)](./scripts/README.md)
- [Infraestrutura de Banco de Dados (`db/DOCKER.md`)](./db/DOCKER.md)
