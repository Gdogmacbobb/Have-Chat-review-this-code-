import express from 'express';
import path from 'path';
import { registerRoutes } from './routes';

const app = express();
const PORT = 5000;

// Enable CORS for all routes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Parse JSON and text bodies
app.use(express.json({ limit: '10mb' }));
app.use(express.text({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Register API routes
registerRoutes(app).then((httpServer) => {
  // Serve static files from build/web
  const buildPath = path.join(process.cwd(), 'build', 'web');
  app.use(express.static(buildPath, {
    maxAge: '1h',
    setHeaders: (res, filepath) => {
      if (filepath.endsWith('.html')) {
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
      } else if (filepath.endsWith('.js') || filepath.endsWith('.css')) {
        res.setHeader('Cache-Control', 'public, max-age=3600');
      }
    }
  }));

  // Serve index.html for all routes (SPA)
  app.get('*', (req, res) => {
    res.sendFile(path.join(buildPath, 'index.html'));
  });

  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}).catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});