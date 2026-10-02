const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 8088;
const connectionString = process.env.DATABASE_URL || 'postgres://sanctuary_user:sanctuary_secret@localhost:5438/sanctuary_db';

const pool = new Pool({
  connectionString,
  connectionTimeoutMillis: 1000,
});

pool.on('error', (err) => {
  // Prevent unhandled pool errors from terminating the Node process when PostgreSQL is offline
});

process.on('uncaughtException', (err) => {
  console.warn('[Backend Warning uncaughtException]:', err.message);
});

process.on('unhandledRejection', (reason) => {
  console.warn('[Backend Warning unhandledRejection]:', reason);
});

let dbOfflineLogged = false;
async function safeQuery(sql, params = []) {
  try {
    return await pool.query(sql, params);
  } catch (err) {
    if (!dbOfflineLogged) {
      console.log(' [DB Status] PostgreSQL no responde o Docker no está activo. Activando almacenamiento local de respaldo.');
      dbOfflineLogged = true;
    }
    return null;
  }
}

const localDbPath = path.join(__dirname, 'data', 'local_db.json');

function getDefaultLocalDb() {
  return {
    users: [
      {
        id: 1,
        username: 'admin',
        password: 'admin',
        role: 'admin',
        full_name: 'Administrador Sanctuary',
        email: 'admin@sanctuary.local',
        avatar_url: '',
        bio: 'Administrador del sistema',
        created_at: new Date().toISOString(),
      }
    ],
    cv_profiles: [
      {
        id: 'profile-1',
        fullName: 'JOSÉ MARIO SUÁREZ MÉNDEZ',
        jobTitle: 'OPERARIO/A DE MANTENIMIENTO URBANO',
        avatarUrl: 'assets/avatars/avatar1.png',
        moduleBadge: 'MÓDULO FC0003 · Inserción y Orientación Laboral',
        workshopTitle: 'Taller de Curriculum Vitae · Gestión Docente',
        phone: '+34 600 000 000',
        email: 'jose.suarez.mendez88@correo.es',
        location: 'Arucas, Gran Canaria',
        availability: 'Disponibilidad horaria e incorporación inmediata',
        drivingLicense: 'Permiso B y vehículo propio',
        summary: 'Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para trabajar en equipo.\n\nManejo herramientas y métodos del oficio con destreza técnica, priorizando siempre la prevención de riesgos y el uso de EPIs.',
        skills: ['TRABAJO EN EQUIPO', 'PREVENCIÓN Y EPIS', 'PUNTUALIDAD Y SERIEDAD', 'MANEJO DE HERRAMIENTAS', 'CAPACIDAD DE APRENDIZAJE'],
        skillItems: [
          { name: 'TRABAJO EN EQUIPO', level: 2, description: 'Compañerismo y coordinación en cuadrilla' },
          { name: 'PREVENCIÓN Y EPIS', level: 5, description: 'Seguridad y prevención de riesgos en obra' },
          { name: 'PUNTUALIDAD Y SERIEDAD', level: 5, description: 'Compromiso riguroso con horarios y tareas' },
          { name: 'MANEJO DE HERRAMIENTAS', level: 4, description: 'Destreza con útiles manuales y eléctricos' },
          { name: 'CAPACIDAD DE APRENDIZAJE', level: 5, description: 'Asimilación rápida de nuevas técnicas' }
        ],
        experiences: [
          {
            jobTitle: 'APRENDIZ TRABAJADOR/A - OPERARIO/A DE MANTENIMIENTO URBANO',
            company: 'Ayuntamiento de Arucas (Programa de Empleo y Formación Trayectoria)',
            period: '2024 - 2025',
            description: 'Tareas prácticas en obras y servicios públicos municipales, conservación y manejo de herramientas y maquinaria ligera, y aplicación estricta de medidas de seguridad y EPIs.'
          }
        ],
        educations: [
          {
            degree: 'CERTIFICADO DE PROFESIONALIDAD (EN CURSO)',
            institution: 'Servicio Canario de Empleo / Ayuntamiento de Arucas',
            period: '2024 - 2025',
            details: 'Formación teórico-práctica acreditada con módulos de Competencias Clave y PRL.'
          },
          {
            degree: 'COMPETENCIAS CLAVE Y HABILIDADES LABORALES',
            institution: 'Programa de Empleo y Formación Trayectoria Arucas',
            period: '2024 - 2025',
            details: 'Módulos transversales de Matemáticas, Lengua Castellana, Competencias Digitales y Orientación Laboral.'
          }
        ],
        template: 'sidebar_dark',
        accentColor: '#10B981',
        fontFamily: 'Inter',
        updatedAt: new Date().toISOString()
      }
    ],
    repo_links: [
      { id: 1, title: 'Sanctuary Repository', url: 'https://github.com/carlosss91/Sanctuary', description: 'Repositorio principal del santuario con CV Builder y Docker', category: 'Repositorios', icon_name: 'folder_git' },
      { id: 2, title: 'Portal Docente & Orientación', url: 'https://github.com/carlosss91', description: 'Herramienta de gestión de alumnos y orientación laboral', category: 'Educación', icon_name: 'school' },
      { id: 3, title: 'Slide Downloader', url: 'app://prezi2pdf', description: 'Descargador universal de presentaciones y videos', category: 'Web Apps', icon_name: 'present_to_all' },
      { id: 4, title: 'Web Apps & Proyectos', url: 'https://github.com/carlosss91', description: 'Directorio de aplicaciones interactivas y utilidades', category: 'Web Apps', icon_name: 'apps' }
    ]
  };
}

