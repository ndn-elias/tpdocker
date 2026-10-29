# J'ai choisi Nginx car il sert la page d'accueil du garage et redirige les mécaniciens vers le front et l'API.
# J'ai fixé la version 1.27 pour que le serveur marche pareil partout, et alpine garde l'image légère pour le petit PC de l'atelier.
FROM nginx:1.27-alpine

# J'ai mis une valeur par défaut au port du front et de l'API, pour que Nginx marche même si le .env ne le donne pas.
ENV APP_PORT=3000

# J'ai copié ma config dans le dossier "templates" car c'est elle qui envoie /app/ vers mon front et /api/ vers mon API,
# et dans ce dossier l'image Nginx remplace ${APP_PORT} par la valeur du .env au démarrage.
COPY nginx.conf /etc/nginx/templates/default.conf.template

# J'ai copié index.html car c'est la page d'accueil du garage, avec les liens vers la liste des réparations.
COPY index.html /usr/share/nginx/html/index.html

# J'ai mis EXPOSE 80 car c'est le port par lequel les mécaniciens entrent dans l'appli du garage.
EXPOSE 80

# J'ai mis un healthcheck pour que Docker sache si l'entrée de l'appli répond vraiment, et pas seulement si le conteneur est allumé.
# J'utilise wget car il est déjà dans alpine, comme ça je n'installe rien en plus.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1

# J'ai mis STOPSIGNAL SIGQUIT car Nginx s'arrête "en douceur" avec ce signal : il finit les requêtes en cours puis quitte
# (avec SIGTERM il coupe tout de suite). L'image nginx le fait déjà, je l'écris pour que ce soit clair.
STOPSIGNAL SIGQUIT

# Je n'ai pas mis de CMD car l'image Nginx démarre déjà le serveur toute seule : son entrypoint lance nginx avec "exec",
# donc nginx est le processus 1 du conteneur et reçoit directement le signal d'arrêt.
