const http = require("http");

http.createServer((req, res) => {
  res.end("Hello World depuis le back");
}).listen(3000);
