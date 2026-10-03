const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.env.WEB_PORT || 8085;
const webDir = path.join(__dirname, '..', 'build', 'web');

// Automatically adapt base href for local root hosting
app.get(['/', '/index.html'], (req, res) => {
  const indexPath = path.join(webDir, 'index.html');
  if (fs.existsSync(indexPath)) {
    let html = fs.readFileSync(indexPath, 'utf8');
    html = html.replace('<base href="/Sanctuary/">', '<base href="/">');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(html);
  }
  res.status(404).send('No se encontró build/web. Ejecuta el despliegue o la descarga de la web compilada.');
});

// Serve assets with both /Sanctuary and / prefixes
app.use('/Sanctuary', express.static(webDir));
app.use('/', express.static(webDir));

// Fallback for Flutter deep linking
app.get('*', (req, res) => {
  const indexPath = path.join(webDir, 'index.html');
  if (fs.existsSync(indexPath)) {
    let html = fs.readFileSync(indexPath, 'utf8');
    html = html.replace('<base href="/Sanctuary/">', '<base href="/">');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(html);
  }
  res.status(404).send('Not found');
});

app.listen(port, '0.0.0.0', () => {
  console.log(`🌐 Sanctuary Flutter Web running locally at http://localhost:${port}`);
});
