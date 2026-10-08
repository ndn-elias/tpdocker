# Projet Docker : To-Do List d'un garage moto

Le sujet de mon projet est une **To-Do List pour un garage moto** : les mécaniciens voient la liste
des réparations à faire sur chaque moto (modèle, immatriculation, travail à faire) et ce qui est
déjà fait.

Il y a 3 conteneurs :

- **front** : la page avec la liste des réparations
- **back** : l'API qui renvoie les réparations (stockées dans un fichier JSON)
- **serveur-web** : Nginx, le seul point d'entrée, qui redirige vers le front et le back

## Technologies utilisées

- **Front et back** : Node.js avec le module `http` natif, sans aucune dépendance (image `node:22-alpine`)
- **Stockage des réparations** : un fichier JSON (`reparations.json`), lu avec le module `fs` natif
  de Node, et gardé dans un volume Docker
- **Serveur web** : Nginx avec une configuration `nginx.conf` personnalisée et une page `index.html`
  statique (image `nginx:1.27-alpine`)
- **Docker Compose** : pour lancer les 3 conteneurs ensemble

Je n'ai utilisé aucune librairie en plus (pas de `npm install`).

## Pourquoi ces choix pour un garage moto

- **Volume** : les réparations ne doivent pas être perdues, sinon les mécaniciens ne savent plus
  quelles motos réparer ni ce qui a déjà été fait
- **Pas de root, réseau privé, ports du back fermés** : l'API contient des infos clients (moto,
  immatriculation), personne ne doit y accéder sans passer par Nginx
- **Nginx comme seule entrée** : les mécaniciens n'ont qu'une adresse à retenir
- **restart et healthcheck** : l'appli sert toute la journée, si elle plante elle doit revenir
  toute seule
- **depends_on** : le matin à l'ouverture, un mécanicien ne doit pas tomber sur une page d'erreur
- **alpine et limites CPU / RAM** : l'appli tourne sur le petit PC de l'atelier, qui doit garder de
  la puissance pour le reste

## Lancer le projet

