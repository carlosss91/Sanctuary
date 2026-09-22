-- Sanctuary Database Schema
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Default admin user: admin / admin
INSERT INTO users (username, password, role)
VALUES ('admin', 'admin', 'admin')
ON CONFLICT (username) DO NOTHING;

CREATE TABLE IF NOT EXISTS cv_profiles (
    id VARCHAR(100) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    job_title VARCHAR(150),
    avatar_url TEXT,
    data_json JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS repo_links (
    id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    url TEXT NOT NULL,
    description TEXT,
    category VARCHAR(50) DEFAULT 'General',
    icon_name VARCHAR(50) DEFAULT 'code',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sample initial repository links
INSERT INTO repo_links (title, url, description, category, icon_name)
VALUES 
('Sanctuary Core Repository', 'https://github.com/carlosss91/Sanctuary', 'Repositorio principal del portal Sanctuary y creador de CV', 'Repositorios', 'folder_git'),
('Portal Docente & Formación', 'https://github.com/carlosss91', 'Herramientas de orientación laboral y gestión de certificados', 'Educación', 'school'),
('Web Apps & Microservicios', 'https://github.com/carlosss91', 'Ecosistema de utilidades y herramientas web interactivas', 'Web Apps', 'apps'),
('Documentación y Guías', 'https://github.com/carlosss91', 'Guías técnicas y documentación de proyectos', 'Docs', 'menu_book');

-- Sample initial CV profile matching reference screenshot
INSERT INTO cv_profiles (id, full_name, job_title, avatar_url, data_json)
VALUES 
('profile-1', 'JOSÉ MARIO SUÁREZ MÉNDEZ', 'OPERARIO/A DE MANTENIMIENTO URBANO', 'assets/avatars/avatar1.png', '{
  "id": "profile-1",
  "moduleBadge": "MÓDULO FC0003 · Inserción y Orientación Laboral",
  "workshopTitle": "Taller de Curriculum Vitae · Gestión Docente",
  "fullName": "JOSÉ MARIO SUÁREZ MÉNDEZ",
  "jobTitle": "OPERARIO/A DE MANTENIMIENTO URBANO",
  "photoUrl": "assets/avatars/avatar1.png",
  "photoZoom": 1.0,
  "photoPanX": 0.0,
  "photoPanY": 0.0,
  "phone": "+34 600 000 000",
  "email": "jose.suarez.mendez88@correo.es",
  "location": "Arucas, Gran Canaria",
  "availability": "Disponibilidad horaria e incorporación inmediata",
  "drivingLicense": "Permiso B y vehículo propio",
  "summary": "Soy un profesional comprometido y responsable, con vocación práctica, puntualidad y constante disposición para trabajar en equipo.\n\nManejo herramientas y métodos del oficio con destreza técnica, priorizando siempre la prevención de riesgos y el uso de EPIs.",
  "skills": [
    "Albañilería básica",
    "Fontanería básica",
    "Pintura y acabados",
    "Uso de maquinaria ligera",
    "Prevención de riesgos (EPIs)",
    "Trabajo en equipo",
    "Resolución de incidencias"
  ],
  "experiences": [
    {
      "jobTitle": "APRENDIZ TRABAJADOR/A - OPERARIO/A DE MANTENIMIENTO URBANO",
      "company": "Ayuntamiento de Arucas (Programa de Empleo y Formación Trayectoria)",
      "period": "2024 - 2025",
      "description": "Tareas prácticas en obras y servicios públicos municipales, conservación y manejo de herramientas y maquinaria ligera, y aplicación estricta de medidas de seguridad y EPIs."
    }
  ],
  "educations": [
    {
      "degree": "CERTIFICADO DE PROFESIONALIDAD (EN CURSO)",
      "institution": "Servicio Canario de Empleo / Ayuntamiento de Arucas",
      "period": "2024 - 2025",
      "details": "Formación teórico-práctica acreditada con módulos de Competencias Clave y PRL."
    },
    {
      "degree": "COMPETENCIAS CLAVE Y HABILIDADES LABORALES",
      "institution": "Programa de Empleo y Formación Trayectoria Arucas",
      "period": "2024 - 2025",
      "details": "Módulos transversales de Matemáticas, Lengua Castellana, Competencias Digitales y Orientación Laboral."
    }
  ],
  "template": "sidebar_dark",
  "accentColor": "#10B981",
  "fontFamily": "Inter"
}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cv_profiles (id, full_name, job_title, avatar_url, data_json)
VALUES 
('profile-2', 'ANTONIO JOSÉ GÓMEZ CABRERA', 'OPERARIO/A DE MANTENIMIENTO URBANO', 'assets/avatars/avatar2.png', '{
  "id": "profile-2",
  "moduleBadge": "MÓDULO FC0003 · Inserción y Orientación Laboral",
  "workshopTitle": "Taller de Curriculum Vitae · Gestión Docente",
  "fullName": "ANTONIO JOSÉ GÓMEZ CABRERA",
  "jobTitle": "OPERARIO/A DE MANTENIMIENTO URBANO",
  "photoUrl": "assets/avatars/avatar2.png",
  "photoZoom": 1.0,
  "photoPanX": 0.0,
  "photoPanY": 0.0,
  "phone": "+34 611 222 333",
  "email": "antonio.gomez.c@correo.es",
  "location": "Las Palmas de Gran Canaria",
  "availability": "Disponibilidad completa e incorporación inmediata",
  "drivingLicense": "Permiso B y vehículo propio",
  "summary": "Persona dinámica con gran capacidad de adaptación y aprendizaje rápido en labores de mantenimiento de espacios públicos e infraestructuras.",
  "skills": ["Mantenimiento preventivo", "Jardinería básica", "Reparaciones rápidas", "Manejo de herramienta manual"],
  "experiences": [
    {
      "jobTitle": "PEÓN DE MANTENIMIENTO URBANO",
      "company": "Servicios Urbanos Integrados",
      "period": "2023 - 2024",
      "description": "Limpieza y acondicionamiento de viales públicos, mantenimiento de mobiliario y apoyo a cuadrillas de especialistas."
    }
  ],
  "educations": [
    {
      "degree": "GRADUADO EN EDUCACIÓN SECUNDARIA OBLIGATORIA",
      "institution": "IES Gran Canaria",
      "period": "2018 - 2022",
      "details": "Graduado con mención en tecnología aplicada."
    }
  ],
  "template": "sidebar_dark",
  "accentColor": "#10B981",
  "fontFamily": "Inter"
}')
ON CONFLICT (id) DO NOTHING;
