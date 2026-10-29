# J'ai choisi alpine car l'autoscaler n'a besoin que du client Docker et d'un shell, ça garde l'image légère pour le petit PC de l'atelier.
# J'ai fixé la version 3.21 car son client Docker est assez récent pour parler au Docker du PC (Docker 29).
FROM alpine:3.21

# J'ai installé seulement docker-cli car le script utilise "docker stats" et "docker service scale",
# sh et awk sont déjà dans alpine donc je n'installe rien d'autre.
RUN apk add --no-cache docker-cli

# J'ai copié seulement autoscale.sh car c'est le seul fichier dont l'autoscaler a besoin.
# J'ai mis --chmod pour que le script soit exécutable sans faire un RUN en plus.
COPY --chmod=755 autoscale.sh /autoscale.sh

# Je n'ai pas mis USER car le script doit parler au socket Docker, qui n'est accessible qu'en root.
# C'est pour ça que dans docker-stack.yml l'autoscaler tourne seulement sur le nœud manager.

# J'ai mis STOPSIGNAL SIGTERM (la valeur par défaut) : autoscale.sh l'attrape avec un "trap" et quitte tout de suite.
STOPSIGNAL SIGTERM

# J'ai mis le script en CMD (forme exec) pour que l'autoscaler commence à surveiller l'appli dès le lancement du conteneur,
# et que le script soit le processus 1 du conteneur : il reçoit SIGTERM directement, sans shell entre les deux.
CMD ["/autoscale.sh"]
