# Test duck-ui

L'interface Duck-UI

C'est une interface web moderne, open source, optimisée pour DuckDB et propulsée par WebAssembly (WASM). Elle se déploie en 2 secondes et te permet de glisser-déposer tes Parquet ou d'aller les chercher dans un volume.

Elle s'exécute entièrement dans ton navigateur via WebAssembly (WASM). Par défaut, elle n'a pas besoin de base de données backend car elle utilise la puissance de ton navigateur pour faire tourner le moteur DuckDB.

```
version: '3.8'

services:
  duck-ui:
    image: ghcr.io/caioricciuti/duck-ui:latest
    container_name: duck-ui
    ports:
      - "5522:5522"
    volumes:
      # On monte ton dossier contenant les fichiers Parquet
      - ./data:/data:ro
    restart: unless-stopped
```

`docker compose -f docker-compose-duck-ui-yml up -d`

Ok sur http://localhost:5522/

Voir https://duckdb.org/

Ok pour jouer mais ... nous avons Apache Superset !

# DuckDB engine + Superset

Superset ne sait pas lire un fichier Parquet directement (il a besoin d'une base de données SQL/SQLAlchemy).

- Avant, il fallait monter un cluster Trino/Presto ou un ClickHouse (très lourd pour du dév ou du processing intermédiaire).

- Aujourd'hui, on utilise DuckDB directement embarqué (In-Process) dans Superset. DuckDB traite le Parquet à la vitesse du C++, supporte le multi-threading, sait lire le partitionnement Hive et ne consomme rien au repos.

---------

Test :

- start : `docker compose up -d --build`
- init ok ? `docker logs -f superset-init`
- check `docker logs -f superset-init`
- PGADMIN : http://localhost:5050/browser/
- SF : http://localhost:8088/superset/welcome/
- SQL SQLALCHEMY connexion : `duckdb:///:memory:`

Cette syntaxe indique à Superset d'initialiser une instance DuckDB en mémoire vive volatile. C'est idéal et ultra-rapide pour requêter tes fichiers Parquet montés en lecture seule.

Dans SQL LAB
`SELECT * FROM read_parquet('/data/stations.parquet') `

DuckDB comprendra que le fichier Parquet externe est la source de données, peu importe le schéma sélectionné dans l'interface de Superset.

Tu enregistres cette requête en tant que "Dataset". Désormais, tu peux faire du Drag & Drop pour créer tes graphiques (Bar Chart, Camembert, Séries temporelles) exactement comme si tes fichiers Parquet étaient une base PostgreSQL classique.


## La nature "Schema-on-Read" du format Parquet

Pas besoin de sélectionner de schéma (ou tu peux laisser le champ vide/par défaut) !

Contrairement à PostgreSQL ou Oracle où les tables et leurs schémas (colonnes, types) doivent être créés et structurés à l'avance dans un schéma logique (comme public), le fichier Parquet est auto-descriptif. Il contient ses propres métadonnées (le schéma de tes données y est déjà inscrit par ton traitement Java).
Lorsque tu exécutes read_parquet(), DuckDB lit ce schéma à la volée lors de la lecture. Il n'a donc pas besoin d'un conteneur de schéma relationnel classique pour comprendre la structure.

Contrairement à une base de données relationnelle classique où les jointures se font en mémoire vive du serveur SQL en exploitant des index (B-Tree), un fichier Parquet est un format colonnaire, immuable et auto-descriptif.

C'est DuckDB qui va agir comme un moteur SQL relationnel virtuel. Il va charger les métadonnées des fichiers Parquet, indexer temporairement les colonnes de jointure en mémoire vive (via un algorithme de Hash Join ultra-performant en C++), et exécuter la jointure exactement comme le ferait un PostgreSQL.


# Alternative "Cloud-Native" pour l'Architecture : La Stack MotherDuck

Si tes fichiers Parquet grossissent (plusieurs dizaines de Go), ou qu'ils sont générés directement dans un Cloud Storage (AWS S3, MinIO, Azure Blob) par tes 14 microservices Java, le DuckDB local dans le conteneur Superset peut saturer la RAM de ta machine.

L'alternative d'architecte : Utiliser MotherDuck (l'extension Cloud / SaaS de DuckDB, qui a un tiers gratuit très généreux).

- Le principe : Tes fichiers Parquet restent sur ton S3 ou MinIO. MotherDuck s'occupe de faire le requêtage lourd dans le cloud (Serverless Data Warehouse).

- Côté Superset : Tu branches Superset à MotherDuck en changeant simplement l'URI : duckdb:///md:nom_de_db?motherduck_token=ton_token.

- Avantage : Ton conteneur Superset reste ultra-léger et ne sature jamais, peu importe la taille du fichier Parquet

https://motherduck.com/


# Si problème WSL (en local)

localhost inaccessible ...

- Passer WSL en mode mirrored (Fortement recommandé)
- Le conflit d'IPv6 (Fréquent avec le mode Mirrored)

```
galloisg@FR-JX6QWL3 MINGW64 ~
$ cat .wslconfig
[wsl2]
dnsTunneling=true
networkingMode=Mirrored
# Désactive l'IPv6 si le réseau d'entreprise ne le gère pas proprement avec WSL
vmSwitchProperties=disable_ipv6=true
```