function getLocalDb() {
  try {
    if (fs.existsSync(localDbPath)) {
      const parsed = JSON.parse(fs.readFileSync(localDbPath, 'utf8'));
      if (parsed && Array.isArray(parsed.users)) {
        if (!parsed.users.some(u => u.username.toLowerCase() === 'admin')) {
          parsed.users.push(getDefaultLocalDb().users[0]);
          saveLocalDb(parsed);
        }
        return parsed;
      }
    }
  } catch (e) {
    console.error('Error reading local db:', e.message);
  }
  const def = getDefaultLocalDb();
  saveLocalDb(def);
  return def;
}

function saveLocalDb(data) {
  try {
    const dir = path.dirname(localDbPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(localDbPath, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    console.error('Error saving local db:', e.message);
  }
}

app.use(cors());
app.use(express.json({ limit: '15mb' }));

// Static directory for uploaded images
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
app.use('/uploads', express.static(uploadsDir));

// Image Upload Endpoint (accepts Base64 image payload from PC)
app.post('/api/upload', (req, res) => {
  try {
    const { image, filename } = req.body;
    if (!image) {
      return res.status(400).json({ success: false, message: 'No se envió ninguna imagen' });
    }

    let base64Data = image;
    let ext = 'png';
    const matches = image.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
    if (matches && matches.length === 3) {
      const mime = matches[1];
      if (mime.includes('jpeg') || mime.includes('jpg')) ext = 'jpg';
      else if (mime.includes('webp')) ext = 'webp';
      else if (mime.includes('gif')) ext = 'gif';
      base64Data = matches[2];
    }

    const safeName = `img_${Date.now()}_${Math.floor(Math.random() * 1000)}.${ext}`;
    const filePath = path.join(uploadsDir, safeName);
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(filePath, buffer);

    const host = req.get('host') || `localhost:${port}`;
    const protocol = req.protocol || 'http';
    const publicUrl = `${protocol}://${host}/uploads/${safeName}`;

    res.json({
      success: true,
      message: 'Imagen subida correctamente',
      filename: safeName,
      url: publicUrl,
    });
  } catch (err) {
    console.error('Error uploading image:', err);
    res.status(500).json({ success: false, message: 'Error al guardar imagen: ' + err.message });
  }
});

// Healthcheck endpoint
app.get('/api/health', async (req, res) => {
  const result = await safeQuery('SELECT NOW() as time');
  if (result && result.rows.length > 0) {
    return res.json({
      status: 'ok',
      service: 'Sanctuary API',
      database: 'connected (PostgreSQL)',
      timestamp: result.rows[0].time,
    });
  }
  res.json({
    status: 'ok',
    service: 'Sanctuary API',
    database: 'local_fallback (offline mode)',
    timestamp: new Date().toISOString(),
  });
});

// Run schema migrations for users profile columns if PostgreSQL is online
safeQuery(`
  ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS full_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS email VARCHAR(150),
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT;
`).catch(() => {});

// Authentication: Login
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  const uClean = username.trim();
  const pClean = password.trim();

  // Try PostgreSQL
  const result = await safeQuery(
    'SELECT id, username, role, full_name, email, avatar_url, bio, created_at FROM users WHERE username = $1 AND password = $2',
    [uClean, pClean]
  );

  if (result) {
    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
    }
    return res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      user: result.rows[0],
    });
  }

  // Fallback to local DB when PostgreSQL is not running
  const ldb = getLocalDb();
  let user = ldb.users.find(u => u.username.toLowerCase() === uClean.toLowerCase() && u.password === pClean);
  if (!user && uClean.toLowerCase() === 'admin' && pClean === 'admin') {
    user = getDefaultLocalDb().users[0];
    ldb.users.push(user);
    saveLocalDb(ldb);
  }

  if (user) {
    const { password: _, ...userNoPwd } = user;
    return res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      user: userNoPwd,
    });
  }

  return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
});

