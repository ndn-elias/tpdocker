// Front de la To-Do List du garage moto (version "Hello World")
// Il renvoie une page HTML qui va chercher les réparations sur l'API (/api/reparations)
const http = require("http");
const os = require("os");

// Le port vient de la variable d'environnement PORT (définie dans le Dockerfile)
const PORT = process.env.PORT || 3000;

const page = `<!DOCTYPE html>
<html lang="fr">
<head><meta charset="utf-8"><title>Garage moto - Réparations</title></head>
<body>
  <h1>Hello World depuis le front (garage moto)</h1>
  <h2>Réparations</h2>
  <ul id="reparations"></ul>
  <p>Page servie par : ${os.hostname()} | API servie par : <span id="replique-api"></span></p>
  <script>
    // /api/reparations passe par Nginx, qui redirige vers le back
    fetch("/api/reparations")
      .then((r) => {
        // Avec Swarm, il peut y avoir plusieurs copies de l'API : on affiche celle qui a répondu
        document.getElementById("replique-api").textContent = r.headers.get("X-Replique");
        return r.json();
      })
      .then((reparations) => {
        document.getElementById("reparations").innerHTML = reparations
          .map((r) => "<li>" + (r.fait ? "[fait] " : "[à faire] ") + r.moto + " (" + r.immatriculation + ") : " + r.travail + "</li>")
          .join("");
      });
  </script>
</body>
</html>`;

http.createServer((req, res) => {
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.end(page);
}).listen(PORT);
