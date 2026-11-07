# Relevo do motor: Copernicus GLO-30 no AWS Open Data

Este documento explica como o motor obtém o relevo depois da migração da
OpenTopography para o Copernicus DEM GLO-30 público no AWS Open Data.

Para o contexto técnico usado por agentes de IA, veja
[`docs/ai/MOTOR_AWS_IMPLEMENTATION_REFERENCE.md`](ai/MOTOR_AWS_IMPLEMENTATION_REFERENCE.md).

## Resumo

- Fonte: `https://copernicus-dem-30m.s3.amazonaws.com`
- Acesso: público e anônimo. **Não precisa de conta AWS, chave ou cota diária.**
- Dados: Copernicus DEM GLO-30, DSM de 30 m, release 2021, tiles COG de 1° x 1°.
- Cache local: volume Docker `tecsys-dem-cache` ou `DEM_CACHE_DIR`.
- Mirror opcional: diretório local/NAS em `DEM_MIRROR_DIR`, montado read-only.
- Ordem de busca: **cache → mirror → S3**.
- Se o relevo não puder ser obtido, o projeto termina em `FALHA`. Não existe
  queda silenciosa para terreno plano.

## Cobertura inicial

- São José dos Campos
- Caçapava
- Campos do Jordão

A Serra da Mantiqueira ficou fora do escopo por enquanto.

Os tiles são de 1° x 1°. A caixa de São José dos Campos, Caçapava e Campos do
Jordão normalmente usa poucos tiles, por exemplo:

- `Copernicus_DSM_COG_10_S24_00_W047_00_DEM`
- `Copernicus_DSM_COG_10_S24_00_W046_00_DEM`
- `Copernicus_DSM_COG_10_S23_00_W047_00_DEM`
- `Copernicus_DSM_COG_10_S23_00_W046_00_DEM`

A lista exata depende da margem calculada pelo motor. Use o script de
sincronização para calcular e baixar os tiles da bbox real.

## Configuração

As variáveis ficam em `MOTOR/.env.properties` (modo local) ou
`MOTOR/.env.supabase` (modo Supabase):

```properties
# Opcional: mirror local/NAS. Caminho no host.
DEM_MIRROR_DIR=/mnt/tecsys-dem-mirror

# Opcionais
DEM_DOWNLOAD_ATTEMPTS=4
DEM_RETRY_BACKOFF_MS=5000
DEM_AWS_BASE_URL=https://copernicus-dem-30m.s3.amazonaws.com
```

Não existe mais `OPENTOPOGRAPHY_API_KEY`.

## Cache

O cache novo fica em:

```text
<DEM_CACHE_DIR>/aws-copernicus/<tile>/<tile>.tif
```

No container, `DEM_CACHE_DIR=/var/cache/tecsys-dem`, e o volume Docker
`tecsys-dem-cache` preserva os arquivos entre reinícios.

O cache antigo da OpenTopography (`indice.json` e `dem_<hash>.tif`) é
preservado, mas ignorado pelo fluxo novo. Ele serve para rollback, comparação
e uso futuro. Não apague automaticamente.

## Mirror local/NAS

O mirror é opcional. Ele serve para evitar downloads repetidos e para permitir
operação com o S3 indisponível.

Layout aceito:

```text
<DEM_MIRROR_DIR>/<tile>/<tile>.tif
```

Também é aceito o layout plano:

```text
<DEM_MIRROR_DIR>/<tile>.tif
```

### Montagem NFS

Exemplo de montagem no host Docker:

```bash
sudo mkdir -p /mnt/tecsys-dem-mirror
sudo mount -t nfs <servidor-nas>:/<export> /mnt/tecsys-dem-mirror
```

Para montagem persistente, adicione ao `/etc/fstab`:

```fstab
<servidor-nas>:/<export> /mnt/tecsys-dem-mirror nfs ro,defaults 0 0
```

O motor monta o diretório read-only dentro do container:

```bash
-v /mnt/tecsys-dem-mirror:/var/cache/tecsys-dem-mirror:ro
-e DEM_MIRROR_DIR=/var/cache/tecsys-dem-mirror
```

O `scripts/run-motor.sh` faz isso automaticamente quando `DEM_MIRROR_DIR` está
definido no arquivo de ambiente.

### Montagem SMB

Se a infraestrutura usar SMB:

