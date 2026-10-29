# J'ai choisi node:22-alpine car l'API du garage est écrite en Node.js, et alpine garde l'image légère pour le petit PC de l'atelier.
FROM node:22-alpine

# J'ai mis NODE_ENV=production car l'API est utilisée tous les jours par les mécaniciens : dans ce mode, server.js n'affiche
# pas chaque requête dans les logs (avec NODE_ENV=development, il les affiche pour corriger un bug).
ENV NODE_ENV=production
# J'ai mis APP_PORT en ARG (argument du build) car EXPOSE ne peut pas lire une variable d'environnement du run : docker compose
# lui donne la valeur du .env au build, comme ça EXPOSE, PORT et la config de Nginx ont toujours le même port.
ARG APP_PORT=3000
# J'ai mis le port dans une variable pour pouvoir le changer sans modifier le code de mon API (le .env peut le remplacer au run).
ENV PORT=${APP_PORT}
# J'ai mis le chemin du fichier des réparations dans une variable pour que mon API sache où lire reparations.json.
ENV DATA_FILE=/app/data/reparations.json

# J'ai choisi /app comme dossier de travail pour ranger le code de mon API au même endroit, et WORKDIR le crée pour moi.
WORKDIR /app

# J'ai créé le dossier data pour y ranger le fichier des réparations, et je le donne à "node" pour que mon API puisse écrire dedans.
RUN mkdir -p /app/data && chown node:node /app/data

# J'ai copié seulement server.js car c'est le seul fichier dont mon API a besoin pour fonctionner.
# J'ai mis --chown pour que le fichier appartienne à "node", l'utilisateur qui lance mon API.
COPY --chown=node:node server.js .

# J'ai mis USER node pour que l'API ne tourne pas en root, car elle contient les infos des clients (moto, immatriculation)
# et si quelqu'un l'attaque, il n'a pas tous les droits.
USER node

# J'ai mis un volume sur /app/data pour que les réparations ne soient pas perdues quand je supprime le conteneur,
# sinon les mécaniciens ne sauraient plus quelles motos réparer, ni ce qui a déjà été fait.
# Le fichier reparations.json n'est donc pas dans mon dossier de projet, c'est mon API qui le crée dans le volume au premier lancement.
# Pour le voir, il faut taper "docker compose exec back cat /app/data/reparations.json", ou Docker Desktop > Volumes > projet1_garage-data.
VOLUME ["/app/data"]

# J'ai mis EXPOSE pour noter le port de mon API, c'est celui que Nginx utilise pour lui envoyer les requêtes /api/.
# EXPOSE n'ouvre aucun port sur le PC (c'est "ports" dans le compose qui le fait), c'est juste une indication.
EXPOSE ${APP_PORT}

# J'ai mis un healthcheck pour que Docker sache si l'API répond vraiment, et pas seulement si le conteneur est allumé :
# si elle ne répond plus, les mécaniciens ne voient plus leurs réparations.
# J'appelle /api/reparations car c'est la route principale de l'appli, et j'utilise wget car il est déjà dans alpine.
# J'ai écrit $PORT au lieu de 3000 pour que le healthcheck marche aussi si le port est changé dans le .env.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:$PORT/api/reparations || exit 1

# J'ai mis STOPSIGNAL SIGTERM pour dire clairement à Docker quel signal envoyer à l'arrêt (c'est déjà la valeur par défaut) :
# server.js l'attrape, finit les requêtes en cours puis quitte.
STOPSIGNAL SIGTERM

# J'ai mis "node server.js" (forme exec, avec des crochets) pour que node soit le processus 1 du conteneur et reçoive SIGTERM directement,
# sans passer par npm car je n'ai pas de package.json.
CMD ["node", "server.js"]
