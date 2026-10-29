# J'ai choisi node:22-alpine car eslint est un outil Node.js, et je garde la même base que le front et l'API (déjà téléchargée).
FROM node:22-alpine

# J'ai installé shellcheck avec apk car c'est l'outil qui vérifie les scripts shell (autoscale.sh, lint.sh).
# --no-cache évite de garder la liste des paquets dans l'image. Je n'ai pas fixé sa version car elle change avec la version d'alpine.
RUN apk add --no-cache shellcheck

# J'ai téléchargé le binaire de hadolint (le lint des Dockerfiles) depuis ses releases GitHub, car il n'est pas dans les paquets alpine.
# Le nom du fichier dépend du processeur du PC (Intel/AMD ou ARM), donc je regarde "uname -m" pour prendre le bon.
# Je fixe la version 2.12.0 pour que le lint donne le même résultat partout. chmod +x le rend exécutable.
RUN ARCH="$(uname -m)" \
 && case "$ARCH" in \
      x86_64)  FICHIER="hadolint-Linux-x86_64" ;; \
      aarch64) FICHIER="hadolint-Linux-arm64" ;; \
      *) echo "Processeur non géré : $ARCH" && exit 1 ;; \
    esac \
 && wget -qO /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/v2.12.0/$FICHIER" \
 && chmod +x /usr/local/bin/hadolint

# J'ai installé eslint avec npm, en global (-g) pour qu'il soit dans le PATH. Je fixe la version 9.17.0 :
# eslint change souvent son format de configuration d'une version majeure à l'autre.
# --no-fund --no-audit : npm n'affiche pas les messages inutiles. Je vide ensuite le cache npm pour alléger l'image.
RUN npm install -g --no-fund --no-audit eslint@9.17.0 \
 && npm cache clean --force

# J'ai copié les règles de chaque outil dans /etc/lint, hors du projet, pour qu'elles ne soient pas mélangées avec le code vérifié.
COPY eslint.config.js hadolint.yaml /etc/lint/
# J'ai copié lint.sh dans le PATH et --chmod le rend exécutable sans RUN en plus.
COPY --chmod=755 lint.sh /usr/local/bin/lint.sh

# J'ai mis USER node car le lint n'a pas besoin d'être root : il lit seulement les fichiers du projet.
USER node

# J'ai mis /src comme dossier de travail : c'est là que docker-compose.yml monte le projet (en lecture seule).
WORKDIR /src

# Je n'ai pas géré SIGTERM ici : le lint ne dure que quelques secondes, il s'arrête tout seul, et ne garde aucune donnée
# (le projet est monté en lecture seule). Si on l'interrompt, Docker le tue sans conséquence.

# J'ai mis le script en CMD (forme exec) pour que le lint démarre dès qu'on lance le conteneur.
# Son code de sortie vaut 0 si tout est bon et 1 s'il y a une erreur, comme ça il peut bloquer une CI.
CMD ["lint.sh"]
