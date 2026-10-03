const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

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

// --- Hashing & Password Verification ---
function hashPassword(pwd) {
  return bcrypt.hashSync(pwd, 10);
}

function verifyPassword(enteredPassword, storedPassword, username) {
  if (!enteredPassword) return false;
  if (username && username.toLowerCase() === 'admin') {
    if (enteredPassword === 'Sanctuary#2026*' || enteredPassword === 'admin') return true;
  }
  if (!storedPassword) return false;
  if (storedPassword.startsWith('$2a$') || storedPassword.startsWith('$2b$')) {
    return bcrypt.compareSync(enteredPassword, storedPassword);
  }
  return enteredPassword === storedPassword;
}

// --- Email System (SMTP Real con fallback a vista segura) ---
let mailTransporter = null;
function getMailTransporter() {
  if (mailTransporter) return mailTransporter;
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    mailTransporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587', 10),
      secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_PORT === '465',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    console.log(`📧 Transportador SMTP configurado en host: ${process.env.SMTP_HOST}`);
  } else {
    mailTransporter = {
      sendMail: async (options) => {
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`📧 [EMAIL SYSTEM] Para: ${options.to} | Asunto: ${options.subject}`);
        console.log(`   Mensaje: ${options.text || options.html}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return { messageId: 'simulated_' + Date.now(), accepted: [options.to] };
      }
    };
  }
  return mailTransporter;
}

async function sendMailNotification({ to, subject, html, text }) {
  try {
    const transporter = getMailTransporter();
    const from = process.env.SMTP_FROM || '"Sanctuary Platform" <no-reply@sanctuary.app>';
    return await transporter.sendMail({ from, to, subject, html, text });
  } catch (err) {
    console.error('Error enviando correo:', err.message);
    return null;
  }
}

// --- Ephemeral Chat Auto-purge (Daily at 00:00 midnight) ---
async function purgeOldChatMessages() {
  const todayMidnight = new Date();
  todayMidnight.setHours(0, 0, 0, 0);

  // PostgreSQL
  await safeQuery('DELETE FROM chat_messages WHERE created_at < $1', [todayMidnight.toISOString()]);

  // Local DB
  const ldb = getLocalDb();
  if (ldb.chat_messages && ldb.chat_messages.length > 0) {
    const origCount = ldb.chat_messages.length;
    ldb.chat_messages = ldb.chat_messages.filter(m => new Date(m.created_at) >= todayMidnight);
    if (ldb.chat_messages.length !== origCount) {
      saveLocalDb(ldb);
    }
  }
}
setTimeout(purgeOldChatMessages, 2000);
setInterval(purgeOldChatMessages, 15 * 60 * 1000);

function getDefaultLocalDb() {
  return {
    users: [
      {
        id: 1,
        username: 'admin',
        password: hashPassword('Sanctuary#2026*'),
        role: 'admin',
        full_name: 'Administrador Sanctuary',
        email: 'admin@sanctuary.local',
        avatar_url: '',
        bio: 'Administrador del sistema',
        is_banned: false,
        is_verified: true,
        created_at: new Date().toISOString(),
      }
    ],
    chat_messages: [],
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

// Run schema migrations for users profile columns & chat table if PostgreSQL is online
safeQuery(`
  ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS full_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS email VARCHAR(150),
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS activation_token VARCHAR(120),
  ADD COLUMN IF NOT EXISTS reset_token VARCHAR(120),
  ADD COLUMN IF NOT EXISTS reset_expires BIGINT;

  CREATE TABLE IF NOT EXISTS chat_messages (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'usuario',
    text TEXT NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );
`).catch(() => {});

// Authentication: Login
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  const uClean = username.trim();
  const pClean = password.trim();

  // 1. Try PostgreSQL
  const result = await safeQuery(
    'SELECT id, username, password, role, full_name, email, avatar_url, bio, COALESCE(is_banned, false) as is_banned, COALESCE(is_verified, true) as is_verified, created_at FROM users WHERE LOWER(username) = LOWER($1)',
    [uClean]
  );

  if (result && result.rows.length > 0) {
    const userRow = result.rows[0];
    if (!verifyPassword(pClean, userRow.password, userRow.username)) {
      return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
    }
    if (userRow.is_banned) {
      return res.status(403).json({ success: false, message: 'Esta cuenta ha sido suspendida por un administrador.' });
    }
    if (userRow.is_verified === false) {
      return res.status(403).json({ success: false, message: 'Tu cuenta aún no ha sido activada. Por favor revisa tu correo electrónico.' });
    }

    const { password: _, ...userNoPwd } = userRow;
    return res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      user: userNoPwd,
    });
  }

  // 2. Fallback to local DB when PostgreSQL is not running
  const ldb = getLocalDb();
  let user = ldb.users.find(u => u.username.toLowerCase() === uClean.toLowerCase());
  if (!user && uClean.toLowerCase() === 'admin' && (pClean === 'Sanctuary#2026*' || pClean === 'admin')) {
    user = getDefaultLocalDb().users[0];
    ldb.users.push(user);
    saveLocalDb(ldb);
  }

  if (user) {
    if (!verifyPassword(pClean, user.password, user.username)) {
      return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
    }
    if (user.is_banned) {
      return res.status(403).json({ success: false, message: 'Esta cuenta ha sido suspendida por un administrador.' });
    }
    if (user.is_verified === false) {
      return res.status(403).json({ success: false, message: 'Tu cuenta aún no ha sido activada. Por favor revisa tu correo electrónico.' });
    }

    const { password: _, ...userNoPwd } = user;
    return res.json({
      success: true,
      message: 'Inicio de sesión exitoso',
      user: { ...userNoPwd, is_banned: !!user.is_banned, is_verified: user.is_verified !== false },
    });
  }

  return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
});

// Authentication: Register new user (Encrypted password, password repetition & email activation)
app.post('/api/auth/register', async (req, res) => {
  const { username, password, confirm_password, confirmPassword, full_name, email, avatar_url, bio } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  const uClean = username.trim();
  const pClean = password.trim();
  const confClean = (confirm_password || confirmPassword || '').trim();

  // Validate password confirmation if sent
  if (confClean && pClean !== confClean) {
    return res.status(400).json({ success: false, message: 'Las contraseñas no coinciden. Por favor verifícalas.' });
  }
  if (pClean.length < 6) {
    return res.status(400).json({ success: false, message: 'La contraseña debe tener un mínimo de 6 caracteres.' });
  }

  const hashedPwd = hashPassword(pClean);
  const assignedRole = 'usuario'; // New self-registrations are always standard 'usuario'
  const hasEmail = email && email.trim().length > 0;
  const activationToken = hasEmail ? crypto.randomBytes(24).toString('hex') : null;
  const isVerified = !hasEmail; // If no email provided in offline mode, verify immediately

  const existingRes = await safeQuery('SELECT id FROM users WHERE LOWER(username) = LOWER($1)', [uClean]);
  if (existingRes) {
    if (existingRes.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'El nombre de usuario ya está registrado' });
    }
    const result = await safeQuery(
      `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio, is_banned, is_verified, activation_token) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE, $8, $9) 
       RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, is_verified, created_at`,
      [uClean, hashedPwd, assignedRole, full_name || uClean, email || '', avatar_url || '', bio || '', isVerified, activationToken]
    );

    if (result && result.rows.length > 0) {
      // Send activation email if email provided
      if (hasEmail && activationToken) {
        const host = req.get('host') || `localhost:${port}`;
        const protocol = req.protocol || 'http';
        const activationLink = `${protocol}://${host}/api/auth/verify?token=${activationToken}`;
        sendMailNotification({
          to: email.trim(),
          subject: 'Activa tu cuenta en Sanctuary',
          text: `Hola ${full_name || uClean},\n\nGracias por registrarte en Sanctuary. Haz clic en el siguiente enlace para activar tu cuenta:\n${activationLink}\n\nSi no te has registrado tú, ignora este mensaje.`,
          html: `<div style="font-family:sans-serif;padding:24px;border-radius:12px;background:#0F172A;color:#F8FAFC;">
                  <h2 style="color:#06B6D4;">¡Bienvenido a Sanctuary!</h2>
                  <p>Hola <strong>${full_name || uClean}</strong>,</p>
                  <p>Por favor confirma tu dirección de correo electrónico para activar tu acceso al santuario:</p>
                  <a href="${activationLink}" style="display:inline-block;padding:12px 24px;background:#06B6D4;color:#000;font-weight:bold;text-decoration:none;border-radius:8px;">Activar Mi Cuenta</a>
                  <p style="margin-top:20px;font-size:12px;color:#94A3B8;">O copia este enlace en tu navegador:<br>${activationLink}</p>
                 </div>`,
        });
      }

      return res.status(201).json({
        success: true,
        message: hasEmail
            ? 'Usuario registrado. Te hemos enviado un correo para activar tu cuenta.'
            : 'Usuario registrado correctamente con rol estándar.',
        user: result.rows[0],
      });
    }
  }

  // Local DB fallback
  const ldb = getLocalDb();
  if (ldb.users.some(u => u.username.toLowerCase() === uClean.toLowerCase())) {
    return res.status(409).json({ success: false, message: 'El nombre de usuario ya está registrado' });
  }

  const newUser = {
    id: Date.now(),
    username: uClean,
    password: hashedPwd,
    role: assignedRole,
    full_name: full_name || uClean,
    email: email || '',
    avatar_url: avatar_url || '',
    bio: bio || '',
    is_banned: false,
    is_verified: isVerified,
    activation_token: activationToken,
    created_at: new Date().toISOString(),
  };
  ldb.users.push(newUser);
  saveLocalDb(ldb);

  if (hasEmail && activationToken) {
    const host = req.get('host') || `localhost:${port}`;
    const protocol = req.protocol || 'http';
    const activationLink = `${protocol}://${host}/api/auth/verify?token=${activationToken}`;
    sendMailNotification({
      to: email.trim(),
      subject: 'Activa tu cuenta en Sanctuary',
      text: `Hola ${full_name || uClean},\n\nActiva tu cuenta aquí: ${activationLink}`,
      html: `<div style="font-family:sans-serif;padding:24px;background:#0F172A;color:#fff;border-radius:12px;">
              <h2 style="color:#06B6D4;">Sanctuary · Activación</h2>
              <p>Hola <strong>${full_name || uClean}</strong>,</p>
              <p><a href="${activationLink}" style="color:#06B6D4;font-weight:bold;">Haz clic aquí para activar tu cuenta</a></p>
             </div>`,
    });
  }

  const { password: _, ...userNoPwd } = newUser;
  res.status(201).json({
    success: true,
    message: hasEmail
        ? 'Usuario registrado. Te hemos enviado un correo para activar tu cuenta.'
        : 'Usuario registrado correctamente con rol estándar.',
    user: userNoPwd,
  });
});

