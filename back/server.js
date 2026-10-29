// API de la To-Do List du garage moto (version "Hello World")
// Elle renvoie la liste des réparations à faire, stockée dans un fichier JSON
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

// Le port et le chemin du fichier viennent des variables d'environnement (définies dans le Dockerfile)
const PORT = process.env.PORT || 3000;
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, "data", "reparations.json");
// Le mode vient de NODE_ENV : en "production" l'API est silencieuse, sinon (par exemple "development")
// elle affiche chaque requête dans les logs, pour corriger un bug sans reconstruire l'image
const MODE = process.env.NODE_ENV || "production";

// Si le fichier n'existe pas encore (premier lancement), on le crée avec des réparations d'exemple
// Dans Docker, il est créé dans le volume projet1_garage-data (pas dans le dossier du projet)
if (!fs.existsSync(DATA_FILE)) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify([
    { id: 1, moto: "Yamaha MT-07", immatriculation: "AB-123-CD", travail: "Vidange + plaquettes de frein", fait: false },
    { id: 2, moto: "Honda XL 750 Transalp", immatriculation: "EF-456-GH", travail: "Révision des 24 000 km : jeu aux soupapes, vidange, bougies, filtre à air, filtre à huile, consommables", fait: true }
  ], null, 2));
}

const server = http.createServer((req, res) => {
  if (MODE !== "production") console.log(`${req.method} ${req.url}`);
  // Pour GET /api/reparations, on lit le fichier JSON et on renvoie les réparations
  if (req.url === "/api/reparations") {
    res.setHeader("Content-Type", "application/json");
    // Avec Swarm, il peut y avoir plusieurs copies de l'API : on renvoie le nom de la copie qui a répondu
    res.setHeader("X-Replique", os.hostname());
    res.end(fs.readFileSync(DATA_FILE));
    return;
  }

  res.end("Hello World depuis le back (API du garage moto)");
});

server.listen(PORT, () => console.log(`API démarrée sur le port ${PORT} (mode ${MODE}), réparations dans ${DATA_FILE}`));

// Docker envoie SIGTERM au conteneur quand on fait "docker compose stop" ou "docker stack rm" (ou qu'une copie est enlevée).
// Node est le processus 1 du conteneur : sans ce code, il n'a rien de prévu à l'arrêt et Docker doit le tuer (SIGKILL).
// Ici on arrête d'accepter de nouvelles connexions, on laisse finir les requêtes en cours, puis on quitte proprement.
function arret(signal) {
  console.log(`${signal} reçu, arrêt de l'API`);
  server.close(() => process.exit(0));
  // Les connexions gardées ouvertes mais sans requête en cours ne doivent pas bloquer l'arrêt
  server.closeIdleConnections();
}
process.on("SIGTERM", () => arret("SIGTERM"));
process.on("SIGINT", () => arret("SIGINT"));
