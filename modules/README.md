# ETL (modules)

Scripts Python que carregam a BDGD/ANEEL no PostGIS: a geodatabase (`.gdb`) da distribuidora, recortada pelos municípios escolhidos, e os consumidores de média e alta tensão (CSVs da ANEEL). Em produção são executados pelo backend como subprocesso; também podem ser executados direto pela linha de comando.

## 1. O que faz e com quem conversa

| Interlocutor | Direção | Canal | Finalidade |
|---|---|---|---|
| Backend | quem aciona | Subprocesso `python etl_cli.py ...`; resposta por stdout | Inspeção e carga disparadas pela tela ETL (perfil `ADM`) |
| PostGIS | saída | SQLAlchemy/GeoAlchemy2 (`ETL_DB_URL`) | Gravação da rede e dos consumidores |
| API de malhas do IBGE | entrada | HTTPS (`IBGE_MALHAS_URL`, padrão `servicodados.ibge.gov.br/api/v4/malhas/municipios`) | Limite oficial de cada município, usado no recorte |
| ANEEL dados abertos | entrada | HTTPS (CSV `ucat_pj`, `ucmt_pj`) | Consumidores de alta e média tensão |
| Geodatabase `.gdb` ou `.zip` | entrada | Arquivo (GDAL/pyogrio) | Rede, subestações, transformadores e baixa tensão |

Protocolo por stdout (lido pelo backend):

| Prefixo | Conteúdo |
|---|---|
| `ETL_ETAPA:` | Texto da etapa atual (exibido no card da tela ETL) |
| `ETL_INSPECAO:` | JSON da inspeção: distribuidora, período, municípios |
| `ETL_RESULT:` | JSON do resumo final: métricas por tabela e avisos |

O ETL no sistema, com tudo o que entra e o que sai:

```mermaid
flowchart LR
    BE["Backend<br/>tela ETL (perfil ADM)"]
    CLI["etl_cli.py<br/>--inspecionar ou carga"]
    GDB[/"Geodatabase<br/>.gdb ou .zip"/]
    IBGE["API de malhas do IBGE<br/>limite do município"]
    ANEEL["ANEEL dados abertos<br/>CSV ucat_pj e ucmt_pj"]
    PG[("PostGIS<br/>ETL_DB_URL")]

    BE ==>|"subprocesso Python"| CLI
    CLI -.->|"stdout: ETL_ETAPA,<br/>ETL_INSPECAO, ETL_RESULT"| BE
    GDB -->|"GDAL / pyogrio"| CLI
    IBGE -->|"HTTPS"| CLI
    ANEEL -->|"HTTPS"| CLI
    CLI ==>|"SQLAlchemy / GeoAlchemy2"| PG

    classDef ext fill:#f5f5f5,stroke:#757575,color:#0d1b2a
    classDef svc fill:#e0f2f1,stroke:#006a60,color:#0d1b2a
    classDef cli fill:#fff3e0,stroke:#e65100,color:#0d1b2a
    class GDB,IBGE,ANEEL,PG ext
    class BE svc
    class CLI cli
```

## 2. Como executar e testar

### Pelo backend (uso normal)

A imagem do backend já contém Python 3.12 e as dependências (venv em `/opt/etl-venv`). Fluxo na aplicação: tela **ETL & Geodados** → upload da `.gdb`/`.zip` → inspeção → escolha dos municípios → carga. Ver [`Backend/tecsys/DOCKER.md`](../Backend/tecsys/DOCKER.md).

### Pela linha de comando

```bash
cd modules
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # ETL_DB_URL=postgresql+psycopg2://usuario:senha@localhost:5433/tecsys

# 1) Inspeção (não grava nada): distribuidora, período e municípios existentes no arquivo
python etl_cli.py --gdb /caminho/arquivo.zip --inspecionar

# 2) Carga: códigos IBGE de 7 dígitos, separados por vírgula (ex.: 3549904 = São José dos Campos)
python etl_cli.py --gdb /caminho/arquivo.zip --municipios 3549904

# Só a geodatabase, sem baixar/gravar os CSVs da ANEEL
python etl_cli.py --gdb /caminho/arquivo.zip --municipios 3549904 --sem-consumidores
```

