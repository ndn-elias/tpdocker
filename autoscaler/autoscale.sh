#!/bin/sh
# J'ai fait ce script pour que Docker Swarm ajoute tout seul des copies (replicas) du front et de l'API
# quand beaucoup de mécaniciens utilisent l'appli en même temps, et qu'il les enlève quand c'est calme,
# pour que le PC de l'atelier garde sa puissance pour le reste.
# Il tourne dans le conteneur "autoscaler" du stack, et parle à Docker grâce au socket /var/run/docker.sock.

# ---- CONFIG ----
# Toutes les valeurs viennent des variables d'environnement (passées par docker-stack.yml depuis le .env),
# ce qui est après ":-" est la valeur par défaut.
# J'ai mis le nom du stack car Swarm appelle les services "<stack>_<service>" (par exemple garage_front).
STACK_NAME="${STACK_NAME:-garage}"
# J'ai mis aussi Nginx car en testant l'autoscaler avec 100 mécaniciens en même temps, c'est lui qui était à fond le premier :
# toutes les requêtes passent par lui, donc multiplier seulement le front et l'API ne servait à rien.
SERVICES="${SERVICES:-front back serveur-web}"
MIN_REPLICAS="${MIN_REPLICAS:-1}"
MAX_REPLICAS="${MAX_REPLICAS:-4}"
# Les seuils sont en % de la limite CPU du service, pas du PC : avec une limite de 0.25 CPU,
# 80 % veut dire que le conteneur utilise 0.2 CPU, donc qu'il est presque à fond.
CPU_HAUT="${CPU_HAUT:-80}"
CPU_BAS="${CPU_BAS:-20}"
# J'ai mis 15 secondes entre deux mesures pour réagir vite à un pic sans surcharger Docker de commandes.
INTERVALLE="${INTERVALLE:-15}"
# J'ai mis un temps d'attente après chaque changement pour laisser à la nouvelle copie le temps de démarrer
# et de prendre sa part des requêtes, sinon le script ajouterait des copies en boucle.
COOLDOWN="${COOLDOWN:-60}"

echo "Autoscaler démarré pour le stack ${STACK_NAME} : services [${SERVICES}], ${MIN_REPLICAS} à ${MAX_REPLICAS} replicas, seuils ${CPU_BAS}% / ${CPU_HAUT}%"

# Docker envoie SIGTERM au conteneur à l'arrêt ("docker stack rm"). Ce script est le processus 1 du conteneur,
# et sans trap le script n'a rien de prévu à l'arrêt : il serait interrompu n'importe où (code de sortie différent de 0).
# Avec ce trap, le script affiche un message et quitte tout de suite.
trap 'echo "$(date "+%H:%M:%S") - SIGTERM reçu, arrêt de l autoscaler"; exit 0' TERM INT

while true; do
  MAINTENANT=$(date +%s)

  for SERVICE in $SERVICES; do
    NOM="${STACK_NAME}_${SERVICE}"

    # Je lis le nombre de replicas demandé et la limite CPU directement dans la config du service Swarm.
    REPLICAS=$(docker service inspect --format '{{.Spec.Mode.Replicated.Replicas}}' "$NOM" 2>/dev/null)
    LIMITE=$(docker service inspect --format '{{.Spec.TaskTemplate.Resources.Limits.NanoCPUs}}' "$NOM" 2>/dev/null)
    if [ -z "$REPLICAS" ]; then
      echo "$(date '+%H:%M:%S') - ${NOM} introuvable, je passe"
      continue
    fi

    # Je prends seulement les copies "healthy" : une copie qui démarre utilise tout son CPU pendant quelques secondes
    # (surtout le front avec npm), et sans ce filtre l'autoscaler ajoutait une copie dès le lancement du stack.
    # Swarm met le nom du service dans le label com.docker.swarm.service.name de chaque conteneur.
    PRETS=$(docker ps --filter "label=com.docker.swarm.service.name=${NOM}" --filter health=healthy --format '{{.Names}}')
    if [ -z "$PRETS" ]; then
      echo "$(date '+%H:%M:%S') - ${NOM} : aucune copie prête pour l'instant, j'attends"
      continue
    fi

    # Je fais la moyenne du CPU des copies prêtes, puis je la ramène à la limite CPU du service.
    # docker stats donne le CPU en % d'un cœur (0.25 CPU à fond = 25 %), donc je divise par la limite (0.25).
    # Attention : docker stats ne voit que les conteneurs de cette machine, c'est suffisant car le garage n'a qu'un PC (un seul nœud Swarm).
    # $PRETS n'a pas de guillemets exprès : il contient un nom de conteneur par ligne, et docker stats doit les recevoir
    # comme plusieurs arguments séparés (shellcheck le signale avec SC2086, je le désactive pour cette ligne).
    # shellcheck disable=SC2086
    CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" $PRETS | awk -v limite="${LIMITE:-0}" '
      { gsub(/%/, "", $1); total += $1; n++ }
      END {
        if (n == 0) { print 0; exit }
        coeurs = (limite > 0) ? limite / 1000000000 : 1
        print int(total / n / coeurs)
      }')

    echo "$(date '+%H:%M:%S') - ${NOM} : CPU moyen=${CPU}% de la limite | replicas=${REPLICAS} ($(echo "$PRETS" | wc -l) prêtes)"

    # Je regarde quand ce service a changé pour la dernière fois, pour respecter le temps d'attente.
    DERNIER=$(cat "/tmp/dernier_${SERVICE}" 2>/dev/null || echo 0)
    if [ $((MAINTENANT - DERNIER)) -lt "$COOLDOWN" ]; then
      continue
    fi

    # Si les copies sont presque à fond, j'en ajoute une (sans dépasser MAX_REPLICAS).
    if [ "$CPU" -gt "$CPU_HAUT" ] && [ "$REPLICAS" -lt "$MAX_REPLICAS" ]; then
      NOUVEAU=$((REPLICAS + 1))
      echo "$(date '+%H:%M:%S') - ${NOM} : charge forte, je passe à ${NOUVEAU} replicas"
      # J'ai mis --detach pour ne pas bloquer le script pendant que Swarm démarre la nouvelle copie.
      docker service scale --detach "${NOM}=${NOUVEAU}" >/dev/null
      echo "$MAINTENANT" > "/tmp/dernier_${SERVICE}"
    # Si c'est calme, j'en enlève une (sans descendre sous MIN_REPLICAS).
    elif [ "$CPU" -lt "$CPU_BAS" ] && [ "$REPLICAS" -gt "$MIN_REPLICAS" ]; then
      NOUVEAU=$((REPLICAS - 1))
      echo "$(date '+%H:%M:%S') - ${NOM} : c'est calme, je redescends à ${NOUVEAU} replicas"
      docker service scale --detach "${NOM}=${NOUVEAU}" >/dev/null
      echo "$MAINTENANT" > "/tmp/dernier_${SERVICE}"
    fi
  done

  # Je lance sleep en arrière-plan puis j'attends avec "wait" : un trap ne s'exécute pas tant qu'une commande
  # au premier plan tourne (le script resterait bloqué jusqu'à la fin du sleep), alors que "wait" est interrompu par le signal.
  sleep "$INTERVALLE" &
  wait $!
done
