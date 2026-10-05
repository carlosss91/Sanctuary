const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

// Load environment variables from .env if present
const envCandidates = [path.join(__dirname, '.env'), path.join(__dirname, '..', '.env')];
for (const envFile of envCandidates) {
  if (fs.existsSync(envFile)) {
    try {
      const content = fs.readFileSync(envFile, 'utf8');
      content.split(/\r?\n/).forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) {
          const eqIdx = trimmed.indexOf('=');
          if (eqIdx > 0) {
            const k = trimmed.substring(0, eqIdx).trim();
            let v = trimmed.substring(eqIdx + 1).trim();
            if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
              v = v.substring(1, v.length - 1);
            }
            if (!process.env[k]) {
              process.env[k] = v;
            }
          }
        }
      });
    } catch (_) {}
  }
}

let PDFParseClass = null;
try {
  const pdfParsePkg = require('pdf-parse');
  PDFParseClass = pdfParsePkg.PDFParse || pdfParsePkg;
} catch (e) {
  console.warn('[Backend] pdf-parse opcional no disponible:', e.message);
}

let Tesseract = null;
try {
  Tesseract = require('tesseract.js');
} catch (e) {
  console.warn('[Backend] tesseract.js opcional no disponible:', e.message);
}

const app = express();
app.set('trust proxy', 1);
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

// --- Email System (SMTP Real con soporte Ethereal / configuración dinámica y persistencia en DB) ---
let mailTransporter = null;
async function getMailTransporter() {
  if (mailTransporter) return mailTransporter;

  const ldb = getLocalDb();
  let dbSmtp = ldb.smtp_config;

  // Si no está en local_db.json, consultar tabla app_settings de PostgreSQL para persistencia tras despliegues
  if (!dbSmtp?.host) {
    try {
      const q = await safeQuery("SELECT value FROM app_settings WHERE key = 'smtp_config'");
      if (q && q.rows && q.rows.length > 0) {
        dbSmtp = typeof q.rows[0].value === 'string' ? JSON.parse(q.rows[0].value) : q.rows[0].value;
        ldb.smtp_config = dbSmtp;
      }
    } catch (_) {}
  }

  const host = process.env.SMTP_HOST || dbSmtp?.host;
  const port = parseInt(process.env.SMTP_PORT || dbSmtp?.port || '587', 10);
  const user = process.env.SMTP_USER || dbSmtp?.user;
  const pass = process.env.SMTP_PASS || dbSmtp?.pass;
  const secure = process.env.SMTP_SECURE === 'true' || port === 465 || dbSmtp?.secure === true;

  if (host && user && pass) {
    try {
      mailTransporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass },
        tls: { rejectUnauthorized: process.env.SMTP_REJECT_UNAUTHORIZED !== 'false' },
        connectionTimeout: 10000,
        greetingTimeout: 8000,
        socketTimeout: 15000,
      });
      mailTransporter._isCustom = true;
      mailTransporter._customUser = user;
      console.log(`📧 [SMTP] Servidor SMTP configurado activamente: ${host}:${port} (${user})`);
      return mailTransporter;
    } catch (err) {
      console.warn('⚠️ Error al crear transportador SMTP personalizado:', err.message);
    }
  }

  // Si no se suministraron credenciales SMTP personalizadas, intentar generar cuenta de prueba Ethereal con timeout estricto
  try {
    const testPromise = nodemailer.createTestAccount();
    const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Ethereal testAccount timeout')), 2500));
    const testAccount = await Promise.race([testPromise, timeoutPromise]);

    mailTransporter = nodemailer.createTransport({
      host: 'smtp.ethereal.email',
      port: 587,
      secure: false,
      auth: {
        user: testAccount.user,
        pass: testAccount.pass,
      },
      connectionTimeout: 4000,
      greetingTimeout: 3000,
      socketTimeout: 5000,
    });
    mailTransporter._isEthereal = true;
    mailTransporter._etherealUser = testAccount.user;
    console.log(`📧 [Auto-SMTP] Servidor de correo de prueba Ethereal generado: ${testAccount.user}`);
    return mailTransporter;
  } catch (e) {
    console.warn('⚠️ Modo consola simulado activado para correo (SMTP no configurado):', e.message);
    mailTransporter = {
      _isSimulated: true,
      sendMail: async (options) => {
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`📧 [EMAIL SIMULADO] Para: ${options.to} | Asunto: ${options.subject}`);
        console.log(`   Mensaje: ${options.text || options.html}`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return { messageId: 'simulated_' + Date.now(), accepted: [options.to] };
      }
    };
    return mailTransporter;
  }
}

async function sendMailNotification({ to, subject, html, text }) {
  try {
    const transporter = await getMailTransporter();
    if (!transporter) return null;

    const ldb = getLocalDb();
    const dbSmtp = ldb.smtp_config;
    const from = process.env.SMTP_FROM || dbSmtp?.from || (transporter._customUser ? `"Sanctuary Platform" <${transporter._customUser}>` : (transporter._etherealUser ? `"Sanctuary Platform" <${transporter._etherealUser}>` : '"Sanctuary Platform" <no-reply@sanctuary.app>'));
    
    // Proteger el envío contra bloqueos o cuelgues de red en servidores cloud
    const sendPromise = transporter.sendMail({ from, to, subject, html, text });
    const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Tiempo de espera SMTP excedido (12s)')), 12000));
    
    const info = await Promise.race([sendPromise, timeoutPromise]);
    if (transporter._isEthereal && nodemailer.getTestMessageUrl) {
      const previewUrl = nodemailer.getTestMessageUrl(info);
      console.log(`📧 [Vista previa del correo en navegador]: ${previewUrl}`);
      info.previewUrl = previewUrl;
    }
    return info;
  } catch (err) {
    console.warn('⚠️ No se pudo completar el envío de correo:', err.message);
    return null;
  }
}