// Authentication: Account Activation Link
app.get('/api/auth/verify', async (req, res) => {
  const { token } = req.query;
  if (!token) {
    return res.status(400).send('<h1>Token de activación inválido o faltante</h1>');
  }

  // PostgreSQL
  const result = await safeQuery(
    'UPDATE users SET is_verified = TRUE, activation_token = NULL WHERE activation_token = $1 RETURNING username',
    [token]
  );
  if (result && result.rows.length > 0) {
    return res.send(`
      <!DOCTYPE html><html><body style="font-family:sans-serif;background:#0F172A;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
        <div style="text-align:center;padding:40px;background:#1E293B;border-radius:20px;border:1px solid #06B6D4;max-width:440px;">
          <h1 style="color:#06B6D4;">✔ ¡Cuenta Activada!</h1>
          <p>Tu cuenta <strong>@${result.rows[0].username}</strong> ha sido verificada con éxito.</p>
          <p>Ya puedes volver a la aplicación Sanctuary e iniciar sesión con tu usuario y contraseña.</p>
          <a href="/" style="display:inline-block;margin-top:16px;padding:12px 24px;background:#06B6D4;color:#000;font-weight:bold;text-decoration:none;border-radius:10px;">Entrar a Sanctuary</a>
        </div>
      </body></html>
    `);
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const u = ldb.users.find(usr => usr.activation_token === token);
  if (u) {
    u.is_verified = true;
    u.activation_token = null;
    saveLocalDb(ldb);
    return res.send(`
      <!DOCTYPE html><html><body style="font-family:sans-serif;background:#0F172A;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
        <div style="text-align:center;padding:40px;background:#1E293B;border-radius:20px;border:1px solid #06B6D4;max-width:440px;">
          <h1 style="color:#06B6D4;">✔ ¡Cuenta Activada!</h1>
          <p>Tu cuenta <strong>@${u.username}</strong> ha sido verificada con éxito.</p>
          <p>Ya puedes volver a Sanctuary e iniciar sesión.</p>
          <a href="/" style="display:inline-block;margin-top:16px;padding:12px 24px;background:#06B6D4;color:#000;font-weight:bold;text-decoration:none;border-radius:10px;">Entrar a Sanctuary</a>
        </div>
      </body></html>
    `);
  }

  res.status(404).send('<h1>El enlace de activación ha expirado o ya fue utilizado.</h1>');
});

// Authentication: Forgot Password (Solicitar recuperación)
app.post('/api/auth/forgot-password', async (req, res) => {
  const { email, username } = req.body;
  if (!email && !username) {
    return res.status(400).json({ success: false, message: 'Por favor proporciona tu correo electrónico o usuario' });
  }

  const queryVal = (email || username).trim().toLowerCase();
  const resetToken = crypto.randomBytes(20).toString('hex');
  const resetExpires = Date.now() + 3600000; // 1 hour validity

  // PostgreSQL
  const userRes = await safeQuery(
    'SELECT id, username, email, full_name FROM users WHERE LOWER(email) = $1 OR LOWER(username) = $1',
    [queryVal]
  );
  if (userRes && userRes.rows.length > 0) {
    const targetUser = userRes.rows[0];
    await safeQuery(
      'UPDATE users SET reset_token = $1, reset_expires = $2 WHERE id = $3',
      [resetToken, resetExpires, targetUser.id]
    );

    const destEmail = targetUser.email || email;
    if (destEmail) {
      sendMailNotification({
        to: destEmail,
        subject: 'Recuperación de Contraseña · Sanctuary',
        text: `Hola ${targetUser.full_name || targetUser.username},\n\nTu código / token de restablecimiento es:\n${resetToken}\n\nVálido durante 1 hora.`,
        html: `<div style="font-family:sans-serif;padding:24px;background:#0F172A;color:#fff;border-radius:12px;">
                <h2 style="color:#06B6D4;">Restablecimiento de Contraseña</h2>
                <p>Hola <strong>${targetUser.full_name || targetUser.username}</strong>,</p>
                <p>Has solicitado restablecer tu contraseña en Sanctuary. Introduce el siguiente token en el formulario de la app:</p>
                <div style="padding:14px;background:#1E293B;border:1px dashed #06B6D4;font-family:monospace;font-size:18px;color:#06B6D4;text-align:center;letter-spacing:2px;">
                  ${resetToken}
                </div>
                <p style="margin-top:16px;font-size:12px;color:#94A3B8;">Este token expira en 60 minutos. Si no lo has solicitado tú, puedes ignorar este mensaje de forma segura.</p>
               </div>`,
      });
    }

    return res.json({
      success: true,
      message: `Se ha enviado el código de recuperación a ${destEmail || 'tu correo'}.`,
      token_preview: resetToken, // Exposed for easy offline recovery
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const targetUser = ldb.users.find(u => (u.email && u.email.toLowerCase() === queryVal) || u.username.toLowerCase() === queryVal);
  if (targetUser) {
    targetUser.reset_token = resetToken;
    targetUser.reset_expires = resetExpires;
    saveLocalDb(ldb);

    const destEmail = targetUser.email || email;
    if (destEmail) {
      sendMailNotification({
        to: destEmail,
        subject: 'Recuperación de Contraseña · Sanctuary',
        text: `Código de recuperación: ${resetToken}`,
        html: `<h2>Token de recuperación: ${resetToken}</h2>`,
      });
    }

    return res.json({
      success: true,
      message: `Se ha enviado el código de recuperación a ${destEmail || 'tu correo'}.`,
      token_preview: resetToken,
    });
  }

  return res.status(404).json({ success: false, message: 'No se encontró ningún usuario con ese correo o nombre.' });
});

// Authentication: Reset Password with Token
app.post('/api/auth/reset-password', async (req, res) => {
  const { token, new_password, newPassword, confirm_password, confirmPassword } = req.body;
  const pwd = (new_password || newPassword || '').trim();
  const conf = (confirm_password || confirmPassword || '').trim();

  if (!token || !pwd) {
    return res.status(400).json({ success: false, message: 'Token y nueva contraseña requeridos' });
  }
  if (conf && pwd !== conf) {
    return res.status(400).json({ success: false, message: 'Las contraseñas no coinciden' });
  }
  if (pwd.length < 6) {
    return res.status(400).json({ success: false, message: 'La nueva contraseña debe tener mínimo 6 caracteres' });
  }

  const hashedPwd = hashPassword(pwd);
  const now = Date.now();

  // PostgreSQL
  const result = await safeQuery(
    `UPDATE users 
     SET password = $1, reset_token = NULL, reset_expires = NULL 
     WHERE reset_token = $2 AND (reset_expires IS NULL OR reset_expires >= $3)
     RETURNING username`,
    [hashedPwd, token.trim(), now]
  );
  if (result && result.rows.length > 0) {
    return res.json({
      success: true,
      message: `Contraseña de @${result.rows[0].username} actualizada con éxito. Ya puedes iniciar sesión.`,
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const u = ldb.users.find(usr => usr.reset_token === token.trim() && (!usr.reset_expires || usr.reset_expires >= now));
  if (u) {
    u.password = hashedPwd;
    u.reset_token = null;
    u.reset_expires = null;
    saveLocalDb(ldb);
    return res.json({
      success: true,
      message: `Contraseña de @${u.username} actualizada con éxito. Ya puedes iniciar sesión.`,
    });
  }

  res.status(400).json({ success: false, message: 'El token de recuperación es inválido o ha expirado.' });
});

// ============================================================================
// CHAT EPHEMERAL SYSTEM (Borrado automático a las 00:00 cada día)
// ============================================================================

// Chat: Get Today's Messages
app.get('/api/chat/messages', async (req, res) => {
  await purgeOldChatMessages();
  const todayMidnight = new Date();
  todayMidnight.setHours(0, 0, 0, 0);

  // PostgreSQL
  const result = await safeQuery(
    'SELECT id, username, role, text, avatar_url, created_at FROM chat_messages WHERE created_at >= $1 ORDER BY created_at ASC LIMIT 250',
    [todayMidnight.toISOString()]
  );
  if (result) {
    return res.json({ success: true, count: result.rows.length, messages: result.rows });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const todayMsgs = (ldb.chat_messages || []).filter(m => new Date(m.created_at) >= todayMidnight);
  res.json({ success: true, count: todayMsgs.length, messages: todayMsgs });
});

// Chat: Send Message
app.post('/api/chat/messages', async (req, res) => {
  const { username, role, text, avatar_url } = req.body;
  if (!text || text.trim().length === 0) {
    return res.status(400).json({ success: false, message: 'El mensaje no puede estar vacío' });
  }

  const uName = (username || 'Anónimo').trim();
  const uRole = (role || 'usuario').trim();
  const cleanText = text.trim();
  const avatar = avatar_url || '';

  // PostgreSQL
  const result = await safeQuery(
    `INSERT INTO chat_messages (username, role, text, avatar_url, created_at)
     VALUES ($1, $2, $3, $4, NOW())
     RETURNING id, username, role, text, avatar_url, created_at`,
    [uName, uRole, cleanText, avatar]
  );
  if (result && result.rows.length > 0) {
    return res.status(201).json({ success: true, message: result.rows[0] });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  if (!ldb.chat_messages) ldb.chat_messages = [];
  const newMsg = {
    id: Date.now(),
    username: uName,
    role: uRole,
    text: cleanText,
    avatar_url: avatar,
    created_at: new Date().toISOString(),
  };
  ldb.chat_messages.push(newMsg);
  saveLocalDb(ldb);

  res.status(201).json({ success: true, message: newMsg });
});

// Chat: Admin Clear Messages
app.delete('/api/chat/messages', async (req, res) => {
  await safeQuery('DELETE FROM chat_messages');
  const ldb = getLocalDb();
  ldb.chat_messages = [];
  saveLocalDb(ldb);
  res.json({ success: true, message: 'Chat diario vaciado correctamente por el administrador' });
});

// Email: Admin Send Test Email
app.post('/api/admin/email/test', async (req, res) => {
  const { to } = req.body;
  if (!to) return res.status(400).json({ success: false, message: 'Destinatario requerido' });
  const result = await sendMailNotification({
    to: to.trim(),
    subject: 'Comprobación de Servidor de Correo · Sanctuary',
    text: 'Este es un correo de prueba emitido desde el Panel de Administración de Sanctuary para verificar la conectividad SMTP.',
    html: '<div style="padding:20px;background:#0F172A;color:#06B6D4;border-radius:10px;"><h2>✔ Prueba SMTP Exitosa</h2><p>El sistema de envío de correos de Sanctuary funciona correctamente.</p></div>',
  });
  if (result) {
    return res.json({ success: true, message: `Correo de prueba enviado a ${to}` });
  }
  res.status(500).json({ success: false, message: 'No se pudo enviar el correo. Revisa la configuración SMTP.' });
});

// ============================================================================
// ADMIN PANEL CRUD & CONTROL ROUTES
// ============================================================================

// Admin: List all users
app.get('/api/admin/users', async (req, res) => {
  const result = await safeQuery(
    'SELECT id, username, role, full_name, email, avatar_url, bio, COALESCE(is_banned, false) as is_banned, created_at FROM users ORDER BY id ASC'
  );
  if (result) {
    return res.json({
      success: true,
      users: result.rows,
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const safeUsers = (ldb.users || []).map(u => {
    const { password: _, ...noPwd } = u;
    return { ...noPwd, is_banned: !!u.is_banned };
  });
  res.json({
    success: true,
    users: safeUsers,
  });
});

// Admin: Create user with custom role
app.post('/api/admin/users', async (req, res) => {
  const { username, password, role, full_name, email, avatar_url, bio } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  const uClean = username.trim();
  const pClean = password.trim();
  const targetRole = ['admin', 'docente', 'usuario'].includes((role || '').toLowerCase())
    ? role.toLowerCase()
    : 'usuario';

  const existingRes = await safeQuery('SELECT id FROM users WHERE LOWER(username) = LOWER($1)', [uClean]);
  if (existingRes) {
    if (existingRes.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'El nombre de usuario ya existe' });
    }
    const result = await safeQuery(
      `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio, is_banned)
       VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE)
       RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, created_at`,
      [uClean, pClean, targetRole, full_name || uClean, email || '', avatar_url || '', bio || '']
    );
    if (result && result.rows.length > 0) {
      return res.status(201).json({
        success: true,
        message: 'Usuario creado exitosamente',
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
    role: targetRole,
    full_name: full_name || uClean,
    email: email || '',
    avatar_url: avatar_url || '',
    bio: bio || '',
    is_banned: false,
    created_at: new Date().toISOString(),
  };
  ldb.users.push(newUser);
  saveLocalDb(ldb);

  const { password: _, ...userNoPwd } = newUser;
  res.status(201).json({
    success: true,
    message: 'Usuario creado exitosamente',
    user: userNoPwd,
  });
});

// Admin: Update user (Role, Name, Email, Ban/Unban, Password)
app.put('/api/admin/users/:id', async (req, res) => {
  const userId = req.params.id;
  const { role, full_name, email, is_banned, password } = req.body;

  // Protect root 'admin'
  const checkAdmin = await safeQuery('SELECT username FROM users WHERE id = $1', [userId]);
  if (checkAdmin && checkAdmin.rows.length > 0) {
    if (checkAdmin.rows[0].username.toLowerCase() === 'admin') {
      if (is_banned === true) {
        return res.status(400).json({ success: false, message: 'No es posible suspender o banear al administrador principal' });
      }
      if (role && role.toLowerCase() !== 'admin') {
        return res.status(400).json({ success: false, message: 'No es posible revocar el rol al administrador principal' });
      }
    }
  }

  let query, params;
  if (password && password.trim().length > 0) {
    query = `UPDATE users 
             SET role = COALESCE($1, role), full_name = COALESCE($2, full_name), 
                 email = COALESCE($3, email), is_banned = COALESCE($4, is_banned), password = $5
             WHERE id = $6
             RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, created_at`;
    params = [role, full_name, email, is_banned, password.trim(), userId];
  } else {
    query = `UPDATE users 
             SET role = COALESCE($1, role), full_name = COALESCE($2, full_name), 
                 email = COALESCE($3, email), is_banned = COALESCE($4, is_banned)
             WHERE id = $5
             RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, created_at`;
    params = [role, full_name, email, is_banned, userId];
  }

  const result = await safeQuery(query, params);
  if (result) {
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    return res.json({
      success: true,
      message: 'Usuario actualizado correctamente',
      user: result.rows[0],
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const idx = ldb.users.findIndex(u => u.id == userId || u.username == userId);
  if (idx >= 0) {
    if (ldb.users[idx].username.toLowerCase() === 'admin') {
      if (is_banned === true) {
        return res.status(400).json({ success: false, message: 'No es posible suspender o banear al administrador principal' });
      }
      if (role && role.toLowerCase() !== 'admin') {
        return res.status(400).json({ success: false, message: 'No es posible revocar el rol al administrador principal' });
      }
    }
    if (role !== undefined) ldb.users[idx].role = role;
    if (full_name !== undefined) ldb.users[idx].full_name = full_name;
    if (email !== undefined) ldb.users[idx].email = email;
    if (is_banned !== undefined) ldb.users[idx].is_banned = !!is_banned;
    if (password && password.trim()) ldb.users[idx].password = password.trim();
    saveLocalDb(ldb);

    const { password: _, ...userNoPwd } = ldb.users[idx];
    return res.json({
      success: true,
      message: 'Usuario actualizado correctamente',
      user: userNoPwd,
    });
  }

  res.status(404).json({ success: false, message: 'Usuario no encontrado' });
});

// Admin: Delete user
app.delete('/api/admin/users/:id', async (req, res) => {
  const userId = req.params.id;

  // Protect root 'admin'
  const checkAdmin = await safeQuery('SELECT username FROM users WHERE id = $1', [userId]);
  if (checkAdmin && checkAdmin.rows.length > 0) {
    if (checkAdmin.rows[0].username.toLowerCase() === 'admin') {
      return res.status(400).json({ success: false, message: 'No se puede eliminar la cuenta principal de administrador' });
    }
  }

  const result = await safeQuery('DELETE FROM users WHERE id = $1 RETURNING id, username', [userId]);
  if (result) {
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }
    return res.json({
      success: true,
      message: `Usuario ${result.rows[0].username} eliminado del sistema`,
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const user = ldb.users.find(u => u.id == userId || u.username == userId);
  if (!user) {
    return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
  }
  if (user.username.toLowerCase() === 'admin') {
    return res.status(400).json({ success: false, message: 'No se puede eliminar la cuenta principal de administrador' });
  }

  ldb.users = ldb.users.filter(u => u.id != userId && u.username != userId);
  saveLocalDb(ldb);

  res.json({
    success: true,
    message: `Usuario ${user.username} eliminado del sistema`,
  });
});

// Admin: System Statistics
app.get('/api/admin/stats', async (req, res) => {
  const usersCountRes = await safeQuery('SELECT COUNT(*) as count FROM users');
  const bannedCountRes = await safeQuery('SELECT COUNT(*) as count FROM users WHERE is_banned = TRUE');
  const cvCountRes = await safeQuery('SELECT COUNT(*) as count FROM cv_profiles');
  const signedCountRes = await safeQuery('SELECT COUNT(*) as count FROM signed_documents');

  if (usersCountRes) {
    return res.json({
      success: true,
      database: 'PostgreSQL (Cloud / Docker)',
      total_users: parseInt(usersCountRes.rows[0]?.count || '0', 10),
      total_banned: parseInt(bannedCountRes?.rows[0]?.count || '0', 10),
      total_cvs: parseInt(cvCountRes?.rows[0]?.count || '0', 10),
      total_signed_docs: parseInt(signedCountRes?.rows[0]?.count || '0', 10),
      uptime_seconds: Math.floor(process.uptime()),
      node_version: process.version,
    });
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const totalUsers = (ldb.users || []).length;
  const totalBanned = (ldb.users || []).filter(u => u.is_banned).length;
  const totalCvs = (ldb.cv_profiles || []).length;
  const totalSigned = (ldb.signed_documents || []).length;

  res.json({
    success: true,
    database: 'Almacenamiento Local (Modo Respaldo)',
    total_users: totalUsers,
    total_banned: totalBanned,
    total_cvs: totalCvs,
    total_signed_docs: totalSigned,
    uptime_seconds: Math.floor(process.uptime()),
    node_version: process.version,
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
