const { GIFEncoder, quantize, applyPalette } = require('gifenc');
const fs = require('fs');
const path = require('path');

// Helper: draw soft glowing dot / star
function drawDot(data, width, height, cx, cy, radius, [r, g, b], alpha = 1.0) {
  const minX = Math.max(0, Math.floor(cx - radius * 1.6));
  const maxX = Math.min(width - 1, Math.ceil(cx + radius * 1.6));
  const minY = Math.max(0, Math.floor(cy - radius * 1.6));
  const maxY = Math.min(height - 1, Math.ceil(cy + radius * 1.6));

  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const dist = Math.hypot(x - cx, y - cy);
      if (dist <= radius * 1.6) {
        const intensity = Math.max(0, Math.min(1, 1 - (dist / (radius * 1.6)))) * alpha;
        if (intensity > 0.03) {
          const idx = (y * width + x) * 4;
          data[idx] = Math.round(data[idx] * (1 - intensity) + r * intensity);
          data[idx + 1] = Math.round(data[idx + 1] * (1 - intensity) + g * intensity);
          data[idx + 2] = Math.round(data[idx + 2] * (1 - intensity) + b * intensity);
        }
      }
    }
  }
}

// Helper: draw soft Gaussian-like volumetric nebula gas cloud
function drawNebulaGas(data, width, height, cx, cy, rx, ry, [r, g, b], maxAlpha = 0.35) {
  const minX = Math.max(0, Math.floor(cx - rx));
  const maxX = Math.min(width - 1, Math.ceil(cx + rx));
  const minY = Math.max(0, Math.floor(cy - ry));
  const maxY = Math.min(height - 1, Math.ceil(cy + ry));

  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const normDist = Math.hypot((x - cx) / rx, (y - cy) / ry);
      if (normDist <= 1.0) {
        const intensity = Math.pow(1 - normDist, 1.8) * maxAlpha;
        if (intensity > 0.02) {
          const idx = (y * width + x) * 4;
          data[idx] = Math.round(data[idx] * (1 - intensity) + r * intensity);
          data[idx + 1] = Math.round(data[idx + 1] * (1 - intensity) + g * intensity);
          data[idx + 2] = Math.round(data[idx + 2] * (1 - intensity) + b * intensity);
        }
      }
    }
  }
}

// Helper: draw luminous shooting comet with radiant tail
function drawComet(data, width, height, hx, hy, tx, ty, headColor, tailColor, headRadius) {
  const steps = 36;
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    const px = hx * (1 - t) + tx * t;
    const py = hy * (1 - t) + ty * t;
    const tailAlpha = (1 - t) * 0.92;
    const radius = headRadius * (1 - t * 0.72);
    const cr = Math.round(headColor[0] * (1 - t) + tailColor[0] * t);
    const cg = Math.round(headColor[1] * (1 - t) + tailColor[1] * t);
    const cb = Math.round(headColor[2] * (1 - t) + tailColor[2] * t);
    drawDot(data, width, height, px, py, radius, [cr, cg, cb], tailAlpha);
  }
  // Glowing incandescent nucleus
  drawDot(data, width, height, hx, hy, headRadius * 1.5, [255, 255, 255], 1.0);
}