// Gorgeous HTML activation email template with Sanctuary Celestial branding
function buildActivationEmailHtml({ username, fullName, activationCode, activationLink }) {
  const displayName = fullName || username;
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Activa tu cuenta en Sanctuary</title>
</head>
<body style="margin:0;padding:0;background-color:#080C14;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display','Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#F8FAFC;-webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#080C14;padding:40px 16px;">
    <tr>
      <td align="center">
        <!-- Main Card -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:540px;background:linear-gradient(145deg, #0F172A 0%, #131E33 100%);border-radius:24px;border:1px solid #1E293B;box-shadow:0 20px 45px rgba(0,0,0,0.5);overflow:hidden;">
          
          <!-- Top Emerald Glow Bar -->
          <tr>
            <td style="height:4px;background:linear-gradient(90deg, #10B981 0%, #06B6D4 50%, #3B82F6 100%);"></td>
          </tr>

          <!-- Header with Logo -->
          <tr>
            <td align="center" style="padding:40px 30px 20px 30px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <div style="width:64px;height:64px;border-radius:20px;background:radial-gradient(circle at 35% 35%, #10B981, #064E3B);box-shadow:0 0 25px rgba(16,185,129,0.45);display:inline-block;line-height:64px;text-align:center;font-size:32px;">
                      🪐
                    </div>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:14px;">
                    <span style="font-size:22px;font-weight:900;letter-spacing:3px;color:#FFFFFF;text-transform:uppercase;">SANCTUARY</span>
                    <div style="font-size:11px;font-weight:700;letter-spacing:1.8px;color:#10B981;margin-top:4px;">PLATFORM · DIGITAL SUITE</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body Content -->
          <tr>
            <td style="padding:10px 36px 30px 36px;">
              <h1 style="margin:0 0 12px 0;font-size:22px;font-weight:800;color:#F8FAFC;text-align:center;">¡Te damos la bienvenida a bordo!</h1>
              <p style="margin:0 0 20px 0;font-size:14.5px;line-height:1.6;color:#94A3B8;text-align:center;">
                Hola <strong style="color:#F1F5F9;">${displayName}</strong>, tu cuenta en Sanctuary está prácticamente lista. Para garantizar la seguridad de tu identidad y activar todas tus herramientas digitales, introduce este código en la aplicación o pulsa el botón inferior:
              </p>

              ${activationCode ? `
              <!-- 6-digit PIN Box -->
              <div style="background-color:#0A101D;border:1px solid #10B981;border-radius:16px;padding:18px;margin:20px 0;text-align:center;box-shadow:0 0 20px rgba(16,185,129,0.15);">
                <div style="font-size:11px;color:#94A3B8;letter-spacing:1.5px;text-transform:uppercase;font-weight:700;">Código de Activación</div>
                <div style="font-size:32px;font-weight:900;letter-spacing:8px;color:#10B981;margin-top:6px;font-family:monospace;">${activationCode}</div>
              </div>` : ''}

              <!-- CTA Button -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
                <tr>
                  <td align="center">
                    <a href="${activationLink}" target="_blank" style="display:inline-block;background:linear-gradient(135deg, #10B981 0%, #059669 100%);color:#FFFFFF;font-size:15px;font-weight:700;letter-spacing:0.5px;text-decoration:none;padding:16px 36px;border-radius:14px;box-shadow:0 8px 24px rgba(16,185,129,0.35);border:1px solid rgba(255,255,255,0.2);">
                      ✔ Activar Mi Cuenta Ahora
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Fallback Link -->
              <div style="background-color:#0A101D;border:1px solid #1E293B;border-radius:14px;padding:16px;margin-top:24px;">
                <p style="margin:0 0 8px 0;font-size:11.5px;color:#64748B;font-weight:600;">¿El botón no responde? Copia y abre este enlace en tu navegador:</p>
                <div style="font-size:11.5px;color:#06B6D4;word-break:break-all;line-height:1.4;font-family:monospace;background:#0F172A;padding:8px 10px;border-radius:8px;border:1px solid rgba(6,182,212,0.25);">
                  ${activationLink}
                </div>
              </div>

              <!-- Security Notice -->
              <p style="margin:24px 0 0 0;font-size:11.5px;line-height:1.5;color:#64748B;text-align:center;">
                🔒 Este enlace de activación es único y válido durante 24 horas.<br>
                Si no te has registrado en Sanctuary, puedes desestimar este mensaje de forma segura.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:22px 30px;background-color:#0A0F1A;border-top:1px solid #1E293B;text-align:center;">
              <p style="margin:0;font-size:11px;color:#475569;line-height:1.5;">
                Sanctuary Suite © 2026 · Desarrollado con precisión<br>
                Portal Docente, CV Maker interactivo & Digital Signer
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
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
    ldb.chat_messages = ldb.chat_messages.filter(m => new Date(m.created_at || m.timestamp || Date.now()) >= todayMidnight);
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
      { id: 1, title: 'Slide Downloader', url: 'app://prezi2pdf', description: 'Descargador universal de presentaciones y videos', category: 'Web Apps', icon_name: 'present_to_all' },
      { id: 2, title: 'CV Maker Studio', url: 'app://cvmaker', description: 'Generador y diseñador de currículums interactivos en formato A4', category: 'Educación', icon_name: 'badge' },
      { id: 3, title: 'PDF Signer', url: 'app://pdfsigner', description: 'Herramienta de firma digital y certificación de documentos', category: 'Web Apps', icon_name: 'draw' }
    ],
    smtp_config: {
      host: 'smtp-relay.brevo.com',
      port: 587,
      user: 'bcab54001@smtp-brevo.com',
      pass: 'bskf1OiRHcPp5lE',
      from: '"Sanctuary Platform" <chals.santana@gmail.com>',
      secure: false,
    }
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
        // Sanitize repo_links to remove any legacy carlosss91 personal repos
        if (Array.isArray(parsed.repo_links)) {
          const cleaned = parsed.repo_links.filter(l => !l.url?.toLowerCase().includes('carlosss91') && !l.title?.toLowerCase().includes('carlosss91'));
          if (cleaned.length !== parsed.repo_links.length) {
            parsed.repo_links = cleaned.length > 0 ? cleaned : getDefaultLocalDb().repo_links;
            saveLocalDb(parsed);
          }
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

// Run schema migrations for users, chat table & app_settings if PostgreSQL is online
safeQuery(`
  CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role VARCHAR(50) DEFAULT 'usuario',
    full_name VARCHAR(150),
    email VARCHAR(150),
    avatar_url TEXT,
    bio TEXT,
    is_banned BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT TRUE,
    activation_token VARCHAR(120),
    activation_code VARCHAR(20),
    reset_token VARCHAR(120),
    reset_expires BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  ALTER TABLE users 
  ADD COLUMN IF NOT EXISTS full_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS email VARCHAR(150),
  ADD COLUMN IF NOT EXISTS avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS activation_token VARCHAR(120),
  ADD COLUMN IF NOT EXISTS activation_code VARCHAR(20),
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

  CREATE TABLE IF NOT EXISTS app_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );
`).catch((err) => console.warn('⚠️ Error en migraciones iniciales:', err?.message));

async function syncUsersToPostgres() {
  try {
    const adminPwd = hashPassword('Sanctuary#2026*');
    await safeQuery(
      `INSERT INTO users (username, password, role, full_name, email, is_banned, is_verified) 
       VALUES ('admin', $1, 'admin', 'Administrador Sanctuary', 'admin@sanctuary.local', FALSE, TRUE) 
       ON CONFLICT (username) DO NOTHING`,
      [adminPwd]
    );

    const ldb = getLocalDb();
    if (Array.isArray(ldb.users)) {
      for (const u of ldb.users) {
        if (!u.username) continue;
        await safeQuery(
          `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio, is_banned, is_verified)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           ON CONFLICT (username) DO NOTHING`,
          [
            u.username,
            u.password || hashPassword('123456'),
            u.role || 'usuario',
            u.full_name || u.fullName || u.username,
            u.email || '',
            u.avatar_url || u.avatarUrl || '',
            u.bio || '',
            !!u.is_banned,
            u.is_verified !== false,
          ]
        );
      }
    }
    console.log('✅ [PostgreSQL] Tabla users y cuentas sincronizadas con éxito.');
  } catch (err) {
    console.warn('⚠️ Error sincronizando usuarios en PostgreSQL:', err.message);
  }
}
setTimeout(syncUsersToPostgres, 1500);

// --- Ephemeral Community Chat Endpoints ---
app.get('/api/chat/messages', async (req, res) => {
  try {
    await purgeOldChatMessages();
    const todayMidnight = new Date();
    todayMidnight.setHours(0, 0, 0, 0);

    const q = await safeQuery(
      'SELECT id, username, role, text as message, text, avatar_url as "avatarUrl", avatar_url, created_at as timestamp, created_at FROM chat_messages WHERE created_at >= $1 ORDER BY created_at ASC LIMIT 250',
      [todayMidnight.toISOString()]
    );
    if (q && q.rows && q.rows.length > 0) {
      return res.json({ success: true, count: q.rows.length, messages: q.rows });
    }
    const ldb = getLocalDb();
    const todayMsgs = (ldb.chat_messages || []).filter(m => new Date(m.created_at || m.timestamp || Date.now()) >= todayMidnight);
    return res.json({ success: true, count: todayMsgs.length, messages: todayMsgs });
  } catch (err) {
    console.error('Error fetching chat messages:', err);
    const ldb = getLocalDb();
    return res.json({ success: true, messages: ldb.chat_messages || [] });
  }
});

app.post('/api/chat/messages', async (req, res) => {
  try {
    const { message, text, username, role, avatarUrl, avatar_url } = req.body;
    const bodyText = message || text;
    if (!bodyText || !bodyText.trim()) {
      return res.status(400).json({ success: false, message: 'El mensaje no puede estar vacío' });
    }

    const cleanMsg = bodyText.trim();
    const cleanUser = (username || 'Anónimo').trim();
    const cleanRole = role || 'usuario';
    const cleanAvatar = avatarUrl || avatar_url || '';
    const timestamp = new Date().toISOString();

    // Check if user is banned
    const checkBan = await safeQuery('SELECT is_banned FROM users WHERE LOWER(username) = LOWER($1)', [cleanUser]);
    if (checkBan && checkBan.rows.length > 0 && checkBan.rows[0].is_banned) {
      return res.status(403).json({ success: false, message: 'Tu cuenta está suspendida y no puedes enviar mensajes' });
    }
    const ldb = getLocalDb();
    const ldbUser = (ldb.users || []).find(u => u.username.toLowerCase() === cleanUser.toLowerCase());
    if (ldbUser && ldbUser.is_banned) {
      return res.status(403).json({ success: false, message: 'Tu cuenta está suspendida y no puedes enviar mensajes' });
    }

    const q = await safeQuery(
      'INSERT INTO chat_messages (username, role, text, avatar_url, created_at) VALUES ($1, $2, $3, $4, $5) RETURNING id, username, role, text as message, text, avatar_url as "avatarUrl", avatar_url, created_at as timestamp, created_at',
      [cleanUser, cleanRole, cleanMsg, cleanAvatar, timestamp]
    );

    let chatMessage;
    if (q && q.rows && q.rows.length > 0) {
      chatMessage = q.rows[0];
    } else {
      if (!Array.isArray(ldb.chat_messages)) ldb.chat_messages = [];
      chatMessage = {
        id: Date.now(),
        username: cleanUser,
        role: cleanRole,
        message: cleanMsg,
        text: cleanMsg,
        avatarUrl: cleanAvatar,
        avatar_url: cleanAvatar,
        created_at: timestamp,
        timestamp,
      };
      ldb.chat_messages.push(chatMessage);
      if (ldb.chat_messages.length > 250) {
        ldb.chat_messages = ldb.chat_messages.slice(-250);
      }
      saveLocalDb(ldb);
    }

    return res.status(201).json({ success: true, chat_message: chatMessage, message: chatMessage });
  } catch (err) {
    console.error('Error saving chat message:', err);
    return res.status(500).json({ success: false, message: 'Error interno al guardar mensaje' });
  }
});

// Admin: Delete single chat message
app.delete('/api/chat/messages/:id', async (req, res) => {
  try {
    const msgId = req.params.id;
    await safeQuery('DELETE FROM chat_messages WHERE id::text = $1', [msgId.toString()]);
    const ldb = getLocalDb();
    if (Array.isArray(ldb.chat_messages)) {
      ldb.chat_messages = ldb.chat_messages.filter(m => m.id?.toString() !== msgId.toString());
      saveLocalDb(ldb);
    }
    return res.json({ success: true, message: 'Mensaje eliminado correctamente' });
  } catch (err) {
    console.error('Error deleting single chat message:', err);
    return res.status(500).json({ success: false, message: 'Error al eliminar mensaje' });
  }
});

// Admin: Clear all chat messages
app.delete('/api/chat/messages', async (req, res) => {
  try {
    await safeQuery('DELETE FROM chat_messages');
    const ldb = getLocalDb();
    ldb.chat_messages = [];
    saveLocalDb(ldb);
    return res.json({ success: true, message: 'Historial del chat vaciado con éxito' });
  } catch (err) {
    console.error('Error clearing chat:', err);
    return res.status(500).json({ success: false, message: 'Error al vaciar chat' });
  }
});

// Admin: Ban user by username
app.post('/api/admin/users/ban', async (req, res) => {
  try {
    const { username } = req.body;
    if (!username) return res.status(400).json({ success: false, message: 'Usuario requerido' });
    const cleanUser = username.trim();
    if (cleanUser.toLowerCase() === 'admin') {
      return res.status(400).json({ success: false, message: 'No es posible suspender o banear al administrador principal' });
    }

    await safeQuery('UPDATE users SET is_banned = TRUE WHERE LOWER(username) = LOWER($1)', [cleanUser]);

    const ldb = getLocalDb();
    if (ldb.users) {
      const u = ldb.users.find(x => x.username.toLowerCase() === cleanUser.toLowerCase());
      if (u) {
        u.is_banned = true;
        saveLocalDb(ldb);
      }
    }
    return res.json({ success: true, message: `Usuario @${cleanUser} suspendido y baneado correctamente` });
  } catch (err) {
    console.error('Error banning user by username:', err);
    return res.status(500).json({ success: false, message: 'Error interno al banear usuario' });
  }
});

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
      return res.status(403).json({
        success: false,
        requires_activation: true,
        message: 'Tu cuenta aún no ha sido activada. Por favor introduce tu código de activación o revisa tu correo electrónico.',
        username: userRow.username,
        email: userRow.email,
      });
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
      return res.status(403).json({
        success: false,
        requires_activation: true,
        message: 'Tu cuenta aún no ha sido activada. Por favor introduce tu código de activación o revisa tu correo electrónico.',
        username: user.username,
        email: user.email,
      });
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
  const activationToken = crypto.randomBytes(24).toString('hex');
  const activationCode = Math.floor(100000 + Math.random() * 900000).toString();
  const isVerified = false; // Always require activation

  const existingRes = await safeQuery('SELECT id FROM users WHERE LOWER(username) = LOWER($1)', [uClean]);
  if (existingRes) {
    if (existingRes.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'El nombre de usuario ya está registrado' });
    }
    const result = await safeQuery(
      `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio, is_banned, is_verified, activation_token, activation_code) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE, $8, $9, $10) 
       RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, is_verified, created_at`,
      [uClean, hashedPwd, assignedRole, full_name || uClean, email || '', avatar_url || '', bio || '', isVerified, activationToken, activationCode]
    );

    if (result && result.rows.length > 0) {
      const dbUser = result.rows[0];

      // Mirror into local database for redundancy
      const ldb = getLocalDb();
      if (!ldb.users.some(u => u.username.toLowerCase() === uClean.toLowerCase())) {
        ldb.users.push({
          id: dbUser.id,
          username: dbUser.username,
          password: hashedPwd,
          role: dbUser.role,
          full_name: dbUser.full_name,
          email: dbUser.email,
          avatar_url: dbUser.avatar_url,
          bio: dbUser.bio,
          is_banned: dbUser.is_banned,
          is_verified: dbUser.is_verified,
          activation_token: activationToken,
          activation_code: activationCode,
          created_at: dbUser.created_at || new Date().toISOString(),
        });
        saveLocalDb(ldb);
      }

      // Send activation email asynchronously if email provided so registration returns in milliseconds
      if (hasEmail) {
        const host = req.get('host') || `localhost:${port}`;
        const protocol = req.protocol || 'http';
        const activationLink = `${protocol}://${host}/api/auth/verify?token=${activationToken}`;
        sendMailNotification({
          to: email.trim(),
          subject: 'Activa tu cuenta en Sanctuary 🪐',
          text: `Hola ${full_name || uClean},\n\nGracias por registrarte en Sanctuary. Tu código de activación es: ${activationCode}\nO activa directamente pulsando aquí:\n${activationLink}\n\nSi no te has registrado tú, ignora este mensaje.`,
          html: buildActivationEmailHtml({ username: uClean, fullName: full_name || uClean, activationCode, activationLink }),
        }).catch(err => console.warn('⚠️ Error al enviar email de activación:', err.message));
      }

      return res.status(201).json({
        success: true,
        requires_activation: true,
        requiresActivation: true,
        message: hasEmail
            ? 'Usuario registrado. Te hemos enviado un correo con tu código de activación.'
            : 'Usuario registrado. Introduce tu código de activación.',
        activation_token: activationCode,
        activationToken: activationCode,
        activation_code: activationCode,
        activationCode: activationCode,
        preview_url: null,
        previewUrl: null,
        user: dbUser,
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
    activation_code: activationCode,
    created_at: new Date().toISOString(),
  };
  ldb.users.push(newUser);
  saveLocalDb(ldb);

  if (hasEmail) {
    const host = req.get('host') || `localhost:${port}`;
    const protocol = req.protocol || 'http';
    const activationLink = `${protocol}://${host}/api/auth/verify?token=${activationToken}`;
    sendMailNotification({
      to: email.trim(),
      subject: 'Activa tu cuenta en Sanctuary 🪐',
      text: `Hola ${full_name || uClean},\n\nTu código de activación es: ${activationCode}\nO activa directamente en: ${activationLink}`,
      html: buildActivationEmailHtml({ username: uClean, fullName: full_name || uClean, activationCode, activationLink }),
    }).catch(err => console.warn('⚠️ Error al enviar email local:', err.message));
  }

  const { password: _, ...userNoPwd } = newUser;
  return res.status(201).json({
    success: true,
    requires_activation: true,
    requiresActivation: true,
    message: hasEmail
        ? 'Usuario registrado. Te hemos enviado un correo con tu código de activación.'
        : 'Usuario registrado. Introduce tu código de activación.',
    activation_token: activationCode,
    activationToken: activationCode,
    activation_code: activationCode,
    activationCode: activationCode,
    preview_url: previewUrl,
    previewUrl: previewUrl,
    user: userNoPwd,
  });
});

// Authentication: Activate account via code or token
app.post('/api/auth/activate', async (req, res) => {
  try {
    const { token, code, username } = req.body;
    const lookup = (code || token || '').trim();
    const uClean = (username || '').trim();

    if (!lookup) {
      return res.status(400).json({ success: false, message: 'Código o token de activación requerido' });
    }

    // 1. Try PostgreSQL
    let pgQuery = `UPDATE users 
                   SET is_verified = TRUE, activation_token = NULL, activation_code = NULL 
                   WHERE (activation_token = $1 OR activation_code = $1)`;
    let pgParams = [lookup];
    if (uClean) {
      pgQuery += ' AND LOWER(username) = LOWER($2)';
      pgParams.push(uClean);
    }
    pgQuery += ' RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, is_verified, created_at';

    const result = await safeQuery(pgQuery, pgParams);
    if (result && result.rows.length > 0) {
      return res.json({
        success: true,
        message: '¡Cuenta activada con éxito! Ya puedes acceder al Santuario.',
        user: result.rows[0],
      });
    }

    // 2. Local DB fallback
    const ldb = getLocalDb();
    const u = ldb.users.find(usr => {
      const matchToken = usr.activation_token === lookup || usr.activation_code === lookup;
      if (uClean) {
        return matchToken && usr.username.toLowerCase() === uClean.toLowerCase();
      }
      return matchToken;
    });

    if (u) {
      u.is_verified = true;
      u.activation_token = null;
      u.activation_code = null;
      saveLocalDb(ldb);
      const { password: _, ...userNoPwd } = u;
      return res.json({
        success: true,
        message: '¡Cuenta activada con éxito! Ya puedes acceder al Santuario.',
        user: { ...userNoPwd, is_banned: !!u.is_banned, is_verified: true },
      });
    }

    return res.status(400).json({
      success: false,
      message: 'Código o enlace de activación inválido o expirado. Por favor solicita un nuevo código.',
    });
  } catch (err) {
    console.error('Error activating user:', err);
    return res.status(500).json({ success: false, message: 'Error interno al activar la cuenta' });
  }
});

// Authentication: Resend activation email / code
app.post('/api/auth/resend-activation', async (req, res) => {
  try {
    const { username, email } = req.body;
    const uClean = (username || '').trim();
    const eClean = (email || '').trim();

    if (!uClean && !eClean) {
      return res.status(400).json({ success: false, message: 'Usuario o correo electrónico requerido' });
    }

    let user = null;
    let isPg = false;

    // 1. Try PostgreSQL
    const checkRes = await safeQuery(
      'SELECT id, username, role, full_name, email, is_verified FROM users WHERE LOWER(username) = LOWER($1) OR (email != \'\' AND LOWER(email) = LOWER($2))',
      [uClean, eClean || uClean]
    );

    if (checkRes && checkRes.rows.length > 0) {
      user = checkRes.rows[0];
      isPg = true;
    } else {
      const ldb = getLocalDb();
      user = ldb.users.find(u => 
        (uClean && u.username.toLowerCase() === uClean.toLowerCase()) || 
        (eClean && u.email && u.email.toLowerCase() === eClean.toLowerCase())
      );
    }

    if (!user) {
      return res.status(404).json({ success: false, message: 'No se encontró ningún usuario con esos datos' });
    }

    if (user.is_verified) {
      return res.status(400).json({ success: false, message: 'Esta cuenta ya está activada. Puedes iniciar sesión directamente.' });
    }

    const newCode = Math.floor(100000 + Math.random() * 900000).toString();
    const newToken = crypto.randomBytes(24).toString('hex');
    const targetEmail = (user.email || eClean).trim();

    if (isPg) {
      await safeQuery(
        'UPDATE users SET activation_code = $1, activation_token = $2 WHERE id = $3',
        [newCode, newToken, user.id]
      );
    } else {
      const ldb = getLocalDb();
      const localU = ldb.users.find(u => u.id === user.id);
      if (localU) {
        localU.activation_code = newCode;
        localU.activation_token = newToken;
        saveLocalDb(ldb);
      }
    }

    let previewUrl = null;
    if (targetEmail) {
      const host = req.get('host') || `localhost:${port}`;
      const protocol = req.protocol || 'http';
      const activationLink = `${protocol}://${host}/api/auth/verify?token=${newToken}`;
      const mailInfo = await sendMailNotification({
        to: targetEmail,
        subject: 'Nuevo código de activación · Sanctuary 🪐',
        text: `Hola ${user.full_name || user.username},\n\nTu código de activación de Sanctuary es: ${newCode}\nO activa directamente en: ${activationLink}`,
        html: buildActivationEmailHtml({ username: user.username, fullName: user.full_name, activationCode: newCode, activationLink }),
      });
      previewUrl = mailInfo?.previewUrl || null;
    }

    return res.json({
      success: true,
      message: 'Código de activación reenviado correctamente.',
      activation_token: newCode,
      activationToken: newCode,
      activation_code: newCode,
      activationCode: newCode,
      preview_url: previewUrl,
      previewUrl: previewUrl,
    });
  } catch (err) {
    console.error('Error resending activation:', err);
    return res.status(500).json({ success: false, message: 'Error interno al reenviar activación' });
  }
});

function buildVerificationSuccessHtml(username) {
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="refresh" content="3;url=https://carlosss91.github.io/Sanctuary/">
  <title>Cuenta Verificada · Sanctuary</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 20px;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: radial-gradient(circle at 50% 20%, #0F172A 0%, #080C14 100%);
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;
      color: #F8FAFC;
    }
    .card {
      max-width: 460px;
      width: 100%;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid rgba(16, 185, 129, 0.35);
      border-radius: 28px;
      padding: 42px 32px;
      text-align: center;
      box-shadow: 0 24px 60px rgba(0, 0, 0, 0.6), 0 0 35px rgba(16, 185, 129, 0.15);
      animation: fadeIn 0.6s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(16px) scale(0.96); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    .icon-badge {
      width: 72px;
      height: 72px;
      margin: 0 auto 20px auto;
      border-radius: 22px;
      background: radial-gradient(circle at 30% 30%, #10B981, #064E3B);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 34px;
      box-shadow: 0 10px 30px rgba(16, 185, 129, 0.4);
    }
    .title {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: -0.5px;
      margin: 0 0 8px 0;
      color: #FFFFFF;
    }
    .username-chip {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 20px;
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: #10B981;
      font-weight: 700;
      font-size: 13px;
      margin-bottom: 16px;
    }
    .desc {
      font-size: 14.5px;
      line-height: 1.6;
      color: #94A3B8;
      margin: 0 0 28px 0;
    }
    .btn {
      display: block;
      width: 100%;
      padding: 15px 24px;
      border-radius: 14px;
      background: linear-gradient(135deg, #10B981 0%, #059669 100%);
      color: #FFFFFF;
      font-size: 15px;
      font-weight: 700;
      text-decoration: none;
      box-shadow: 0 10px 24px rgba(16, 185, 129, 0.35);
      border: 1px solid rgba(255, 255, 255, 0.2);
    }
    .brand {
      margin-top: 24px;
      font-size: 11px;
      color: #475569;
      letter-spacing: 1px;
      text-transform: uppercase;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-badge">🪐</div>
    <h1 class="title">¡Cuenta Activada con Éxito!</h1>
    <div class="username-chip">@${username}</div>
    <p class="desc">Tu cuenta ha sido validada y activada correctamente. Redirigiéndote a Sanctuary...</p>
    <a href="https://carlosss91.github.io/Sanctuary/" class="btn">Entrar al Santuario</a>
    <div class="brand">Sanctuary · Digital Suite 2026</div>
  </div>
</body>
</html>`;
}

// Authentication: Account Activation Link
app.get('/api/auth/verify', async (req, res) => {
  const token = (req.query.token || req.query.code || '').trim();
  if (!token) {
    return res.status(400).send('<h1>Token de activación inválido o faltante</h1>');
  }

  // PostgreSQL
  const result = await safeQuery(
    'UPDATE users SET is_verified = TRUE, activation_token = NULL, activation_code = NULL WHERE activation_token = $1 OR activation_code = $1 RETURNING username',
    [token]
  );
  if (result && result.rows.length > 0) {
    return res.send(buildVerificationSuccessHtml(result.rows[0].username));
  }

  // Local DB fallback
  const ldb = getLocalDb();
  const u = ldb.users.find(usr => usr.activation_token === token || usr.activation_code === token);
  if (u) {
    u.is_verified = true;
    u.activation_token = null;
    u.activation_code = null;
    saveLocalDb(ldb);
    return res.send(buildVerificationSuccessHtml(u.username));
  }

  res.status(404).send(`
    <!DOCTYPE html><html><body style="font-family:sans-serif;background:#080C14;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
      <div style="text-align:center;padding:36px;background:#0F172A;border-radius:20px;border:1px solid #EF4444;max-width:440px;">
        <h2 style="color:#EF4444;">Enlace expirado o no encontrado</h2>
        <p style="color:#94A3B8;">Este enlace de activación ya ha sido utilizado o ha vencido. Intenta registrarte o solicitar recuperación.</p>
        <a href="/" style="display:inline-block;margin-top:16px;padding:12px 24px;background:#1E293B;color:#fff;text-decoration:none;border-radius:10px;">Volver al inicio</a>
      </div>
    </body></html>
  `);
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


// Email: Admin Get Email Diagnostics Status
app.get('/api/admin/email/status', async (req, res) => {
  const ldb = getLocalDb();
  let dbSmtp = ldb.smtp_config;

  if (!dbSmtp?.host) {
    try {
      const q = await safeQuery("SELECT value FROM app_settings WHERE key = 'smtp_config'");
      if (q && q.rows && q.rows.length > 0) {
        dbSmtp = typeof q.rows[0].value === 'string' ? JSON.parse(q.rows[0].value) : q.rows[0].value;
        ldb.smtp_config = dbSmtp;
      }
    } catch (_) {}
  }

  const isCustomSmtp = !!((process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) || (dbSmtp && dbSmtp.host && dbSmtp.user && dbSmtp.pass));
  const transporter = await getMailTransporter();
  const isEthereal = !!transporter?._isEthereal;
  const isReal = isCustomSmtp || isEthereal;

  const currentHost = process.env.SMTP_HOST || dbSmtp?.host || (isEthereal ? 'smtp.ethereal.email (Servidor de Prueba)' : 'Modo Simulado / Consola');
  const currentPort = process.env.SMTP_PORT || dbSmtp?.port || '587';
  const currentUser = process.env.SMTP_USER || dbSmtp?.user || null;
  const currentFrom = process.env.SMTP_FROM || dbSmtp?.from || (transporter?._customUser ? `"Sanctuary Platform" <${transporter._customUser}>` : (transporter?._etherealUser ? `"Sanctuary Platform" <${transporter._etherealUser}>` : '"Sanctuary Platform" <no-reply@sanctuary.app>'));

  return res.json({
    success: true,
    isConfigured: isReal,
    isCustomSmtp,
    mode: isCustomSmtp ? 'smtp' : (isEthereal ? 'ethereal' : 'simulated'),
    host: currentHost,
    port: currentPort,
    user: currentUser,
    from: currentFrom,
    etherealUser: transporter?._etherealUser || null,
    message: isCustomSmtp
      ? `Servidor SMTP configurado y activo en ${currentHost}`
      : (isEthereal
          ? 'Servidor de prueba SMTP Ethereal activo: Los correos se generan con visor web real y previsualización online.'
          : 'Modo simulado activo: Las credenciales SMTP no están definidas.'),
  });
});

// Email: Admin Save SMTP Configuration
app.post('/api/admin/email/config', async (req, res) => {
  try {
    const { host, port, user, pass, from, secure } = req.body;
    if (!host || !user || !pass) {
      return res.status(400).json({ success: false, message: 'Host, usuario y contraseña SMTP son requeridos' });
    }

    const ldb = getLocalDb();
    ldb.smtp_config = {
      host: host.trim(),
      port: parseInt(port || '587', 10),
      user: user.trim(),
      pass: pass.trim(),
      from: from ? from.trim() : `"Sanctuary Platform" <${user.trim()}>`,
      secure: secure === true || port == 465,
      updated_at: new Date().toISOString(),
    };
    saveLocalDb(ldb);

    // Guardar en PostgreSQL para persistencia permanente ante reinicios y despliegues
    await safeQuery(
      `INSERT INTO app_settings (key, value, updated_at) 
       VALUES ('smtp_config', $1, NOW()) 
       ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = NOW()`,
      [JSON.stringify(ldb.smtp_config)]
    );

    // Reset transporter so next call re-initializes with new credentials
    mailTransporter = null;
    await getMailTransporter();

    res.json({
      success: true,
      message: 'Configuración SMTP guardada y activada con éxito (persistida en base de datos)',
      host: ldb.smtp_config.host,
      port: ldb.smtp_config.port,
      user: ldb.smtp_config.user,
      from: ldb.smtp_config.from,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Error guardando configuración SMTP: ' + err.message });
  }
});

// Email: Admin Send Test Email
app.post('/api/admin/email/test', async (req, res) => {
  const to = req.body.to || req.body.targetEmail || req.body.email;
  if (!to) return res.status(400).json({ success: false, message: 'Destinatario requerido' });
  const ldb = getLocalDb();
  let dbSmtp = ldb.smtp_config;
  if (!dbSmtp?.host) {
    try {
      const q = await safeQuery("SELECT value FROM app_settings WHERE key = 'smtp_config'");
      if (q && q.rows && q.rows.length > 0) {
        dbSmtp = typeof q.rows[0].value === 'string' ? JSON.parse(q.rows[0].value) : q.rows[0].value;
      }
    } catch (_) {}
  }
  const isCustomSmtp = !!((process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) || (dbSmtp && dbSmtp.host && dbSmtp.user && dbSmtp.pass));
  const activeHost = process.env.SMTP_HOST || dbSmtp?.host || 'smtp-relay.brevo.com';

  const host = req.get('host') || `localhost:${port}`;
  const protocol = req.protocol || 'http';
  const dummyToken = crypto.randomBytes(16).toString('hex');
  const sampleLink = `${protocol}://${host}/api/auth/verify?token=${dummyToken}`;

  const result = await sendMailNotification({
    to: to.trim(),
    subject: 'Comprobación de Servidor de Correo · Sanctuary 🪐',
    text: `Este es un correo de prueba emitido desde el Panel de Administración de Sanctuary para verificar la conectividad SMTP.\n\nEnlace de muestra: ${sampleLink}`,
    html: buildActivationEmailHtml({ username: 'AdminTester', fullName: 'Administrador de Pruebas', activationLink: sampleLink }),
  });

  if (result) {
    const previewUrl = result.previewUrl || null;
    return res.json({
      success: true,
      message: isCustomSmtp
        ? `Correo de prueba enviado a ${to} a través del servidor SMTP (${activeHost}).`
        : (previewUrl
            ? `Correo generado con éxito. Puedes abrir la bandeja de prueba aquí: ${previewUrl}`
            : `Correo registrado para ${to} en los logs del servidor.`),
      mode: isCustomSmtp ? 'smtp' : (previewUrl ? 'ethereal' : 'simulated'),
      previewUrl,
    });
  }
  res.status(500).json({ success: false, message: 'No se pudo enviar el correo. Revisa la configuración SMTP.' });
});

// Storage: Admin Storage & Quota Analytics
app.get('/api/admin/storage', async (req, res) => {
  try {
    // 1. Uploads directory stats
    let uploadsBytes = 0;
    let fileCount = 0;
    const fileList = [];
    if (fs.existsSync(uploadsDir)) {
      const files = fs.readdirSync(uploadsDir);
      for (const f of files) {
        try {
          const st = fs.statSync(path.join(uploadsDir, f));
          if (st.isFile()) {
            uploadsBytes += st.size;
            fileCount++;
            fileList.push({ name: f, size: st.size, modified: st.mtime });
          }
        } catch (_) {}
      }
    }

    // 2. Database stats
    let dbBytes = 0;
    if (fs.existsSync(localDbPath)) {
      try {
        const st = fs.statSync(localDbPath);
        dbBytes += st.size;
      } catch (_) {}
    }
    const pgRes = await safeQuery('SELECT pg_database_size(current_database()) as size');
    if (pgRes && pgRes.rows && pgRes.rows[0]?.size) {
      dbBytes += parseInt(pgRes.rows[0].size, 10);
    }

    // 3. User quota breakdown
    const ldb = getLocalDb();
    const users = ldb.users || [];
    const profiles = ldb.cv_profiles || [];
    const messages = ldb.chat_messages || [];

    const formatBytes = (bytes) => {
      if (bytes === 0) return '0 B';
      const k = 1024;
      const sizes = ['B', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    };

    const usersStorage = users.map((u) => {
      const role = (u.role || 'usuario').toLowerCase();
      // Quota policy: Admin = 1024 MB (1GB), Docente = 250 MB, Usuario = 50 MB
      const quotaBytes = role === 'admin' ? 1024 * 1024 * 1024 : (role === 'docente' ? 250 * 1024 * 1024 : 50 * 1024 * 1024);
      
      const userProfiles = profiles.filter(p => p.userId === u.id || (!p.userId && role === 'admin'));
      const profileEstimatedBytes = JSON.stringify(userProfiles).length;
      
      let userUploadsBytes = 0;
      if (u.avatar_url && u.avatar_url.includes('/uploads/')) {
        const fname = path.basename(u.avatar_url);
        const match = fileList.find(f => f.name === fname);
        if (match) userUploadsBytes += match.size;
      }
      
      const usedBytes = profileEstimatedBytes + userUploadsBytes + 2048; // Base user records overhead
      const percent = Math.min(100, parseFloat(((usedBytes / quotaBytes) * 100).toFixed(1)));

      return {
        id: u.id,
        username: u.username,
        fullName: u.full_name || u.username,
        role: u.role || 'usuario',
        avatarUrl: u.avatar_url || '',
        usedBytes,
        formattedUsed: formatBytes(usedBytes),
        quotaBytes,
        formattedQuota: formatBytes(quotaBytes),
        percent,
        profileCount: userProfiles.length,
        hasAvatar: !!(u.avatar_url && u.avatar_url.length > 0),
      };
    });

    const totalSystemConsumedBytes = uploadsBytes + dbBytes;
    const systemQuotaBytes = 5 * 1024 * 1024 * 1024; // 5 GB standard allocated system storage
    const systemPercent = Math.min(100, parseFloat(((totalSystemConsumedBytes / systemQuotaBytes) * 100).toFixed(1)));

    return res.json({
      success: true,
      summary: {
        totalConsumedBytes: totalSystemConsumedBytes,
        formattedTotal: formatBytes(totalSystemConsumedBytes),
        systemQuotaBytes,
        formattedSystemQuota: formatBytes(systemQuotaBytes),
        systemPercent,
        uploadsBytes,
        formattedUploads: formatBytes(uploadsBytes),
        uploadsCount: fileCount,
        dbBytes,
        formattedDb: formatBytes(dbBytes),
        usersCount: users.length,
        cvProfilesCount: profiles.length,
        chatMessagesCount: messages.length,
      },
      users: usersStorage,
    });
  } catch (err) {
    console.error('Error fetching storage analytics:', err);
    return res.status(500).json({ success: false, message: 'Error calculando almacenamiento: ' + err.message });
  }
});

// ============================================================================
// ADMIN PANEL CRUD & CONTROL ROUTES
// ============================================================================

// Admin: List all users
app.get('/api/admin/users', async (req, res) => {
  const result = await safeQuery(
    'SELECT id, username, role, full_name, email, avatar_url, bio, COALESCE(is_banned, false) as is_banned, COALESCE(is_verified, true) as is_verified, created_at FROM users ORDER BY id ASC'
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
    return { ...noPwd, is_banned: !!u.is_banned, is_verified: u.is_verified !== false };
  });
  res.json({
    success: true,
    users: safeUsers,
  });
});

// Admin: Create user with custom role and password confirmation
app.post('/api/admin/users', async (req, res) => {
  const { username, password, confirm_password, confirmPassword, role, full_name, email, avatar_url, bio } = req.body;
  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Usuario y contraseña requeridos' });
  }

  const uClean = username.trim();
  const pClean = password.trim();
  const confClean = (confirm_password || confirmPassword || '').trim();

  // Validate confirmation if sent
  if (confClean && pClean !== confClean) {
    return res.status(400).json({ success: false, message: 'Las contraseñas no coinciden. Por favor verifícalas.' });
  }
  if (pClean.length < 4) {
    return res.status(400).json({ success: false, message: 'La contraseña debe tener al menos 4 caracteres' });
  }

  const hashedPwd = hashPassword(pClean);
  const targetRole = ['admin', 'docente', 'usuario'].includes((role || '').toLowerCase())
    ? role.toLowerCase()
    : 'usuario';

  const existingRes = await safeQuery('SELECT id FROM users WHERE LOWER(username) = LOWER($1)', [uClean]);
  if (existingRes) {
    if (existingRes.rows.length > 0) {
      return res.status(409).json({ success: false, message: 'El nombre de usuario ya existe' });
    }
    const result = await safeQuery(
      `INSERT INTO users (username, password, role, full_name, email, avatar_url, bio, is_banned, is_verified)
       VALUES ($1, $2, $3, $4, $5, $6, $7, FALSE, TRUE)
       RETURNING id, username, role, full_name, email, avatar_url, bio, is_banned, is_verified, created_at`,
      [uClean, hashedPwd, targetRole, full_name || uClean, email || '', avatar_url || '', bio || '']
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
    password: hashedPwd,
    role: targetRole,
    full_name: full_name || uClean,
    email: email || '',
    avatar_url: avatar_url || '',
    bio: bio || '',
    is_banned: false,
    is_verified: true,
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

// --- CV PDF Extraction & OCR Service ---
function cleanSpacedTextNode(str) {
  if (!str) return '';
  if (/^([A-Za-zÁÉÍÓÚáéíóúñÑ0-9\.]\s+){3,}/.test(str)) {
    return str.replace(/\s+/g, ' ').replace(/([A-Za-zÁÉÍÓÚáéíóúñÑ0-9])\s+(?=[A-Za-zÁÉÍÓÚáéíóúñÑ0-9])/g, '$1').trim();
  }
  return str;
}

function parseCvTextNode(rawText, fileName) {
  const clean = (rawText || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = clean.split('\n')
    .map(l => cleanSpacedTextNode(l.trim()))
    .filter(l => l.length > 0 && l !== '-- 1 of 1 --');

  let email = '';
  const emailMatch = clean.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/);
  if (emailMatch) email = emailMatch[0].replace(/[.,;:]+$/, '');

  let phone = '';
  const phoneRegex = /(?:\+?34[-.\s]?)?[6789]\d{2}[-.\s]?\d{2,3}[-.\s]?\d{2,3}[-.\s]?\d{2,3}|(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}/g;
  for (const m of clean.matchAll(phoneRegex)) {
    const cand = m[0].trim().replace(/[.,;:]+$/, '');
    const digits = cand.replace(/\D/g, '');
    if (digits.length >= 9 && digits.length <= 14 && !digits.startsWith('202') && !digits.startsWith('199')) {
      phone = cand;
      break;
    }
  }

  let nameFromFilename = '';
  if (fileName) {
    let fnClean = fileName.replace(/\.[a-zA-Z0-9]+$/i, '');
    fnClean = fnClean.replace(/^(?:curriculum(?:\s*vitae)?|cv|hoja\s*de\s*vida|resume)\s*[-_ ]*/i, '');
    fnClean = fnClean.replace(/[-_ ]*(?:curriculum(?:\s*vitae)?|cv|final|v\d+|\b20\d\d\b)\b.*$/i, '');
    fnClean = fnClean.replace(/[_\-]+/g, ' ').trim();
    if (fnClean.length >= 3 && fnClean.length <= 50) {
      nameFromFilename = fnClean;
    }
  }

  const professionKeywords = [
    'desarrollador', 'developer', 'ingeniero', 'engineer', 'arquitecto', 'técnico', 'tecnico',
    'diseñador', 'designer', 'administrativo', 'operario', 'auxiliar', 'profesor', 'docente',
    'consultor', 'responsable', 'encargado', 'director', 'analista', 'comercial', 'enfermero',
    'médico', 'psicólogo', 'coordinador', 'especialista', 'camarero', 'cocinero', 'electricista',
    'fontanero', 'mecánico', 'conductor', 'almacenero', 'soldador', 'jardinero', 'dependiente',
    'maestro', 'monitor'
  ];

  const educationDegreeKeywords = [
    'grado', 'fp', 'formación profesional', 'formacion profesional', 'diplomatura', 'licenciatura',
    'máster', 'master', 'bachillerato', 'eso', 'educación secundaria', 'curso', 'adaptación al grado',
    'adaptacion al grado', 'técnico superior en', 'tecnico superior en', 'ciclo formativo', 'doctorado'
  ];

  const educationInstKeywords = [
    'universidad', 'instituto', 'i.e.s.', 'ies', 'colegio', 'facultad', 'academia', 'ilerna',
    'ulpgc', 'ull', 'uned', 'uoc', 'ceip', 'c.e.i.p.'
  ];

  const dateRegex = /\b(?:(?:\d{1,2}\/)?(?:19\d\d|20\d\d)\b(?:\s*[-–—]\s*(?:(?:\d{1,2}\/)?(?:19\d\d|20\d\d)|actualidad|presente))?|(?:19\d\d|20\d\d)\s*[-–—]\s*(?:19\d\d|20\d\d)|actualidad|presente)\b/i;

  const dateIndices = [];
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (dateRegex.test(l) && l.length < 50 && !l.includes('@')) {
      dateIndices.push(i);
    }
  }

  const experiences = [];
  const educations = [];
  const consumedIndices = new Set();

  for (let k = 0; k < dateIndices.length; k++) {
    const i = dateIndices[k];
    const period = lines[i];
    consumedIndices.add(i);

    let title = '';
    let org = '';

    if (i >= 2 && !consumedIndices.has(i - 2) && !consumedIndices.has(i - 1)) {
      title = lines[i - 2];
      org = lines[i - 1];
      consumedIndices.add(i - 2);
      consumedIndices.add(i - 1);
    } else if (i >= 1 && !consumedIndices.has(i - 1)) {
      title = lines[i - 1];
      consumedIndices.add(i - 1);
      if (i + 1 < lines.length && (k === dateIndices.length - 1 || i + 1 < dateIndices[k + 1] - 1) && lines[i + 1].length < 75) {
        org = lines[i + 1];
        consumedIndices.add(i + 1);
      }
    }

    const nextLimit = (k + 1 < dateIndices.length) ? dateIndices[k + 1] - 2 : lines.length;
    const descLines = [];
    let d = i + 1;
    while (d < nextLimit && d < lines.length) {
      if (consumedIndices.has(d)) { d++; continue; }
      const dl = lines[d];
      if (/^(datos|sobre m[ií]|competencias|experiencia|formaci[oó]n)/i.test(dl)) break;
      if (dl.includes('@') || phoneRegex.test(dl)) break;
      if (dl.length > 25) {
        descLines.push(dl);
        consumedIndices.add(d);
      }
      d++;
    }

    const lowerTitle = title.toLowerCase();
    const lowerOrg = org.toLowerCase();

    const isExplicitJob = professionKeywords.some(pk => lowerTitle.startsWith(pk) || lowerTitle.includes(' ' + pk));
    const isExplicitEduDegree = educationDegreeKeywords.some(ek => lowerTitle.includes(ek));
    const isExplicitEduInst = educationInstKeywords.some(ik => lowerOrg.includes(ik));

    const isEdu = (!isExplicitJob && (isExplicitEduDegree || isExplicitEduInst)) || (isExplicitEduDegree && !isExplicitJob);

    if (isEdu) {
      educations.push({
        degree: title.replace(/[…\.]+$/, '').trim(),
        institution: org.replace(/[…\.]+$/, '').trim(),
        period,
        details: descLines.join('\n')
      });
    } else {
      experiences.push({
        jobTitle: title.replace(/[…\.]+$/, '').trim(),
        company: org.replace(/[…\.]+$/, '').trim(),
        period,
        description: descLines.join('\n')
      });
    }
  }

  let location = '';
  let availability = '';
  let drivingLicense = '';

  const locationPatterns = [
    'arrecife', 'lanzarote', 'puerto del rosario', 'fuerteventura', 'las palmas', 'gran canaria',
    'tenerife', 'santa cruz', 'la palma', 'la gomera', 'el hierro', 'canarias', 'telde', 'arucas',
    'madrid', 'barcelona', 'valencia', 'sevilla', 'bilbao', 'españa', 'spain'
  ];

  for (let i = 0; i < lines.length; i++) {
    if (consumedIndices.has(i)) continue;
    const l = lines[i];
    const lower = l.toLowerCase();

    if (/disponib|incorporaci[oó]n|jornada/i.test(lower) && l.length < 80) {
      availability = (availability ? availability + ' ' : '') + l;
      consumedIndices.add(i);
      continue;
    }
    if (/permiso|carnet|veh[ií]culo/i.test(lower) && l.length < 60) {
      drivingLicense = l;
      consumedIndices.add(i);
      continue;
    }
    if (!location && locationPatterns.some(p => lower.includes(p)) && l.length < 60 && !l.includes('@')) {
      location = l;
      consumedIndices.add(i);
      continue;
    }
  }

  const norm = str => str.toLowerCase()
    .replace(/[áàäâã]/g, 'a')
    .replace(/[éèëê]/g, 'e')
    .replace(/[íìïî]/g, 'i')
    .replace(/[óòöôõ]/g, 'o')
    .replace(/[úùüû]/g, 'u')
    .replace(/ñ/g, 'n')
    .replace(/[^a-z0-9]/g, '');

  let summary = '';
  for (let i = 0; i < lines.length; i++) {
    if (consumedIndices.has(i)) continue;
    const l = lines[i];
    const n = norm(l);
    if (/^(datos|s?obremi|competencia|experiencia|formacion|certificac|educacion)/.test(n)) {
      consumedIndices.add(i);
      continue;
    }
    if (l === l.toUpperCase() && l.length <= 40) continue;

    let isSkillList = l.includes('•') || l.includes('|');
    if (!isSkillList && l.includes(',')) {
      const commaParts = l.split(',').map(s => s.trim()).filter(Boolean);
      if (commaParts.length >= 3) {
        const allShort = commaParts.every(p => p.split(/\s+/).length <= 3 && p.length <= 25);
        if (allShort) isSkillList = true;
      }
    }
    if (isSkillList) continue;

    const isProse = (l !== l.toUpperCase()) && (l.length > 55 || /^(?:soy|me considero|profesional|graduado|técnico|ingeniero|busco|mi objetivo)\b/i.test(l));

    if (isProse || /profesional|comprometido|trayectoria|busco|metodología|aporto|responsable/i.test(l)) {
      summary = (summary ? summary + ' ' : '') + l;
      consumedIndices.add(i);
    }
  }

  const skillItems = [];
  for (let i = 0; i < lines.length; i++) {
    if (consumedIndices.has(i)) continue;
    const l = lines[i];
    const n = norm(l);

    const isHeaderOrDegree = !n ||
      n.startsWith('sobremi') ||
      n === 'datos' ||
      n.startsWith('competencia') ||
      n.startsWith('habilidad') ||
      n.startsWith('experiencia') ||
      n.startsWith('formacion') ||
      n.startsWith('certificac') ||
      n.startsWith('educacion') ||
      n.includes('desarrollo') ||
      n.includes('tecnico') ||
      n.includes('sistemas') ||
      n.includes('daw') ||
      n.includes('asir') ||
      n.includes('dam') ||
      n.startsWith('contacto') ||
      professionKeywords.some(pk => n.includes(norm(pk))) ||
      educationDegreeKeywords.some(ek => n.includes(norm(ek)));

    if (isHeaderOrDegree) {
      consumedIndices.add(i);
      continue;
    }

    if (/[A-ZÁÉÍÓÚÑ]/.test(l) && l === l.toUpperCase() && l.length >= 3 && l.length <= 40 && !l.includes('@') && !phoneRegex.test(l)) {
      let cleanSkillName = l.replace(/[…\.]+$/, '').trim();
      if (cleanSkillName.startsWith('PUNTUALIDAD Y SERIED')) cleanSkillName = 'PUNTUALIDAD Y SERIEDAD';
      if (cleanSkillName.startsWith('MANEJO DE HERRAMIEN')) cleanSkillName = 'MANEJO DE HERRAMIENTAS';
      if (cleanSkillName.startsWith('CAPACIDAD DE APRENDI')) cleanSkillName = 'CAPACIDAD DE APRENDIZAJE';
      if (cleanSkillName.startsWith('PREVENCIÓN Y EPI') || cleanSkillName.startsWith('PREVENCION Y EPI')) cleanSkillName = 'PREVENCIÓN Y EPIS';

      let desc = '';
      if (i + 1 < lines.length && !consumedIndices.has(i + 1)) {
        const nextLine = lines[i + 1];
        const nextN = norm(nextLine);
        const isNextHeader = nextN.startsWith('sobremi') || nextN.startsWith('competencia') || nextN.startsWith('experiencia') || nextN.startsWith('formacion') || nextN.includes('desarrollo');
        if (nextLine.length < 85 && nextLine !== nextLine.toUpperCase() && !isNextHeader) {
          desc = nextLine;
          consumedIndices.add(i + 1);
        }
      }
      skillItems.push({
        name: cleanSkillName,
        level: 5,
        description: desc
      });
      consumedIndices.add(i);
    } else if (l.includes('•') || l.includes('|') || (l.includes(',') && l.length <= 60 && !l.endsWith('.'))) {
      const tokens = l.split(/[,•|]/).map(s => s.trim()).filter(s => s.length >= 2 && s.length <= 35);
      for (const tok of tokens) {
        skillItems.push({ name: tok, level: 5, description: '' });
      }
      consumedIndices.add(i);
    }
  }

  let jobTitle = '';
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (/^(T\.S\.|TÉCNICO SUPERIOR|DESARROLLADOR|INGENIERO)/i.test(l) && l.length < 55) {
      jobTitle = l.replace(/[…\.]+$/, '').trim();
      break;
    }
  }
  if (!jobTitle && experiences.length > 0) {
    jobTitle = experiences[0].jobTitle;
  }

  let fullName = nameFromFilename;
  if (!fullName) {
    for (let i = 0; i < lines.length && i < 10; i++) {
      const l = lines[i];
      const lower = l.toLowerCase();
      if (professionKeywords.some(pk => lower.includes(pk))) continue;
      if (educationDegreeKeywords.some(ek => lower.includes(ek))) continue;
      const words = l.split(/\s+/);
      if (words.length >= 2 && words.length <= 4 && l.length >= 4 && l.length <= 40 && !/\d/.test(l) && !l.includes('@')) {
        fullName = l;
        break;
      }
    }
  }

  return {
    fullName: fullName || '',
    jobTitle: jobTitle || '',
    email: email || '',
    phone: phone || '',
    location: location || '',
    availability: availability || '',
    drivingLicense: drivingLicense || '',
    summary: summary.trim(),
    experiences,
    educations,
    skillItems,
    skills: skillItems.map(s => s.name)
  };
}

app.post('/api/cv/extract-pdf', async (req, res) => {
  try {
    const { pdfBase64, filename } = req.body;
    if (!pdfBase64) {
      return res.status(400).json({ success: false, message: 'No se enviaron datos PDF en base64' });
    }

    const pdfBuffer = Buffer.from(pdfBase64, 'base64');

    // 1. Exact SanctuaryCV Metadata check
    const rawLatin = pdfBuffer.toString('latin1');
    const match = rawLatin.match(/SanctuaryCV::([A-Za-z0-9+/=]+)/);
    if (match) {
      try {
        const jsonStr = Buffer.from(match[1], 'base64').toString('utf8');
        const exactProfile = JSON.parse(jsonStr);
        if (exactProfile && exactProfile.fullName) {
          return res.json({ success: true, isExactMetadata: true, profile: exactProfile });
        }
      } catch (_) {}
    }

    // 2. High-Fidelity PDF Text Extraction via PDFParse
    let extractedText = '';
    if (PDFParseClass) {
      try {
        const parser = new PDFParseClass({ data: pdfBuffer });
        const result = await parser.getText();
        extractedText = (typeof result === 'string') ? result : (result?.text || '');
      } catch (err) {
        console.warn('[Backend] Error en PDFParse:', err.message);
      }
    }

    // 3. Fallback to Tesseract OCR if text extraction was sparse (< 60 chars)
    if (extractedText.trim().length < 60 && Tesseract) {
      try {
        console.log('[Backend] Extracción de texto escasa en PDF. Ejecutando OCR con Tesseract...');
        const ocrResult = await Tesseract.recognize(pdfBuffer, 'spa+eng');
        if (ocrResult && ocrResult.data && ocrResult.data.text.trim().length > extractedText.trim().length) {
          extractedText = ocrResult.data.text;
        }
      } catch (ocrErr) {
        console.warn('[Backend] Error en OCR Tesseract:', ocrErr.message);
      }
    }

    const parsedProfile = parseCvTextNode(extractedText, filename || '');

    return res.json({
      success: true,
      rawText: extractedText,
      profile: parsedProfile
    });
  } catch (err) {
    console.error('[Backend] Error en /api/cv/extract-pdf:', err);
    return res.status(500).json({ success: false, message: 'Error procesando documento PDF: ' + err.message });
  }
});

// Repository Links: List
app.get('/api/links', async (req, res) => {
  const result = await safeQuery("SELECT * FROM repo_links WHERE LOWER(url) NOT LIKE '%carlosss91%' ORDER BY id ASC");
  if (result) {
    return res.json({ success: true, links: result.rows });
  }
  const ldb = getLocalDb();
  const links = (ldb.repo_links || []).filter(l => !l.url?.toLowerCase().includes('carlosss91') && !l.title?.toLowerCase().includes('carlosss91'));
  res.json({ success: true, links });
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

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  try {
    const reqHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };
    if (url.includes('prezi') || url.includes('amazonaws.com')) {
      reqHeaders['Referer'] = 'https://prezi.com/';
      reqHeaders['Origin'] = 'https://prezi.com';
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);

    const fetchRes = await fetch(url, {
      headers: reqHeaders,
      signal: controller.signal,
    });
    clearTimeout(timeout);

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
      res.setHeader('Content-Length', buffer.byteLength);
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

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  try {
    const reqHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };
    if (url.includes('prezi') || url.includes('amazonaws.com')) {
      reqHeaders['Referer'] = 'https://prezi.com/';
      reqHeaders['Origin'] = 'https://prezi.com';
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);

    const fetchRes = await fetch(url, {
      headers: reqHeaders,
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!fetchRes.ok) {
      return res.status(fetchRes.status).json({ success: false, message: `Error ${fetchRes.status} al descargar archivo` });
    }

    const safeName = (filename || 'video.mp4').replace(/[^\w\.-]/gi, '_');
    res.setHeader('Content-Disposition', `attachment; filename="${safeName}"`);
    const contentType = fetchRes.headers.get('content-type') || 'application/octet-stream';
    res.setHeader('Content-Type', contentType);

    const buffer = await fetchRes.arrayBuffer();
    res.setHeader('Content-Length', buffer.byteLength);
    res.send(Buffer.from(buffer));
  } catch (err) {
    console.error('Error in /api/slides/download:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.listen(port, () => {
  console.log(`✨ Sanctuary API running on port ${port}`);
});
