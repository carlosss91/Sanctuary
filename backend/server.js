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
});

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
  try {
    const result = await pool.query('SELECT NOW() as time');
    res.json({
      status: 'ok',
      service: 'Sanctuary API',
      database: 'connected',
      timestamp: result.rows[0].time,
    });
  } catch (err) {
    res.status(500).json({
      status: 'error',
      database: 'disconnected',
      message: err.message,
    });
  }
});

// Run schema migrations for users profile columns
pool.query(`
  ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS full_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS email VARCHAR(150),
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT;
`).catch(err => console.log('Migration note:', err.message));

// Authentication: Login
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  try {
    const result = await pool.query(
      'SELECT id, username, role, full_name, email, avatar_url, bio, created_at FROM users WHERE username = $1 AND password = $2',
      [username.trim(), password.trim()]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
    }

    const user = result.rows[0];
    res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      user,
    });
  } catch (err) {
    console.error('Error in login:', err);
    res.status(500).json({ success: false, message: 'Error interno del servidor' });
  }
});

// Authentication: Register new user
app.post('/api/auth/register', async (req, res) => {
  const { username, password, role, full_name, email, avatar_url, bio } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  try {
    const existing = await pool.query('SELECT id FROM users WHERE username = $1', [username.trim()]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'El nombre de usuario ya existe' });
    }

    const result = await pool.query(
      `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) 
       RETURNING id, username, role, full_name, email, avatar_url, bio, created_at`,
      [
        username.trim(), 
        password.trim(), 
        role || 'usuario',
        full_name || username.trim(),
        email || '',
        avatar_url || '',
        bio || ''
      ]
    );

    res.status(201).json({
      success: true,
      message: 'Usuario registrado correctamente',
      user: result.rows[0],
    });
  } catch (err) {
    console.error('Error in register:', err);
    res.status(500).json({ success: false, message: 'Error al registrar el usuario' });
  }
});

// User Profile: Update Profile
app.put('/api/users/profile', async (req, res) => {
  const { id, username, full_name, email, avatar_url, bio, password } = req.body;
  try {
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
    const result = await pool.query(query, params);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    res.json({
      success: true,
      message: 'Perfil actualizado correctamente',
      user: result.rows[0],
    });
  } catch (err) {
    console.error('Error updating user profile:', err);
    res.status(500).json({ success: false, message: 'Error al actualizar perfil: ' + err.message });
  }
});

// CV Profiles: List
app.get('/api/cv/profiles', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, full_name, job_title, avatar_url, data_json, updated_at FROM cv_profiles ORDER BY updated_at DESC');
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
    res.json({ success: true, count: profiles.length, profiles });
  } catch (err) {
    console.error('Error fetching CV profiles:', err);
    res.status(500).json({ success: false, message: 'Error al obtener perfiles' });
  }
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

  try {
    await pool.query(
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

    res.json({ success: true, message: 'Perfil guardado con éxito', id });
  } catch (err) {
    console.error('Error saving CV profile:', err);
    res.status(500).json({ success: false, message: 'Error al guardar el perfil' });
  }
});

// CV Profiles: Delete
app.delete('/api/cv/profiles/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM cv_profiles WHERE id = $1', [id]);
    res.json({ success: true, message: 'Perfil eliminado con éxito' });
  } catch (err) {
    console.error('Error deleting CV profile:', err);
    res.status(500).json({ success: false, message: 'Error al eliminar el perfil' });
  }
});

// Repository Links: List
app.get('/api/links', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM repo_links ORDER BY id ASC');
    res.json({ success: true, links: result.rows });
  } catch (err) {
    console.error('Error fetching repo links:', err);
    res.status(500).json({ success: false, message: 'Error al obtener enlaces' });
  }
});

// Repository Links: Add
app.post('/api/links', async (req, res) => {
  const { title, url, description, category, icon_name } = req.body;
  if (!title || !url) {
    return res.status(400).json({ success: false, message: 'Título y URL requeridos' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO repo_links (title, url, description, category, icon_name)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [title, url, description || '', category || 'General', icon_name || 'link']
    );
    res.status(201).json({ success: true, link: result.rows[0] });
  } catch (err) {
    console.error('Error adding repo link:', err);
    res.status(500).json({ success: false, message: 'Error al crear enlace' });
  }
});

// Repository Links: Delete
app.delete('/api/links/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM repo_links WHERE id = $1', [id]);
    res.json({ success: true, message: 'Enlace eliminado' });
  } catch (err) {
    console.error('Error deleting repo link:', err);
    res.status(500).json({ success: false, message: 'Error al eliminar enlace' });
  }
});

app.listen(port, () => {
  console.log(`✨ Sanctuary API running on port ${port}`);
});
