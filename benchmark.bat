@echo off
rem Benchmark de l'appli du garage moto, il simule plusieurs mécaniciens qui chargent l'appli en même temps.
rem Pour le lancer (avec les conteneurs lancés, depuis cmd), il faut taper benchmark.bat [nombre_de_requetes] [mecaniciens_en_meme_temps] [projet]
rem Par exemple benchmark.bat 3000 10
rem Pour tester l'appli lancée avec Swarm (deploy-swarm.bat), il faut mettre garage en 3e : benchmark.bat 30000 50 garage

rem J'ai mis chcp 65001 pour que les accents s'affichent bien dans cmd.
chcp 65001 >nul
setlocal

rem J'ai mis 3000 requêtes et 10 mécaniciens en même temps par défaut, car c'est un garage avec une dizaine de mécaniciens.
set REQUETES=%1
if "%REQUETES%"=="" set REQUETES=3000
set MECANICIENS=%2
if "%MECANICIENS%"=="" set MECANICIENS=10
rem J'ai mis le nom du projet en paramètre car avec docker compose le réseau s'appelle projet1_garage-network,
rem et avec Swarm il s'appelle garage_garage-network (nom du stack).
set PROJET=%3
if "%PROJET%"=="" set PROJET=projet1

rem Je teste l'API (liste des réparations) puis la page du front.
call :test /api/reparations
call :test /app/
goto :eof

:test
echo.
echo ===== %1 : %REQUETES% requetes, %MECANICIENS% mecaniciens en meme temps

rem J'utilise "ab" (Apache Bench) depuis l'image httpd:alpine, dans un conteneur à part,
rem comme ça je n'installe rien sur mon PC ni dans mes images.
rem Je le branche sur le réseau garage-network pour tester l'appli comme dans le garage, en passant par Nginx.
rem Je le lance en arrière-plan (-d) pour pouvoir mesurer le CPU et la RAM pendant qu'il tourne.
docker rm -f garage-bench >nul 2>&1
docker run -d --name garage-bench --network %PROJET%_garage-network httpd:alpine ab -q -n %REQUETES% -c %MECANICIENS% http://serveur-web%1 >nul

rem Tant que le test tourne, je relève le CPU et la RAM de chaque conteneur de l'appli.
:mesure
docker stats --no-stream --format "{{.Name}}  CPU {{.CPUPerc}}  RAM {{.MemUsage}}" | findstr %PROJET%
docker ps -q -f name=garage-bench | findstr . >nul && goto mesure

rem J'affiche les lignes importantes du résultat, c'est-à-dire les erreurs, requêtes par seconde, temps des requêtes les plus lentes.
echo --- Resultat :
docker logs garage-bench 2>&1 | findstr /C:"Failed requests" /C:"Requests per second" /C:"99%%"

rem Je supprime le conteneur de test, il ne sert plus.
docker rm garage-bench >nul
goto :eof