// Helper: draw full relativistic black hole with accretion disk, event horizon & lensing
function drawBlackHoleInstance(data, width, height, bhX, bhY, scale, progress, spinDir, isDark) {
  const rScale = scale || 1.0;

  // 1. Spacetime gravitational lensing well (especially critical in light mode for stark contrast)
  if (!isDark) {
    drawNebulaGas(data, width, height, bhX, bhY, 52 * rScale, 36 * rScale, [15, 23, 42], 0.75);
    drawNebulaGas(data, width, height, bhX, bhY, 36 * rScale, 24 * rScale, [2, 6, 23], 0.85);
  } else {
    drawNebulaGas(data, width, height, bhX, bhY, 58 * rScale, 38 * rScale, [139, 92, 246], 0.32);
    drawNebulaGas(data, width, height, bhX, bhY, 44 * rScale, 28 * rScale, [6, 182, 212], 0.28);
  }

  // 2. Relativistic rotating plasma accretion disk
  const diskSteps = 54;
  const rotBase = progress * Math.PI * 2 * spinDir;
  for (let i = 0; i < diskSteps; i++) {
    const theta = rotBase + (i * Math.PI * 2) / diskSteps;
    const rx = (32 + Math.sin(theta * 2) * 4) * rScale;
    const ry = (13 + Math.cos(theta * 2) * 2) * rScale;
    const px = bhX + Math.cos(theta) * rx;
    const py = bhY + Math.sin(theta) * ry;

    const norm = (i / diskSteps);
    let plasmaColor;
    if (norm < 0.33) {
      plasmaColor = isDark ? [245, 158, 11] : [217, 119, 6]; // Amber
    } else if (norm < 0.66) {
      plasmaColor = isDark ? [56, 189, 248] : [2, 132, 199]; // Cyan
    } else {
      plasmaColor = isDark ? [239, 68, 68] : [185, 28, 28]; // Crimson
    }
    drawDot(data, width, height, px, py, 2.4 * rScale, plasmaColor, 0.92);
  }

  // 3. Infalling matter streams spiraling into event horizon
  for (let s = 0; s < 5; s++) {
    const streamProg = (progress + s / 5.0) % 1.0;
    const spiralAngle = rotBase * 1.4 + (s * Math.PI * 2) / 5.0 + streamProg * Math.PI * 2;
    const dist = (10 + (1.0 - streamProg) * 26) * rScale;
    const sx = bhX + Math.cos(spiralAngle) * dist;
    const sy = bhY + Math.sin(spiralAngle) * dist * 0.42;
    drawDot(data, width, height, sx, sy, (1.6 * streamProg + 0.5) * rScale, isDark ? [253, 230, 138] : [217, 119, 6], 0.95);
  }

  // 4. Luminous Photon Sphere Ring
  for (let a = 0; a < 28; a++) {
    const rad = (a * Math.PI * 2) / 28;
    const px = bhX + Math.cos(rad) * (11 * rScale);
    const py = bhY + Math.sin(rad) * (10 * rScale);
    drawDot(data, width, height, px, py, 1.6 * rScale, isDark ? [56, 189, 248] : [2, 132, 199], 0.95);
  }

  // 5. Pitch-black Event Horizon core
  const coreR = Math.round(9 * rScale);
  for (let y = Math.max(0, Math.floor(bhY - coreR)); y <= Math.min(height - 1, Math.ceil(bhY + coreR)); y++) {
    for (let x = Math.max(0, Math.floor(bhX - coreR)); x <= Math.min(width - 1, Math.ceil(bhX + coreR)); x++) {
      if (Math.hypot(x - bhX, y - bhY) <= coreR) {
        const idx = (y * width + x) * 4;
        data[idx] = 3;
        data[idx + 1] = 7;
        data[idx + 2] = 18;
        data[idx + 3] = 255;
      }
    }
  }
}

// Shared celestial stars set (deterministic distribution)
const sharedSkyStars = [
  { x: 25, y: 35, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.1 },
  { x: 65, y: 90, r: 2.6, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 1.4 },
  { x: 110, y: 35, r: 1.6, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.7 },
  { x: 155, y: 110, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 0.8 },
  { x: 200, y: 45, r: 1.8, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 3.2 },
  { x: 250, y: 80, r: 2.8, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 1.9 },
  { x: 300, y: 30, r: 1.9, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.1 },
  { x: 350, y: 105, r: 2.5, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 2.3 },
  { x: 400, y: 50, r: 1.7, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.5 },
  { x: 445, y: 95, r: 2.3, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 3.7 },

  { x: 35, y: 160, r: 1.9, colorDark: [167, 139, 250], colorLight: [124, 58, 237], phase: 1.1 },
  { x: 85, y: 210, r: 2.4, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 2.9 },
  { x: 130, y: 175, r: 1.5, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.3 },
  { x: 180, y: 230, r: 2.7, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 3.5 },
  { x: 230, y: 165, r: 2.0, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 1.6 },
  { x: 280, y: 220, r: 1.8, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 4.3 },
  { x: 330, y: 170, r: 2.5, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 2.0 },
  { x: 380, y: 225, r: 1.9, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.7 },
  { x: 435, y: 180, r: 2.3, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 3.0 },

  { x: 30, y: 280, r: 2.1, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 1.8 },
  { x: 75, y: 340, r: 2.6, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 3.6 },
  { x: 125, y: 295, r: 1.7, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 0.9 },
  { x: 170, y: 350, r: 2.3, colorDark: [245, 158, 11], colorLight: [2, 132, 199], phase: 2.4 },
  { x: 220, y: 300, r: 1.9, colorDark: [56, 189, 248], colorLight: [124, 58, 237], phase: 4.5 },
  { x: 270, y: 360, r: 2.8, colorDark: [255, 255, 255], colorLight: [217, 119, 6], phase: 1.3 },
  { x: 320, y: 305, r: 1.6, colorDark: [167, 139, 250], colorLight: [124, 58, 237], phase: 3.1 },
  { x: 370, y: 355, r: 2.4, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.4 },
  { x: 420, y: 310, r: 2.0, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 2.8 },

  { x: 40, y: 410, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 1.5 },
  { x: 90, y: 450, r: 1.9, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 3.3 },
  { x: 140, y: 415, r: 2.5, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 0.6 },
  { x: 190, y: 455, r: 1.7, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 2.2 },
  { x: 240, y: 420, r: 2.3, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 4.0 },
  { x: 290, y: 450, r: 1.8, colorDark: [245, 158, 11], colorLight: [2, 132, 199], phase: 1.7 },
  { x: 340, y: 415, r: 2.7, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 3.8 },
  { x: 390, y: 455, r: 2.0, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 0.2 },
  { x: 440, y: 420, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 2.5 },
];