```bash
sudo mkdir -p /mnt/tecsys-dem-mirror
sudo mount -t cifs //<servidor>/<share> /mnt/tecsys-dem-mirror \
  -o ro,username=<usuario>,uid=$(id -u),gid=$(id -g)
```

O restante é igual: aponte `DEM_MIRROR_DIR` para o diretório montado.

### Sem NAS

Se `DEM_MIRROR_DIR` estiver vazio, o motor usa somente cache e S3. Os testes
automatizados usam diretórios temporários e não dependem de NAS.

Se `DEM_MIRROR_DIR` estiver configurado mas o diretório não existir ou não
estiver montado, o motor registra um aviso e continua com o S3.

## Sincronização do mirror

O script baixa os tiles via HTTPS público do S3, sem AWS CLI e sem
credenciais:

```bash
./scripts/sync-dem-mirror.sh \
  --mirror-dir /mnt/tecsys-dem-mirror \
  --bbox -23.37,-22.93,-46.07,-45.53
```

Ou por lista explícita de tiles:

```bash
./scripts/sync-dem-mirror.sh \
  --mirror-dir /mnt/tecsys-dem-mirror \
  --tiles Copernicus_DSM_COG_10_S23_00_W046_00_DEM
```

O script:

- calcula os tiles de uma bbox;
- valida o domínio suportado;
- baixa para `<mirror>/<tile>/<tile>.tif`;
- verifica o cabeçalho TIFF;
- atualiza `<mirror>/manifest.sha256`.

O `--bbox` usa a ordem `south,north,west,east`, em graus decimais.

## Domínio geográfico

O motor aceita:

- latitude entre **-50° e +50°**;
- longitude entre **-180° e +180°**;
- `south < north`;
- `west < east`, sem cruzar o antimeridiano.

Fora disso, o cálculo falha com mensagem clara. O motivo é que os tiles
Copernicus mudam de resolução acima de 50° e o mosaico atual assume tamanho de
pixel constante. Todas as áreas atuais do projeto estão dentro do domínio.

## Falhas

- Caixa fora do domínio: falha antes de qualquer acesso à rede.
- Cache corrompido: o arquivo é removido e baixado de novo.
- Mirror ausente ou corrompido: aviso e tentativa pelo S3.
- S3 com erro após as tentativas: falha com o nome do tile, HTTP e URL.
- Conteúdo que não é TIFF float32: falha e não grava no cache.
- Sem relevo e `MOTOR_USE_TERRAIN=true`: projeto em `FALHA`.

`MOTOR_USE_TERRAIN=false` gera terreno plano e serve apenas para testes de UI.
Ele não deve ser usado para validação real de cobertura.

## Licença e atribuição

O Copernicus DEM é disponibilizado sob a licença Copernicus DEM. A atribuição
é obrigatória quando o produto é comunicado ao público ou distribuído.

Aviso oficial para a versão GLO-30:

> © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided
> under COPERNICUS by the European Union and ESA; all rights reserved

Quando os dados forem adaptados ou modificados, use o aviso de produto
derivado:

> produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus
> Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European
> Union and ESA; all rights reserved

Inclua essa atribuição em relatórios, telas e materiais distribuídos que usem
o relevo do motor. Para citação científica, o DOI recomendado é
<https://doi.org/10.5270/ESA-c5d3d65>.

Referências:

- Registry of Open Data on AWS: <https://registry.opendata.aws/copernicus-dem/>
- Readme do bucket: <https://copernicus-dem-30m.s3.amazonaws.com/readme.html>
- Página oficial do Copernicus DEM:
  <https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM>

## Testes

Testes normais, sem rede:

```bash
cd MOTOR
mvn test -Dtest='*,!MotorApplicationTests'
```

O `MotorApplicationTests` sobe o contexto Spring e precisa de `DB_URL`,
`DB_USER` e `DB_PASSWORD`.

O teste de rede é opt-in:

```bash
cd MOTOR
mvn test -Dtest=DemServiceNetworkTest -DexcludedGroups=
```

O fixture real pequeno fica em
`MOTOR/src/test/resources/dem/aws-copernicus/` e tem metadados em `SOURCE.md`.

## Rollback

O código antigo da OpenTopography pode ser restaurado pelo histórico do Git.
O cache antigo continua no volume. Para voltar a usar a OpenTopography seria
necessário reintroduzir a chave e o código antigo; a migração atual não faz
fallback automático.