Il faut avoir Docker installé. Dans le dossier du projet, créer d'abord le fichier `.env` à partir
du modèle (sans lui, l'appli démarre quand même avec les valeurs par défaut) :

```bash
cp .env.example .env
```

Puis lancer les conteneurs :

```bash
docker compose up --build
```

Ensuite aller sur :

- accueil (Nginx) : http://localhost:8080
- la liste des réparations (front) : http://localhost:8080/app/
- les réparations en JSON (back) : http://localhost:8080/api/reparations

Pour tout arrêter :

```bash
docker compose down
```

Les réparations restent gardées dans le volume. Pour supprimer aussi le volume :

```bash
docker compose down -v
```

## Schéma

![Schéma de l'architecture](schema.svg)

Le mécanicien passe uniquement par Nginx (port 8080). Nginx envoie :

- `/` vers sa page `index.html`
- `/app/` vers le conteneur front
- `/api/` vers le conteneur back

Le front et le back ne sont pas accessibles directement depuis le PC, seulement par le réseau
interne `garage-network`.

En orange, le fichier `.env` : docker compose le lit au lancement, puis passe à chaque conteneur
seulement les variables dont il a besoin (avec `environment`).

## Les fichiers du projet

```
docker-compose.yml   -> lance les 3 conteneurs
.env.example         -> modèle de configuration (à copier en .env)
.env                 -> la configuration du garage (pas poussé sur git)
benchmark.bat        -> le script de benchmark (à lancer depuis cmd)
schema.svg           -> le schéma
front/
    Dockerfile
    package.json     -> contient la commande "npm start"
    server.js        -> la page avec la liste des réparations
back/
    Dockerfile
    server.js        -> l'API qui lit reparations.json
serveur-web/
    Dockerfile
    nginx.conf       -> la config de Nginx (reverse proxy), avec ${APP_PORT} remplacé au démarrage
    index.html       -> la page d'accueil du garage
```

## Le code

### Back

Le back répond sur `/api/reparations` avec les réparations du fichier `reparations.json`. Au
premier lancement, le fichier n'existe pas, donc le back le crée avec deux réparations d'exemple :

- une Yamaha MT-07 : vidange et plaquettes de frein (**à faire**)
- une Honda XL 750 Transalp : révision des 24 000 km (jeu aux soupapes, vidange, bougies, filtre
  à air, filtre à huile, consommables) (**faite**)

- `require("fs")` : module natif de Node pour lire et écrire des fichiers
- `process.env.PORT` et `process.env.DATA_FILE` : le port et le chemin du fichier viennent des
  variables d'environnement définies dans le Dockerfile

### Front

Le front renvoie une page HTML. Dans la page, un petit script fait `fetch("/api/reparations")`
pour afficher les réparations. La requête passe par Nginx, qui l'envoie au back.

## Où est le fichier des réparations ?

Il n'est pas dans le dossier du projet : il est dans le volume Docker `projet1_garage-data`. Pour
le voir (avec les conteneurs lancés) :

```bash
docker compose exec back cat /app/data/reparations.json
```

Ou dans Docker Desktop : **Volumes** > `projet1_garage-data`.

## Les Dockerfiles

Toutes les instructions sont commentées directement dans les Dockerfiles. Ce que j'ai ajouté
par rapport à la version Hello World de base :

- **Version fixée** : `node:22-alpine` et `nginx:1.27-alpine` au lieu de `nginx` tout court, pour
  avoir toujours la même image (et alpine car c'est plus léger)
- **`ENV`** : `NODE_ENV=production`, le `PORT`, et pour le back le chemin `DATA_FILE` du JSON
- **`USER node`** : l'appli ne tourne pas en root (l'utilisateur `node` est déjà dans l'image)
- **`COPY --chown=node:node`** : les fichiers appartiennent à l'utilisateur `node`
- **`COPY` fichier par fichier** : on copie seulement ce qui est utile, pas tout le dossier
- **`VOLUME`** (back) : le dossier `/app/data` où est stocké `reparations.json`
- **`HEALTHCHECK`** : Docker vérifie régulièrement que le conteneur répond, avec `wget` qui est
  déjà dans alpine (pas de dépendance en plus)

## Docker compose

Toutes les instructions sont aussi commentées dans `docker-compose.yml`. Pour chaque conteneur :

- `build` : le dossier où se trouve le Dockerfile
- `restart: unless-stopped` : le conteneur redémarre tout seul s'il plante
- `networks` : les 3 conteneurs sont sur le réseau `garage-network`, ils se parlent avec leur nom
  (`front`, `back`), c'est pour ça que dans `nginx.conf` j'écris `http://back:${APP_PORT}`
- `cpus` et `mem_limit` : les limites CPU et RAM, choisies grâce aux benchmarks (voir plus bas)

En plus :

- `ports` : seulement sur `serveur-web` (`${NGINX_PORT}:80`, donc 8080 par défaut). Le front et le
  back n'ont pas de port ouvert sur le PC
- `environment` : chaque conteneur reçoit seulement les variables du `.env` dont il a besoin
- `volumes` : le volume `garage-data` est monté dans `/app/data` du back, donc les réparations ne
  sont pas perdues quand on supprime le conteneur
- `depends_on` avec `condition: service_healthy` : Nginx démarre seulement quand le front et le
  back sont prêts (grâce au healthcheck)

## Le fichier .env et le passage des variables

Toutes les valeurs qui peuvent changer d'un garage à l'autre sont dans le fichier `.env` :

| Variable | Valeur | Pourquoi elle est dans le .env |
|---|---|---|
| `NGINX_PORT` | `8080` | Le changer si un autre logiciel du garage utilise déjà ce port |
| `APP_PORT` | `3000` | Le port du front et de l'API, changé à un seul endroit pour les 3 conteneurs |
| `NODE_ENV` | `production` | Passer en `development` pour corriger un bug, sans reconstruire les images |
| `FRONT_CPUS`, `BACK_CPUS`, `NGINX_CPUS` | `0.25` | Adapter les limites à la taille du PC de l'atelier |
| `FRONT_MEM`, `BACK_MEM`, `NGINX_MEM` | `64m`, `32m`, `32m` | Adapter les limites à la taille du PC de l'atelier |

Comment les variables arrivent jusqu'aux conteneurs :

1. `docker compose` lit tout seul le fichier `.env` qui est à côté de `docker-compose.yml`
2. dans `docker-compose.yml`, j'écris `${APP_PORT:-3000}` : ça prend la valeur du `.env`, ou `3000`
   si elle n'existe pas
3. avec `environment:`, je passe à chaque conteneur seulement ce dont il a besoin (le front et l'API
   reçoivent `PORT` et `NODE_ENV`, Nginx reçoit `APP_PORT`)
4. pour Nginx, la config est copiée dans `/etc/nginx/templates/` : au démarrage, l'image Nginx
   remplace `${APP_PORT}` dans la config par sa vraie valeur

Les `ENV` des Dockerfiles restent comme valeurs par défaut : l'image marche même toute seule, et le
`.env` peut les remplacer.

Je n'ai pas mis `DATA_FILE` dans le `.env` : le fichier des réparations doit rester dans le dossier
du volume (`/app/data`), sinon les réparations seraient perdues.

Le `.env` n'est pas poussé sur git (il est dans le `.gitignore`) car chaque garage a sa propre
config. On pousse seulement le modèle `.env.example`.

Pour vérifier qu'une variable est bien arrivée dans un conteneur :

```bash
docker compose exec back printenv PORT
docker compose exec serveur-web grep proxy_pass /etc/nginx/conf.d/default.conf
```

## Benchmarks et limites de ressources

Pour choisir les limites CPU et RAM, j'ai mesuré ce que consomme chaque conteneur avec
`docker stats`, au repos puis pendant une charge. La charge est faite avec `ab` (Apache Bench) qui
envoie beaucoup de requêtes en même temps, comme si plusieurs mécaniciens chargeaient l'appli.
`ab` tourne dans un conteneur jetable (image `httpd:alpine`), donc rien n'est installé en plus.

Pour relancer le benchmark (conteneurs lancés), depuis cmd dans le dossier du projet :

```bash
benchmark.bat 3000 10
```

Le premier nombre est le nombre de requêtes, le deuxième le nombre de mécaniciens en même temps.

### Au repos

| Conteneur | CPU | RAM |
|---|---|---|
| front | 0 % | 32 Mo |
| back | 0 % | 9 Mo |
| serveur-web | 0 % | 10 Mo |

Le front prend plus de RAM car il est lancé avec `npm start` : il y a le processus `npm` en plus
de `node`.

### Pendant la charge

| Limites testées | Mécaniciens en même temps | Requêtes/s | Erreurs | Pic RAM front / back / nginx |
|---|---|---|---|---|
| 0.5 CPU, 128 Mo (mes limites de départ) | 50 | ~2360 | 0 | 37 / 13 / 12 Mo |
| **0.25 CPU, 64 / 32 / 32 Mo** | 10 | **~1100** | 0 | 37 / 14 / 11 Mo |
| 0.1 CPU, 64 / 32 / 32 Mo | 10 | ~480 | 0 | 45 / 13 / 11 Mo |

### Ce que j'en conclus

- **La RAM de départ (128 Mo) était beaucoup trop grande** : le pic le plus haut est de 45 Mo pour
  le front et 14 Mo pour l'API. J'ai mis environ 2 fois le pic : **64 Mo pour le front, 32 Mo pour
  l'API et Nginx**.
- **0.25 CPU par conteneur suffit** : plus de 1000 requêtes par seconde sans erreur, alors qu'un
  garage d'une dizaine de mécaniciens en fait à peine quelques-unes par seconde. Au total, les 3
  conteneurs utilisent au maximum 0.75 cœur, donc moins d'un cœur du PC de l'atelier.
- **Je ne suis pas descendu à 0.1 CPU** : ça marche encore, mais les requêtes les plus lentes
  passent de ~90 ms à ~200 ms. Je garde de la marge pour les jours où le PC de l'atelier est chargé.
- Avec Docker Desktop, un conteneur qui dépasse sa limite de RAM peut utiliser du swap (mémoire sur
  le disque) au lieu de planter : la limite sert surtout à protéger la mémoire du PC de l'atelier.