const sharedBannerStars = [
  { x: 35, y: 35, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0 },
  { x: 75, y: 22, r: 2.8, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 1.2 },
  { x: 120, y: 55, r: 1.8, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.5 },
  { x: 165, y: 28, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 0.8 },
  { x: 215, y: 65, r: 1.8, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 3.1 },
  { x: 260, y: 20, r: 2.6, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 1.7 },
  { x: 310, y: 52, r: 2.0, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.0 },
  { x: 360, y: 25, r: 2.9, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 2.1 },
  { x: 410, y: 62, r: 1.9, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.5 },
  { x: 460, y: 30, r: 2.5, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 3.6 },
  { x: 505, y: 55, r: 2.2, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 1.9 },
  { x: 535, y: 25, r: 1.8, colorDark: [245, 158, 11], colorLight: [124, 58, 237], phase: 4.5 },
];

const sharedSideStars = [
  { x: 25, y: 35, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.2 },
  { x: 75, y: 70, r: 2.6, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 1.5 },
  { x: 35, y: 110, r: 1.8, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.8 },
  { x: 80, y: 150, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 0.9 },
  { x: 30, y: 220, r: 1.9, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 3.4 },
  { x: 70, y: 260, r: 2.8, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 1.8 },
  { x: 25, y: 300, r: 2.1, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.1 },
  { x: 80, y: 340, r: 2.5, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 2.3 },
  { x: 35, y: 380, r: 1.9, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.6 },
  { x: 75, y: 420, r: 2.7, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 3.2 },
  { x: 25, y: 510, r: 2.0, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 1.4 },
  { x: 85, y: 550, r: 2.6, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.4 },
  { x: 30, y: 590, r: 1.9, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.1 },
  { x: 80, y: 625, r: 2.7, colorDark: [253, 230, 138], colorLight: [2, 132, 199], phase: 0.5 },
];