`--gdb` aceita a pasta `.gdb` ou o `.zip` que a contém (lido sem descompactar, via `/vsizip/`). O banco precisa ter o schema criado pelas migrations do Flyway (ver [`db/DOCKER.md`](../db/DOCKER.md)).

| Variável | Padrão | Descrição |
|---|---|---|
| `ETL_DB_URL` | obrigatória | Conexão SQLAlchemy do banco de destino |
| `IBGE_MALHAS_URL` | API v4 de malhas do IBGE | Origem dos limites municipais |
| `CACHE_DIR` | `cache_aneel` | Cache dos CSVs da ANEEL (no Docker, volume `tecsys-aneel-cache`) |

O módulo não possui testes automatizados.

## 3. Resumo de funcionalidades

| Arquivo | Função |
|---|---|
| `etl_cli.py` | Ponto de entrada: `--inspecionar`, carga, `--sem-consumidores`; emite o protocolo de stdout |
| `inspecao_gdb.py` | Lê só atributos (sem geometria): distribuidora, período (camada `BASE`) e municípios com contagem de transformadores (`UNTRMT`) e consumidores de baixa tensão (`UCBT_tab`) |
| `geodatabase_edp_sp.py` | Carga da rede: recorte pela malha do IBGE, integridade referencial, prefixo de distribuidora, gravação idempotente |
| `baixa_tensao_gdb.py` | Carga dos consumidores de baixa tensão, agregados por ponto de conexão |
| `etl_bdgd.py` | Carga de `ucat_pj` e `ucmt_pj` (CSVs da ANEEL), filtrados por município e distribuidora |
| `etl_common.py` | Utilitários: leitura de `.gdb`/`.zip`, validação de códigos IBGE, download com retomada, carga idempotente, prefixos, métricas |

Tabelas gravadas: `sub`, `untrat`, `untrmt`, `ssdat`, `ssdmt`, `ssdbt`, `ucat_pj`, `ucmt_pj`, `ucbt`.

### Baixa tensão

