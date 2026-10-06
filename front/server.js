const http = require("http");

http.createServer((req, res) => {
  res.end("Hello World depuis le front");
}).listen(3000);
