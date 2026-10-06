# Projet Docker

J'ai fait 3 conteneurs : un front, un back et un serveur web.
Ils affichent juste "Hello World".

Le but c'est de faire comme un petit "cloud" : chaque partie tourne dans son propre conteneur
et on lance tout en même temps avec docker compose.

## Technologies utilisées

- **Front et back** : Node.js (image `node:22-alpine`)
- **Serveur web** : Nginx (image `nginx`)
- **Docker Compose** : pour lancer les 3 conteneurs ensemble

Je n'ai utilisé aucune librairie en plus. Pour Node, j'utilise juste le module `http` qui est
déjà inclus dedans.

## Lancer le projet

Il faut avoir Docker installé. Dans le dossier du projet :

```bash
docker compose up --build
```

Ensuite aller sur :

- front : http://localhost:3001
- back : http://localhost:3002
- serveur web : http://localhost:3003

Pour tout arrêter :

```bash
docker compose down
```

## Schéma

![Schéma de l'architecture](schema.svg)

L'utilisateur accède à chaque conteneur avec un port différent sur son PC (3001, 3002, 3003).
Les 3 conteneurs sont lancés par le même docker compose.

## Les fichiers du projet

```
docker-compose.yml   -> lance les 3 conteneurs
schema.svg           -> le schéma
front/
    Dockerfile
    package.json     -> contient la commande "npm start"
    server.js        -> le code du front
back/
    Dockerfile
    server.js        -> le code du back
serveur-web/
    Dockerfile
    nginx.conf       -> la config de Nginx
    index.html       -> la page affichée
```

## Le code

Le front et le back ont presque le même code (`server.js`) :

```js
const http = require("http");

http
  .createServer((req, res) => {
    res.end("Hello World depuis le front");
  })
  .listen(3000);
```

- `require("http")` : on prend le module http de Node
- `createServer` : on crée un serveur, et à chaque requête il répond "Hello World"
- `listen(3000)` : le serveur écoute sur le port 3000

Pour le front, il y a aussi un `package.json`. Il sert à dire ce que fait `npm start` :

```json
"scripts": {
  "start": "node server.js"
}
```

## Les Dockerfiles

### Front

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

- `FROM` : on part d'une image avec Node.js déjà installé (alpine car c'est plus léger)
- `WORKDIR` : on se met dans le dossier `/app` (il est créé s'il n'existe pas)
- `COPY . .` : on copie nos fichiers du dossier `front/` dans `/app`
- `EXPOSE` : on indique que l'appli utilise le port 3000
- `CMD` : la commande lancée quand le conteneur démarre, ici `npm start`

### Back

C'est pareil que le front, sauf la dernière ligne :

```dockerfile
CMD ["node", "server.js"]
```

Ici on lance directement le fichier avec `node`, sans passer par `npm`. Du coup pas besoin
de `package.json` pour le back.

### Serveur web

Pour le serveur web j'utilise Nginx :

```dockerfile
FROM nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
```

- `FROM` : on part de l'image Nginx
- `COPY nginx.conf` : on remplace la config de base de Nginx par la nôtre
- `COPY index.html` : on met notre page Hello World dans le dossier que Nginx affiche

Il faut faire des `COPY` car le conteneur ne voit pas les fichiers de mon PC, il faut les
mettre dedans au moment du build.

Pas besoin de `CMD`, l'image Nginx lance déjà le serveur toute seule.

Ma config `nginx.conf` :

```nginx
server {
    listen 80;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

- `listen 80` : Nginx écoute sur le port 80
- `root` : le dossier où sont les pages
- `index` : la page à afficher par défaut

### Pas de dépendances

Je n'installe rien dans mes images (pas de `npm install`, pas de `apt install`). Tout ce dont
j'ai besoin est déjà dans les images de base. Les images sont personnalisées avec mes propres
fichiers (code, config, page HTML).

## Docker compose

```yaml
services:
  front:
    build: ./front
    ports:
      - "3001:3000"
    cpus: 0.5
    mem_limit: 128m

  back:
    build: ./back
    ports:
      - "3002:3000"
    cpus: 0.5
    mem_limit: 128m

  serveur-web:
    build: ./serveur-web
    ports:
      - "3003:80"
    cpus: 0.5
    mem_limit: 128m
```

Pour chaque conteneur j'ai mis :

- `build` : le dossier où se trouve le Dockerfile
- `ports` : pour ouvrir le conteneur sur mon PC. Par exemple `3001:3000` veut dire que le
  port 3001 de mon PC envoie vers le port 3000 du conteneur.
- `cpus: 0.5` : le conteneur peut utiliser au maximum la moitié d'un CPU
- `mem_limit: 128m` : le conteneur peut utiliser au maximum 128 Mo de RAM

Le front et le back utilisent tous les deux le port 3000 dans leur conteneur, mais ce n'est
pas un problème car chaque conteneur est séparé. Par contre sur mon PC il faut des ports
différents, c'est pour ça que j'ai mis 3001 et 3002.

Si on lançait sans docker compose, ce serait par exemple pour le front :

```bash
docker build -t front ./front
docker run -p 3001:3000 --cpus 0.5 --memory 128m front
```

## Commandes utiles

```bash
docker compose ps          # voir les conteneurs qui tournent
docker compose logs        # voir les logs des conteneurs
docker stats               # voir le CPU et la RAM utilisés par chaque conteneur
docker compose down        # tout arrêter et supprimer les conteneurs
```

Avec `docker stats`, on voit bien la limite de 128 Mo dans la colonne `MEM USAGE / LIMIT`.
