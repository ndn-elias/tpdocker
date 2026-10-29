#!/bin/sh
# J'ai fait ce script pour vérifier le projet du garage moto avant de le lancer :
# les Dockerfiles (hadolint), les scripts shell (shellcheck) et le code Node.js (eslint).
# Il tourne dans le conteneur "lint", qui voit le projet dans /src (monté en lecture seule).
# Je ne m'arrête pas à la première erreur : je lance les 3 outils pour tout voir d'un coup,
# puis je sors avec le code 1 si au moins un outil a trouvé un problème (0 sinon).

ERREURS=0

echo "===== hadolint : Dockerfiles"
# */Dockerfile = un Dockerfile par dossier (front, back, serveur-web, autoscaler, lint)
for FICHIER in */Dockerfile; do
  echo "-- ${FICHIER}"
  hadolint --config /etc/lint/hadolint.yaml "$FICHIER" || ERREURS=$((ERREURS + 1))
done

echo "===== shellcheck : scripts shell"
# -s sh : ce sont des scripts sh (alpine n'a pas bash), pas des scripts bash
shellcheck -s sh autoscaler/autoscale.sh lint/lint.sh || ERREURS=$((ERREURS + 1))

echo "===== eslint : code Node.js"
# --max-warnings 0 : un avertissement fait aussi échouer le lint
eslint -c /etc/lint/eslint.config.js --max-warnings 0 front/server.js back/server.js || ERREURS=$((ERREURS + 1))

echo "====="
if [ "$ERREURS" -ne 0 ]; then
  echo "Lint : ${ERREURS} outil(s) en erreur"
  exit 1
fi
echo "Lint : tout est bon"