// Authentication: Register new user
app.post('/api/auth/register', async (req, res) => {
  const { username, password, role, full_name, email, avatar_url, bio } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  const uClean = username.trim();
  const pClean = password.trim();

  const existingRes = await safeQuery('SELECT id FROM users WHERE username = $1', [uClean]);
  if (existingRes) {
    if (existingRes.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'El nombre de usuario ya existe' });
    }
    const result = await safeQuery(
      `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) 
       RETURNING id, username, role, full_name, email, avatar_url, bio, created_at`,
      [uClean, pClean, role || 'usuario', full_name || uClean, email || '', avatar_url || '', bio || '']
    );
    if (result && result.rows.length > 0) {
      return res.status(201).json({
        success: true,
        message: 'Usuario registrado correctamente',
        user: result.rows[0],
      });
    }
  }

  // Local DB fallback
  const ldb = getLocalDb();
  if (ldb.users.some(u => u.username.toLowerCase() === uClean.toLowerCase())) {
    return res.status(409).json({ success: false, message: 'El nombre de usuario ya existe' });
  }

  const newUser = {
    id: Date.now(),
    username: uClean,
    password: pClean,
    role: role || 'usuario',
    full_name: full_name || uClean,
    email: email || '',
    avatar_url: avatar_url || '',
    bio: bio || '',
    created_at: new Date().toISOString(),
  };
  ldb.users.push(newUser);
  saveLocalDb(ldb);

  const { password: _, ...userNoPwd } = newUser;
  res.status(201).json({
    success: true,
    message: 'Usuario registrado correctamente',
    user: userNoPwd,
  });
});

