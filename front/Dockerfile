# J'ai choisi node:22-alpine car le front du garage est écrit en Node.js, et alpine garde l'image légère pour le petit PC de l'atelier.
# J'ai fixé la version 22 pour que le front marche pareil sur tous les PC du garage, même si Node sort une nouvelle version.
FROM node:22-alpine

# J'ai mis NODE_ENV=production car le front est utilisé tous les jours par les mécaniciens, ce n'est pas une version de test.
ENV NODE_ENV=production
# J'ai mis le port dans une variable pour pouvoir le changer sans modifier le code de mon front (le .env peut le remplacer).
ENV PORT=3000

# J'ai choisi /app comme dossier de travail pour ranger le code de mon front au même endroit, et WORKDIR le crée pour moi.
WORKDIR /app

# Je n'ai pas copié package.json : mon CMD lance node directement, donc je n'ai pas besoin du script "start" de npm
# (il reste dans le projet pour lancer le front à la main avec "npm start", hors Docker).
# J'ai copié server.js car c'est lui qui affiche la liste des réparations aux mécaniciens.
# J'ai mis --chown pour que les fichiers appartiennent à "node", l'utilisateur qui lance mon front.
COPY --chown=node:node server.js .

# J'ai mis USER node pour que le front ne tourne pas en root, comme ça si quelqu'un l'attaque, il n'a pas tous les droits.
USER node

# J'ai mis EXPOSE 3000 pour noter le port de mon front, c'est celui que Nginx utilise pour lui envoyer les requêtes /app/.
EXPOSE 3000

# J'ai mis un healthcheck pour que Docker sache si la liste des réparations s'affiche vraiment, et pas seulement si le conteneur est allumé.
# J'utilise wget car il est déjà dans alpine, comme ça je n'installe rien en plus.
# J'ai écrit $PORT au lieu de 3000 pour que le healthcheck marche aussi si le port est changé dans le .env.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:$PORT/ || exit 1

# J'ai mis STOPSIGNAL SIGTERM pour dire clairement à Docker quel signal envoyer à l'arrêt (c'est déjà la valeur par défaut) :
# server.js l'attrape, finit les requêtes en cours puis quitte.
STOPSIGNAL SIGTERM

# J'ai mis "node server.js" (forme exec, avec des crochets) pour que node soit le processus 1 du conteneur et reçoive SIGTERM directement.
# Avant j'avais "npm start" : npm lance node comme un sous-processus et ne lui transmet pas bien SIGTERM,
# donc Docker finissait par tuer le conteneur (SIGKILL). En plus, ça enlève le processus npm (moins de RAM).
CMD ["node", "server.js"]