// ==========================================
// 1. COMETS & STARS (cosmic-*)
// ==========================================
function createCosmicSkyTile({ width = 480, height = 480, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // Stars twinkling across the entire sky
    for (const s of sharedSkyStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // Shooting comets flanking the left and right sides so they don't get hidden behind the card!
    // Left flank comet:
    if (progress < 0.60) {
      const t = progress / 0.60;
      const hx = -20 + t * 150;
      const hy = 50 + t * 140;
      const tx = hx - 70;
      const ty = hy - 45;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [56, 189, 248] : [217, 119, 6];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.2);
    }

    // Right flank comet:
    if (progress >= 0.40) {
      const t = (progress - 0.40) / 0.60;
      const hx = 350 + t * 150;
      const hy = 240 + t * 140;
      const tx = hx - 70;
      const ty = hy - 45;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [16, 185, 129] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.0);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createCosmicBanner({ width = 560, height = 90, isDark = true, totalFrames = 24, delay = 110 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    for (const s of sharedBannerStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const cometActive = progress < 0.65;
    if (cometActive) {
      const t = progress / 0.65;
      const hx = -40 + t * (width + 120);
      const hy = 14 + t * 44;
      const tx = hx - 90;
      const ty = hy - 30;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [56, 189, 248] : [217, 119, 6];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.4);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createCosmicSide({ width = 110, height = 650, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // Twinkling stars flanking the side column
    for (const s of sharedSideStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // 1. Upper shooting comet streaming down the lateral wing
    if (progress < 0.60) {
      const t = progress / 0.60;
      const hx = -15 + t * 140;
      const hy = 25 + t * 240;
      const tx = hx - 55;
      const ty = hy - 85;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [56, 189, 248] : [217, 119, 6];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.2);
    }

    // 2. Lower shooting comet streaming down the lateral wing
    if (progress >= 0.42) {
      const t = (progress - 0.42) / 0.58;
      const hx = -15 + t * 140;
      const hy = 330 + t * 250;
      const tx = hx - 55;
      const ty = hy - 85;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [16, 185, 129] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.0);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// ==========================================
// 2. NEBULA COSMICA (nebula-*)
// ==========================================
function createNebulaSkyTile({ width = 480, height = 480, isDark = true, totalFrames = 24, delay = 110 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    const p1 = 0.85 + 0.25 * Math.sin(progress * Math.PI * 2);
    const p2 = 0.85 + 0.25 * Math.cos(progress * Math.PI * 2);

    // Left Flank Nebula: Violet/Pink Cloud (x: 80, y: 160) - completely visible beside central card!
    if (!isDark) {
      drawNebulaGas(data, width, height, 80, 160, 110 * p1, 100 * p1, [30, 41, 59], 0.38);
    }
    drawNebulaGas(data, width, height, 80, 160, 100 * p1, 90 * p1, isDark ? [139, 92, 246] : [109, 40, 217], isDark ? 0.38 : 0.52);
    drawNebulaGas(data, width, height, 95, 175, 65 * p1, 55 * p1, isDark ? [236, 72, 153] : [190, 24, 93], isDark ? 0.32 : 0.44);

    // Right Flank Nebula: Emerald/Cyan Cloud (x: 400, y: 320) - completely visible beside central card!
    if (!isDark) {
      drawNebulaGas(data, width, height, 400, 320, 110 * p2, 100 * p2, [15, 23, 42], 0.36);
    }
    drawNebulaGas(data, width, height, 400, 320, 100 * p2, 90 * p2, isDark ? [16, 185, 129] : [4, 120, 87], isDark ? 0.36 : 0.50);
    drawNebulaGas(data, width, height, 385, 305, 65 * p2, 55 * p2, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.30 : 0.42);

    // Twinkling canopy stars
    for (const s of sharedSkyStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // Swirling stardust on both flanks
    for (let i = 0; i < 10; i++) {
      const angle = progress * Math.PI * 2 + (i * Math.PI * 2) / 10;
      const ox1 = 80 + Math.cos(angle) * (30 + (i % 3) * 12);
      const oy1 = 160 + Math.sin(angle) * (25 + (i % 3) * 10);
      drawDot(data, width, height, ox1, oy1, 2.0, isDark ? [255, 255, 255] : [217, 119, 6], 0.85);

      const ox2 = 400 + Math.cos(-angle) * (30 + (i % 3) * 12);
      const oy2 = 320 + Math.sin(-angle) * (25 + (i % 3) * 10);
      drawDot(data, width, height, ox2, oy2, 2.0, isDark ? [255, 255, 255] : [2, 132, 199], 0.85);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createNebulaBanner({ width = 560, height = 90, isDark = true, totalFrames = 24, delay = 110 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    const shift = Math.sin(progress * Math.PI * 2) * 25;
    if (!isDark) {
      drawNebulaGas(data, width, height, 140 + shift, 45, 170, 44, [30, 41, 59], 0.35);
      drawNebulaGas(data, width, height, 400 - shift, 45, 180, 42, [15, 23, 42], 0.35);
    }
    drawNebulaGas(data, width, height, 140 + shift, 45, 160, 42, isDark ? [139, 92, 246] : [109, 40, 217], isDark ? 0.38 : 0.50);
    drawNebulaGas(data, width, height, 400 - shift, 45, 180, 40, isDark ? [16, 185, 129] : [4, 120, 87], isDark ? 0.34 : 0.48);
    drawNebulaGas(data, width, height, 270 + shift * 0.5, 45, 120, 36, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.28 : 0.40);

    for (const s of sharedBannerStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    for (let i = 0; i < 14; i++) {
      const px = ((progress + i / 14) % 1.0) * width;
      const py = 20 + Math.sin(progress * Math.PI * 2 + i) * 28;
      drawDot(data, width, height, px, py, 2.0, isDark ? [253, 230, 138] : [217, 119, 6], 0.85);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createNebulaSide({ width = 110, height = 650, isDark = true, totalFrames = 24, delay = 110 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    const p = Math.sin(progress * Math.PI * 2);

    // 1. Upper Flank Nebula: Royal Violet / Pink
    if (!isDark) {
      drawNebulaGas(data, width, height, 55, 175 + p * 15, 52, 115, [30, 41, 59], 0.42);
    }
    drawNebulaGas(data, width, height, 55, 175 + p * 15, 50, 110, isDark ? [139, 92, 246] : [109, 40, 217], isDark ? 0.38 : 0.54);
    drawNebulaGas(data, width, height, 55, 175 + p * 15, 36, 75, isDark ? [236, 72, 153] : [190, 24, 93], isDark ? 0.32 : 0.46);

    // 2. Lower Flank Nebula: Emerald / Cyan
    if (!isDark) {
      drawNebulaGas(data, width, height, 55, 475 - p * 15, 52, 120, [15, 23, 42], 0.40);
    }
    drawNebulaGas(data, width, height, 55, 475 - p * 15, 50, 115, isDark ? [16, 185, 129] : [4, 120, 87], isDark ? 0.36 : 0.52);
    drawNebulaGas(data, width, height, 55, 475 - p * 15, 36, 80, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.30 : 0.44);

    // Orbiting stardust in both clouds
    for (let i = 0; i < 6; i++) {
      const angle = progress * Math.PI * 2 + (i * Math.PI * 2) / 6;
      const ox1 = 55 + Math.cos(angle) * 26;
      const oy1 = (175 + p * 15) + Math.sin(angle) * 35;
      drawDot(data, width, height, ox1, oy1, 2.2, isDark ? [255, 255, 255] : [217, 119, 6], 0.88);

      const ox2 = 55 + Math.cos(-angle) * 26;
      const oy2 = (475 - p * 15) + Math.sin(-angle) * 35;
      drawDot(data, width, height, ox2, oy2, 2.2, isDark ? [255, 255, 255] : [2, 132, 199], 0.88);
    }

    // Twinkling stars flanking the column
    for (const s of sharedSideStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// ==========================================
// 3. BLACK HOLE & VORTEX (blackhole-*)
// ==========================================
function createBlackHoleSkyTile({ width = 480, height = 480, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // Place Black Holes on the FLANKS (left: 75, right: 405) so they are completely visible around the central card!
    drawBlackHoleInstance(data, width, height, 75, 170, 0.92, progress, 1.0, isDark);
    drawBlackHoleInstance(data, width, height, 405, 320, 0.88, progress, -1.0, isDark);

    // Stars twinkling across the wide sky
    for (const s of sharedSkyStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createBlackHoleBanner({ width = 560, height = 90, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];
  const bhX = 440;
  const bhY = 45;

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // Twinkling stars across the wide sky
    for (const s of sharedBannerStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // Single majestic black hole in upper canopy
    drawBlackHoleInstance(data, width, height, bhX, bhY, 1.05, progress, 1.0, isDark);

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createBlackHoleSide({ width = 110, height = 650, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // PROMINENT BLACK HOLES PLACED DIRECTLY ON THE SIDES OF THE MESSAGE!
    // Black Hole 1: Upper lateral side
    drawBlackHoleInstance(data, width, height, 55, 175, 0.95, progress, 1.0, isDark);

    // Black Hole 2: Lower lateral side (counter-rotating binary companion)
    drawBlackHoleInstance(data, width, height, 55, 475, 0.88, progress, -1.0, isDark);

    // Stars twinkling around the black holes along the column
    for (const s of sharedSideStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.40 + 0.60 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// Generate files in both web/assets and backend/assets
const targetDirs = [
  path.join(__dirname, '../../web/assets'),
  path.join(__dirname, '../assets'),
];

for (const outDir of targetDirs) {
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  console.log('Generating cosmic & space assets in:', outDir);

  // 1. Cometas & Estrellas
  const skyDark = createCosmicSkyTile({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'cosmic-sky-dark.gif'), skyDark);
  console.log('  -> cosmic-sky-dark.gif:', skyDark.length, 'bytes');

  const skyLight = createCosmicSkyTile({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'cosmic-sky-light.gif'), skyLight);
  console.log('  -> cosmic-sky-light.gif:', skyLight.length, 'bytes');

  const bannerDark = createCosmicBanner({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'cosmic-banner-dark.gif'), bannerDark);
  console.log('  -> cosmic-banner-dark.gif:', bannerDark.length, 'bytes');

  const bannerLight = createCosmicBanner({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'cosmic-banner-light.gif'), bannerLight);
  console.log('  -> cosmic-banner-light.gif:', bannerLight.length, 'bytes');

  const sideDark = createCosmicSide({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'cosmic-side-dark.gif'), sideDark);
  console.log('  -> cosmic-side-dark.gif:', sideDark.length, 'bytes');

  const sideLight = createCosmicSide({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'cosmic-side-light.gif'), sideLight);
  console.log('  -> cosmic-side-light.gif:', sideLight.length, 'bytes');

  // 2. Nebulosa Cósmica
  const nebulaSkyDark = createNebulaSkyTile({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'nebula-sky-dark.gif'), nebulaSkyDark);
  console.log('  -> nebula-sky-dark.gif:', nebulaSkyDark.length, 'bytes');

  const nebulaSkyLight = createNebulaSkyTile({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'nebula-sky-light.gif'), nebulaSkyLight);
  console.log('  -> nebula-sky-light.gif:', nebulaSkyLight.length, 'bytes');

  const nebulaBannerDark = createNebulaBanner({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'nebula-banner-dark.gif'), nebulaBannerDark);
  console.log('  -> nebula-banner-dark.gif:', nebulaBannerDark.length, 'bytes');

  const nebulaBannerLight = createNebulaBanner({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'nebula-banner-light.gif'), nebulaBannerLight);
  console.log('  -> nebula-banner-light.gif:', nebulaBannerLight.length, 'bytes');

  const nebulaSideDark = createNebulaSide({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'nebula-side-dark.gif'), nebulaSideDark);
  console.log('  -> nebula-side-dark.gif:', nebulaSideDark.length, 'bytes');

  const nebulaSideLight = createNebulaSide({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'nebula-side-light.gif'), nebulaSideLight);
  console.log('  -> nebula-side-light.gif:', nebulaSideLight.length, 'bytes');

  // 3. Agujero Negro & Vórtice
  const bhSkyDark = createBlackHoleSkyTile({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'blackhole-sky-dark.gif'), bhSkyDark);
  console.log('  -> blackhole-sky-dark.gif:', bhSkyDark.length, 'bytes');

  const bhSkyLight = createBlackHoleSkyTile({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'blackhole-sky-light.gif'), bhSkyLight);
  console.log('  -> blackhole-sky-light.gif:', bhSkyLight.length, 'bytes');

  const bhBannerDark = createBlackHoleBanner({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'blackhole-banner-dark.gif'), bhBannerDark);
  console.log('  -> blackhole-banner-dark.gif:', bhBannerDark.length, 'bytes');

  const bhBannerLight = createBlackHoleBanner({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'blackhole-banner-light.gif'), bhBannerLight);
  console.log('  -> blackhole-banner-light.gif:', bhBannerLight.length, 'bytes');

  const bhSideDark = createBlackHoleSide({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'blackhole-side-dark.gif'), bhSideDark);
  console.log('  -> blackhole-side-dark.gif:', bhSideDark.length, 'bytes');

  const bhSideLight = createBlackHoleSide({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'blackhole-side-light.gif'), bhSideLight);
  console.log('  -> blackhole-side-light.gif:', bhSideLight.length, 'bytes');
}

console.log('All Space & Cosmic GIFs generated successfully!');