A carga da `.gdb` inclui consumidores de baixa tensão, inclusive residenciais (camadas `UCBT_tab` e `PONNOT`). Para caber no Supabase gratuito (500 MB), a baixa tensão é gravada **um registro por ponto de conexão + classe + CNAE**, com a quantidade de consumidores em `ucbt.qtd_consumidores`. Em Vitória, 166.534 consumidores viram 37.973 registros. O motor usa essa quantidade como peso, então a cobertura do relatório é contada em consumidores. O antigo `preload_ucbt.py` (CSV nacional da ANEEL, só não residenciais) não é mais usado (#TG-144).

## 4. Decisões técnicas e arquitetura

### Fluxo da carga

1. **Distribuidora.** Lida da camada `sub`; a geodatabase deve ter exatamente uma distribuidora, senão a carga é rejeitada.
2. **Limite dos municípios.** Baixado da API de malhas do IBGE (com 3 tentativas), convertido para EPSG:4674 (SIRGAS 2000) e unido numa única área.
3. **Recorte.** Cada camada é lida com máscara espacial e filtrada por `intersects(area)` e por situação ativa (`SIT_ATIV = 'AT'`). Geometrias são normalizadas ao tipo esperado e strings vazias viram nulo.
4. **Pais fora da área.** Transformadores e subestações referenciados por filhos recortados, mas fora da área, são buscados na geodatabase original, para preservar a topologia.
5. **Integridade.** Chaves estrangeiras sem pai são anuladas com aviso e contadas nas métricas.
6. **Gravação**, em uma transação, na ordem pais → folhas, com prefixo de distribuidora e carga idempotente.
7. **Baixa tensão** da própria `.gdb` e, salvo `--sem-consumidores`, **consumidores de média e alta tensão** dos CSVs da ANEEL.

O mesmo fluxo em diagrama:

```mermaid
flowchart TD
    S1["1. Distribuidora<br/>camada sub"]
    REJ["Carga rejeitada"]
    S2["2. Limite dos municípios<br/>API do IBGE, EPSG:4674, união"]
    S3["3. Recorte<br/>máscara espacial e SIT_ATIV = 'AT'"]
    S4["4. Pais fora da área<br/>buscados na .gdb original"]
    S5["5. Integridade<br/>chaves sem pai anuladas"]
    S6["6. Gravação em uma transação<br/>pais → folhas, prefixo, idempotente"]
    S7["7. Baixa tensão<br/>da própria .gdb"]
    Q{"--sem-consumidores?"}
    S8["Consumidores de média e alta tensão<br/>CSVs da ANEEL"]
    FIM(["Resumo ETL_RESULT"])

    S1 -->|"mais de uma"| REJ
    S1 ==>|"exatamente uma"| S2 ==> S3 ==> S4 ==> S5 ==> S6 ==> S7 ==> Q
    Q -->|"não"| S8 --> FIM
    Q -->|"sim"| FIM

    classDef step fill:#e0f2f1,stroke:#006a60,color:#0d1b2a
    classDef bad fill:#ffebee,stroke:#c62828,color:#0d1b2a
    classDef dec fill:#fff3e0,stroke:#e65100,color:#0d1b2a
    classDef ok fill:#e8f5e9,stroke:#2e7d32,color:#0d1b2a
    class S1,S2,S3,S4,S5,S6,S7,S8 step
    class REJ bad
    class Q dec
    class FIM ok
```

### Recorte pela malha do IBGE

O recorte usa o limite oficial do município, não um polígono desenhado. Pontos na divisa podem diferir entre o cadastro da distribuidora e o limite do IBGE; os consumidores de baixa tensão fora do limite são contabilizados nas métricas (`fora_do_municipio`).

### Carga idempotente

`carregar_idempotente` grava o lote numa tabela de staging temporária e insere com `ON CONFLICT (pk) DO NOTHING`. Executar a mesma carga de novo não duplica registros: o resumo informa `inseridos` e `ignorados_ja_existentes` por tabela. Linhas com chave nula ou repetida são descartadas e contadas.

Consequências:
- Linhas já existentes **não são atualizadas** pela recarga. A exceção é `dist`, preenchido nas linhas antigas que o tinham nulo (`preencher_dist_nulo`).
- `ucbt` segue outra regra: reenviar a `.gdb` dos mesmos municípios **substitui** a baixa tensão deles (`DELETE` por distribuidora e município, depois inserção).
- Texto maior que o limite da coluna gera erro, exceto nas colunas listadas em `truncar`, que são truncadas e contadas.

### Prefixo para a segunda distribuidora

Os códigos da BDGD (`cod_id`, `cod_id_encr`, `sub`, `uni_tr_at`, `uni_tr_mt`, `ctmt`, `ctat`) podem colidir entre distribuidoras. `decidir_prefixo` resolve:

| Situação no banco | Prefixo aplicado |
|---|---|
| Nenhuma subestação carregada (banco vazio) | nenhum: a primeira distribuidora mantém os códigos originais |
| A distribuidora já tem subestações | mantém a convenção já usada por ela (`<DIST>:` se os códigos existentes têm prefixo, senão nenhum) |
| Há outras distribuidoras e esta é nova | `<DIST>:` |

A carga também rejeita subestações cujo `cod_id` já pertença a outra distribuidora. O campo `dist` é gravado sem prefixo (é por ele que o filtro do mapa casa).

A mesma regra como árvore de decisão:

```mermaid
flowchart TD
    A{"Há alguma subestação<br/>carregada no banco?"}
    A -->|"não"| N1["Sem prefixo<br/>a primeira distribuidora mantém<br/>os códigos originais"]
    A -->|"sim"| B{"Esta distribuidora já tem<br/>subestações no banco?"}
    B -->|"sim"| C{"Os códigos existentes<br/>têm prefixo?"}
    C -->|"sim"| P1["Prefixo DIST:"]
    C -->|"não"| N2["Sem prefixo"]
    B -->|"não"| P2["Prefixo DIST:<br/>distribuidora nova com outras já carregadas"]

    classDef dec fill:#fff3e0,stroke:#e65100,color:#0d1b2a
    classDef none fill:#e3f2fd,stroke:#1565c0,color:#0d1b2a
    classDef pre fill:#e8f5e9,stroke:#2e7d32,color:#0d1b2a
    class A,B,C dec
    class N1,N2 none
    class P1,P2 pre
```

### Robustez

- Download dos CSVs da ANEEL com retomada por `Range` (arquivo `.part`) e até 5 tentativas.
- A inspeção lê apenas atributos, então leva segundos mesmo em arquivos grandes.
- Falha na carga retorna código de saída 1 e o backend registra o erro no job de ETL.
