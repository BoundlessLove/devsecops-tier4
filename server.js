const http = require('http');

const port = process.env.PORT || 8080;

const requestHandler = (req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Hello from aks-demo running on k3d!\n');
};

const server = http.createServer(requestHandler);

server.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