// User Profile: Update Profile
app.put('/api/users/profile', async (req, res) => {
  const { id, username, full_name, email, avatar_url, bio, password } = req.body;
  let query, params;
  if (password && password.trim().length > 0) {
    query = `UPDATE users 
             SET full_name = $1, email = $2, avatar_url = $3, bio = $4, password = $5
             WHERE id = $6 OR username = $7
             RETURNING id, username, role, full_name, email, avatar_url, bio, created_at`;
    params = [full_name || '', email || '', avatar_url || '', bio || '', password.trim(), id || -1, username || ''];
  } else {
    query = `UPDATE users 
             SET full_name = $1, email = $2, avatar_url = $3, bio = $4
             WHERE id = $5 OR username = $6
             RETURNING id, username, role, full_name, email, avatar_url, bio, created_at`;
    params = [full_name || '', email || '', avatar_url || '', bio || '', id || -1, username || ''];
  }
  const result = await safeQuery(query, params);
  if (result) {
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    return res.json({
      success: true,
      message: 'Perfil actualizado correctamente',
      user: result.rows[0],
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const idx = ldb.users.findIndex(u => (id && u.id == id) || (username && u.username.toLowerCase() === (username || '').toLowerCase()));
  if (idx >= 0) {
    if (full_name !== undefined) ldb.users[idx].full_name = full_name;
    if (email !== undefined) ldb.users[idx].email = email;
    if (avatar_url !== undefined) ldb.users[idx].avatar_url = avatar_url;
    if (bio !== undefined) ldb.users[idx].bio = bio;
    if (password && password.trim()) ldb.users[idx].password = password.trim();
    saveLocalDb(ldb);
    const { password: _, ...userNoPwd } = ldb.users[idx];
    return res.json({ success: true, message: 'Perfil actualizado correctamente', user: userNoPwd });
  }
  res.status(404).json({ success: false, message: 'Usuario no encontrado' });
});

// CV Profiles: List
app.get('/api/cv/profiles', async (req, res) => {
  const result = await safeQuery('SELECT id, full_name, job_title, avatar_url, data_json, updated_at FROM cv_profiles ORDER BY updated_at DESC');
  if (result) {
    const profiles = result.rows.map(row => {
      let data = row.data_json;
      if (typeof data === 'string') {
        try { data = JSON.parse(data); } catch(e) {}
      }
      return {
        id: row.id,
        fullName: row.full_name,
        jobTitle: row.job_title,
        avatarUrl: row.avatar_url,
        updatedAt: row.updated_at,
        ...data,
      };
    });
    return res.json({ success: true, count: profiles.length, profiles });
  }

  const ldb = getLocalDb();
  res.json({ success: true, count: (ldb.cv_profiles || []).length, profiles: ldb.cv_profiles || [] });
});

// CV Profiles: Save or Update (Upsert)
app.post('/api/cv/profiles', async (req, res) => {
  const profile = req.body;
  if (!profile || !profile.id) {
    return res.status(400).json({ success: false, message: 'Datos de perfil o ID faltantes' });
  }

  const id = profile.id;
  const fullName = profile.fullName || 'Nuevo Perfil';
  const jobTitle = profile.jobTitle || '';
  const avatarUrl = profile.photoUrl || profile.avatarUrl || '';
  const dataJson = JSON.stringify(profile);

  await safeQuery(
    `INSERT INTO cv_profiles (id, full_name, job_title, avatar_url, data_json, updated_at)
     VALUES ($1, $2, $3, $4, $5, NOW())
     ON CONFLICT (id) DO UPDATE SET
       full_name = EXCLUDED.full_name,
       job_title = EXCLUDED.job_title,
       avatar_url = EXCLUDED.avatar_url,
       data_json = EXCLUDED.data_json,
       updated_at = NOW()`,
    [id, fullName, jobTitle, avatarUrl, dataJson]
  );

  const ldb = getLocalDb();
  if (!ldb.cv_profiles) ldb.cv_profiles = [];
  const idx = ldb.cv_profiles.findIndex(p => p.id === id);
  if (idx >= 0) {
    ldb.cv_profiles[idx] = profile;
  } else {
    ldb.cv_profiles.unshift(profile);
  }
  saveLocalDb(ldb);

  res.json({ success: true, message: 'Perfil guardado con éxito', id });
});

// CV Profiles: Delete
app.delete('/api/cv/profiles/:id', async (req, res) => {
  const { id } = req.params;
  await safeQuery('DELETE FROM cv_profiles WHERE id = $1', [id]);
  const ldb = getLocalDb();
  if (ldb.cv_profiles) {
    ldb.cv_profiles = ldb.cv_profiles.filter(p => p.id !== id);
    saveLocalDb(ldb);
  }
  res.json({ success: true, message: 'Perfil eliminado con éxito' });
});

// Repository Links: List
app.get('/api/links', async (req, res) => {
  const result = await safeQuery('SELECT * FROM repo_links ORDER BY id ASC');
  if (result) {
    return res.json({ success: true, links: result.rows });
  }
  const ldb = getLocalDb();
  res.json({ success: true, links: ldb.repo_links || [] });
});

// Repository Links: Add
app.post('/api/links', async (req, res) => {
  const { title, url, description, category, icon_name } = req.body;
  if (!title || !url) {
    return res.status(400).json({ success: false, message: 'Título y URL requeridos' });
  }

  const result = await safeQuery(
    `INSERT INTO repo_links (title, url, description, category, icon_name)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [title, url, description || '', category || 'General', icon_name || 'link']
  );
  if (result && result.rows.length > 0) {
    return res.status(201).json({ success: true, link: result.rows[0] });
  }

  const ldb = getLocalDb();
  if (!ldb.repo_links) ldb.repo_links = [];
  const newLink = {
    id: Date.now(),
    title,
    url,
    description: description || '',
    category: category || 'General',
    icon_name: icon_name || 'link',
  };
  ldb.repo_links.push(newLink);
  saveLocalDb(ldb);
  res.status(201).json({ success: true, link: newLink });
});

// Repository Links: Delete
app.delete('/api/links/:id', async (req, res) => {
  const { id } = req.params;
  await safeQuery('DELETE FROM repo_links WHERE id = $1', [id]);
  const ldb = getLocalDb();
  if (ldb.repo_links) {
    ldb.repo_links = ldb.repo_links.filter(l => l.id != id);
    saveLocalDb(ldb);
  }
  res.json({ success: true, message: 'Enlace eliminado' });
});

// Prezi2PDF Proxy Endpoints
app.get('/api/prezi/resolve', async (req, res) => {
  const { url } = req.query;
  if (!url) {
    return res.status(400).json({ success: false, message: 'URL requerida' });
  }

  try {
    const fetchRes = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    if (!fetchRes.ok) {
      return res.status(fetchRes.status).json({ success: false, message: 'Error al consultar Prezi' });
    }

    const html = await fetchRes.text();
    const oidMatches = html.match(/prezi_oid["\'\\]*:\s*["\'\\]*([a-zA-Z0-9_-]+)/);
    const fallbackOidMatches = html.match(/oid["\'\\]*:\s*["\'\\]*([a-zA-Z0-9_-]+)/);
    const oid = oidMatches ? oidMatches[1] : (fallbackOidMatches ? fallbackOidMatches[1] : null);

    const linkMatches = html.match(/link_id["\'\\]*:\s*["\'\\]*([a-zA-Z0-9_-]+)/);
    let prezilink = linkMatches ? linkMatches[1] : null;
    if (!prezilink) {
      const tokenMatch = url.match(/\/view\/([a-zA-Z0-9_-]+)/);
      if (tokenMatch) prezilink = tokenMatch[1];
    }

    const titleMatch = html.match(/<title>(.*?)<\/title>/i);
    let title = null;
    if (titleMatch) {
      title = titleMatch[1].replace(' | Prezi', '').replace(/&amp;/g, '&').trim();
    }

    res.json({
      success: true,
      oid: oid || url,
      prezilink,
      title: title || oid,
    });
  } catch (err) {
    console.error('Error in /api/prezi/resolve:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/api/prezi/storyboard', async (req, res) => {
  const { id, prezilink } = req.query;
  if (!id) {
    return res.status(400).json({ success: false, message: 'ID requerido' });
  }

  let apiUrl = `https://prezi.com/api/v2/storyboard/${id}/`;
  if (prezilink) {
    apiUrl += `?prezilink=${prezilink}`;
  }

  try {
    const fetchRes = await fetch(apiUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
      },
    });

    const data = await fetchRes.json();
    res.status(fetchRes.status).json(data);
  } catch (err) {
    console.error('Error in /api/prezi/storyboard:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/api/prezi/video-content', async (req, res) => {
  const { id } = req.query;
  if (!id) {
    return res.status(400).json({ success: false, message: 'ID requerido' });
  }

  try {
    const fetchRes = await fetch(`https://prezi.com/api/v5/presentation-content/${id}/`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    const data = await fetchRes.json();
    res.status(fetchRes.status).json(data);
  } catch (err) {
    console.error('Error in /api/prezi/video-content:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Generic Slide Downloader Proxy (bypasses CORS for any presentation provider in Web)
app.get('/api/slides/proxy', async (req, res) => {
  const { url } = req.query;
  if (!url) {
    return res.status(400).json({ success: false, message: 'URL requerida' });
  }

  try {
    const fetchRes = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    const contentType = fetchRes.headers.get('content-type') || 'text/html';
    res.setHeader('Content-Type', contentType);

    if (contentType.includes('json')) {
      const data = await fetchRes.json();
      res.status(fetchRes.status).json(data);
    } else if (contentType.includes('text') || contentType.includes('html')) {
      const text = await fetchRes.text();
      res.status(fetchRes.status).send(text);
    } else {
      const buffer = await fetchRes.arrayBuffer();
      res.status(fetchRes.status).send(Buffer.from(buffer));
    }
  } catch (err) {
    console.error('Error in /api/slides/proxy:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Dedicated direct download endpoint with attachment header (forces save dialog)
app.get('/api/slides/download', async (req, res) => {
  const { url, filename } = req.query;
  if (!url) {
    return res.status(400).json({ success: false, message: 'URL requerida' });
  }

  try {
    const fetchRes = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    if (!fetchRes.ok) {
      return res.status(fetchRes.status).json({ success: false, message: 'Error al descargar archivo' });
    }

    const safeName = (filename || 'video.mp4').replace(/[^\w\.-]/gi, '_');
    res.setHeader('Content-Disposition', `attachment; filename="${safeName}"`);
    const contentType = fetchRes.headers.get('content-type') || 'application/octet-stream';
    res.setHeader('Content-Type', contentType);

    const buffer = await fetchRes.arrayBuffer();
    res.send(Buffer.from(buffer));
  } catch (err) {
    console.error('Error in /api/slides/download:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.listen(port, () => {
  console.log(`✨ Sanctuary API running on port ${port}`);
});
