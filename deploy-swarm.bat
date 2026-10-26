@echo off
rem Lancement de l'appli du garage moto avec Docker Swarm et l'autoscaler.
rem Pour le lancer, depuis cmd dans le dossier du projet, il faut taper deploy-swarm.bat
rem Pour tout arrêter : docker stack rm garage

rem J'ai mis chcp 65001 pour que les accents s'affichent bien dans cmd.
chcp 65001 >nul
setlocal

rem J'ai mis le nom du stack ici car Swarm l'utilise devant le nom de chaque service (garage_front, garage_back...).
set STACK_NAME=garage

rem "docker stack deploy" ne lit pas le .env tout seul, alors je charge ses variables moi-même.
rem eol=# saute les lignes de commentaire, et delims== coupe chaque ligne en NOM et VALEUR.
if exist .env (
  for /f "usebackq eol=# tokens=1,* delims==" %%a in (".env") do set "%%a=%%b"
)
if not defined NGINX_PORT set NGINX_PORT=8080

rem Swarm doit être activé sur le PC de l'atelier, sinon je l'active (il devient le seul nœud, et c'est un manager).
docker info --format "{{.Swarm.LocalNodeState}}" | findstr /x active >nul
if errorlevel 1 (
  echo ===== Activation de Docker Swarm
  docker swarm init || exit /b 1
)

rem Swarm ne construit pas les images, donc je les construis avant avec docker compose (il lit les "build" du fichier).
echo ===== Construction des images
docker compose -f docker-stack.yml build || exit /b 1

rem Je lance (ou mets à jour) le stack. Si le stack existe déjà, Swarm fait une mise à jour progressive.
echo ===== Déploiement du stack %STACK_NAME%
docker stack deploy -c docker-stack.yml %STACK_NAME% || exit /b 1

echo.
echo L'appli démarre sur http://localhost:%NGINX_PORT%
echo Pour voir les copies      : docker service ls
echo Pour suivre l'autoscaler  : docker service logs -f %STACK_NAME%_autoscaler
