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

// Helper: draw soft Gaussian volumetric nebula gas cloud
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

// Helper: draw continuous shooting comet with incandescent nucleus and trailing dust
function drawComet(data, width, height, hx, hy, tx, ty, headColor, tailColor, headRadius) {
  const steps = 40;
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
  // Luminous core
  drawDot(data, width, height, hx, hy, headRadius * 1.5, [255, 255, 255], 1.0);
}

// Helper: draw relativistic black hole matching Flutter preview specifications
function drawBlackHoleInstance(data, width, height, bhX, bhY, scale, progress, spinDir, isDark) {
  const rScale = scale || 1.0;

  // 1. Spacetime gravitational lensing well (deep contrast in light mode)
  if (!isDark) {
    drawNebulaGas(data, width, height, bhX, bhY, 68 * rScale, 46 * rScale, [15, 23, 42], 0.78);
    drawNebulaGas(data, width, height, bhX, bhY, 48 * rScale, 32 * rScale, [2, 6, 23], 0.88);
  } else {
    drawNebulaGas(data, width, height, bhX, bhY, 72 * rScale, 48 * rScale, [139, 92, 246], 0.32);
    drawNebulaGas(data, width, height, bhX, bhY, 52 * rScale, 34 * rScale, [6, 182, 212], 0.28);
  }

  // 2. Relativistic rotating plasma accretion disk
  const diskSteps = 54;
  const rotBase = progress * Math.PI * 2 * spinDir;
  for (let i = 0; i < diskSteps; i++) {
    const theta = rotBase + (i * Math.PI * 2) / diskSteps;
    const rx = (36 + Math.sin(theta * 2) * 5) * rScale;
    const ry = (15 + Math.cos(theta * 2) * 3) * rScale;
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
    drawDot(data, width, height, px, py, 2.6 * rScale, plasmaColor, 0.95);
  }

  // 3. Infalling matter streams spiraling into event horizon
  for (let s = 0; s < 5; s++) {
    const streamProg = (progress + s / 5.0) % 1.0;
    const spiralAngle = rotBase * 1.4 + (s * Math.PI * 2) / 5.0 + streamProg * Math.PI * 2;
    const dist = (12 + (1.0 - streamProg) * 28) * rScale;
    const sx = bhX + Math.cos(spiralAngle) * dist;
    const sy = bhY + Math.sin(spiralAngle) * dist * 0.42;
    drawDot(data, width, height, sx, sy, (1.8 * streamProg + 0.6) * rScale, isDark ? [253, 230, 138] : [217, 119, 6], 0.95);
  }

  // 4. Luminous Photon Sphere Ring
  for (let a = 0; a < 32; a++) {
    const rad = (a * Math.PI * 2) / 32;
    const px = bhX + Math.cos(rad) * (13 * rScale);
    const py = bhY + Math.sin(rad) * (11 * rScale);
    drawDot(data, width, height, px, py, 1.8 * rScale, isDark ? [56, 189, 248] : [2, 132, 199], 0.95);
  }

  // 5. Pitch-black Event Horizon core
  const coreR = Math.round(10 * rScale);
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

// 80 Deterministic celestial star coordinates identical to Flutter's CosmicEmailPreviewPainter
const denseStarCoords = [
  [0.04, 0.04], [0.12, 0.07], [0.19, 0.03], [0.27, 0.09], [0.34, 0.04], [0.42, 0.08],
  [0.50, 0.03], [0.58, 0.07], [0.66, 0.04], [0.74, 0.09], [0.81, 0.03], [0.89, 0.07],
  [0.96, 0.05], [0.08, 0.13], [0.23, 0.15], [0.38, 0.12], [0.52, 0.14], [0.62, 0.11],
  [0.77, 0.14], [0.86, 0.12], [0.93, 0.15],
  [0.03, 0.22], [0.09, 0.26], [0.16, 0.20], [0.24, 0.25], [0.31, 0.21], [0.40, 0.24],
  [0.48, 0.19], [0.56, 0.23], [0.65, 0.20], [0.72, 0.26], [0.80, 0.22], [0.88, 0.25],
  [0.96, 0.22], [0.04, 0.32], [0.11, 0.35], [0.18, 0.30], [0.26, 0.34], [0.35, 0.31],
  [0.44, 0.35], [0.53, 0.32], [0.62, 0.35], [0.70, 0.31], [0.79, 0.34], [0.87, 0.30],
  [0.94, 0.34],
  [0.02, 0.42], [0.08, 0.40], [0.15, 0.44], [0.22, 0.40], [0.30, 0.45], [0.38, 0.41],
  [0.46, 0.44], [0.54, 0.40], [0.62, 0.45], [0.70, 0.41], [0.78, 0.45], [0.85, 0.41],
  [0.92, 0.44], [0.98, 0.42], [0.03, 0.52], [0.10, 0.50], [0.17, 0.55], [0.25, 0.51],
  [0.33, 0.54], [0.42, 0.50], [0.50, 0.55], [0.58, 0.51], [0.67, 0.54], [0.75, 0.50],
  [0.83, 0.55], [0.90, 0.51], [0.97, 0.54],
  [0.04, 0.64], [0.11, 0.67], [0.19, 0.63], [0.27, 0.68], [0.36, 0.64], [0.45, 0.67],
  [0.54, 0.63], [0.63, 0.68], [0.72, 0.64], [0.81, 0.67], [0.89, 0.63], [0.96, 0.66],
  [0.02, 0.75], [0.09, 0.72], [0.16, 0.77], [0.24, 0.73], [0.32, 0.78], [0.41, 0.74],
  [0.50, 0.78], [0.59, 0.73], [0.68, 0.78], [0.77, 0.74], [0.85, 0.78], [0.92, 0.73],
  [0.98, 0.76],
  [0.04, 0.85], [0.12, 0.88], [0.20, 0.84], [0.28, 0.89], [0.37, 0.85], [0.46, 0.88],
  [0.55, 0.84], [0.64, 0.89], [0.73, 0.85], [0.82, 0.88], [0.90, 0.84], [0.96, 0.88],
  [0.05, 0.95], [0.14, 0.97], [0.22, 0.94], [0.31, 0.97], [0.40, 0.94], [0.48, 0.97],
  [0.56, 0.94], [0.65, 0.98], [0.74, 0.94], [0.82, 0.97], [0.89, 0.94], [0.96, 0.97],
];

// Helper: draw uniform dense twinkling starfield
function drawStarfield(data, width, height, progress, isDark) {
  for (let i = 0; i < denseStarCoords.length; i++) {
    const [rx, ry] = denseStarCoords[i];
    const sx = rx * width;
    const sy = ry * height;

    const pulse = Math.abs(Math.sin(progress * Math.PI * 2 + i * 1.35));
    const twinkle = 0.35 + 0.65 * pulse;

    const mod = i % 5;
    let starColor;
    if (mod === 0) {
      starColor = isDark ? [245, 158, 11] : [217, 119, 6]; // Amber Gold
    } else if (mod === 1) {
      starColor = isDark ? [255, 255, 255] : [2, 132, 199]; // White / Deep Sapphire
    } else if (mod === 2) {
      starColor = isDark ? [56, 189, 248] : [3, 105, 161]; // Azure Blue
    } else if (mod === 3) {
      starColor = isDark ? [16, 185, 129] : [4, 120, 87]; // Jade Emerald
    } else {
      starColor = isDark ? [167, 139, 250] : [109, 40, 217]; // Royal Violet
    }

    const baseR = (i % 3 === 0) ? 2.3 : ((i % 2 === 0) ? 1.7 : 1.1);
    const radius = baseR * (0.85 + 0.25 * twinkle);

    // Halo for prominent stars
    if (radius > 1.8) {
      drawDot(data, width, height, sx, sy, radius * 2.0, starColor, twinkle * (isDark ? 0.32 : 0.25));
    }
    drawDot(data, width, height, sx, sy, radius, starColor, twinkle);
  }
}

// Helper: draw ambient background auric glows
function drawAmbientAuras(data, width, height, isDark) {
  // Upper-left Jade / Emerald aura
  drawNebulaGas(data, width, height, width * 0.15, height * 0.15, 180, 150, isDark ? [16, 185, 129] : [5, 150, 105], isDark ? 0.16 : 0.14);
  // Upper-right Cyan / Azure aura
  drawNebulaGas(data, width, height, width * 0.85, height * 0.20, 190, 160, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.16 : 0.14);
  // Bottom Deep Blue aura
  drawNebulaGas(data, width, height, width * 0.50, height * 0.90, 210, 160, isDark ? [59, 130, 246] : [37, 99, 235], isDark ? 0.12 : 0.12);
}

// ========================================================
// 1. FULL-CANVAS BLACK HOLE & VORTEX (blackhole-sky-*)
// ========================================================
function createBlackHoleCanvas({ width = 800, height = 640, isDark = true, totalFrames = 18, delay = 90 }) {
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

    drawAmbientAuras(data, width, height, isDark);
    drawStarfield(data, width, height, progress, isDark);

    // 4 Symmetrical Black Holes flanking the central card (Card width: 420px, left: 190, right: 610)
    // Slot 1: Upper-Right Flank
    drawBlackHoleInstance(data, width, height, width * 0.86, height * 0.22, 0.96, progress, -1.0, isDark);
    // Slot 2: Lower-Left Flank
    drawBlackHoleInstance(data, width, height, width * 0.14, height * 0.78, 0.90, progress, -1.0, isDark);
    // Slot 3: Upper-Left Flank
    drawBlackHoleInstance(data, width, height, width * 0.14, height * 0.24, 0.84, progress, 1.0, isDark);
    // Slot 4: Lower-Right Flank
    drawBlackHoleInstance(data, width, height, width * 0.86, height * 0.72, 0.80, progress, 1.0, isDark);

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// ========================================================
// 2. FULL-CANVAS NEBULA COSMICA (nebula-sky-*)
// ========================================================
function createNebulaCanvas({ width = 800, height = 640, isDark = true, totalFrames = 18, delay = 90 }) {
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

    drawAmbientAuras(data, width, height, isDark);
    drawStarfield(data, width, height, progress, isDark);

    const p1 = 0.88 + 0.22 * Math.sin(progress * Math.PI * 2);
    const p2 = 0.88 + 0.22 * Math.cos(progress * Math.PI * 2);
    const p3 = 0.88 + 0.22 * Math.sin(progress * Math.PI * 2 + 1.5);
    const p4 = 0.88 + 0.22 * Math.cos(progress * Math.PI * 2 + 1.5);

    // 4 Symmetrical Nebulae in the 4 Quadrants
    // 1. Upper-Left: Royal Violet / Pink
    const c1x = width * 0.14, c1y = height * 0.22;
    if (!isDark) drawNebulaGas(data, width, height, c1x, c1y, 115 * p1, 105 * p1, [30, 41, 59], 0.40);
    drawNebulaGas(data, width, height, c1x, c1y, 105 * p1, 95 * p1, isDark ? [139, 92, 246] : [109, 40, 217], isDark ? 0.36 : 0.52);
    drawNebulaGas(data, width, height, c1x + 12, c1y + 10, 70 * p1, 60 * p1, isDark ? [236, 72, 153] : [190, 24, 93], isDark ? 0.30 : 0.44);

    // 2. Upper-Right: Sapphire Blue / Indigo
    const c2x = width * 0.86, c2y = height * 0.22;
    if (!isDark) drawNebulaGas(data, width, height, c2x, c2y, 115 * p2, 105 * p2, [15, 23, 42], 0.38);
    drawNebulaGas(data, width, height, c2x, c2y, 105 * p2, 95 * p2, isDark ? [59, 130, 246] : [37, 99, 235], isDark ? 0.35 : 0.50);
    drawNebulaGas(data, width, height, c2x - 10, c2y + 12, 70 * p2, 60 * p2, isDark ? [99, 102, 241] : [79, 70, 229], isDark ? 0.30 : 0.42);

    // 3. Lower-Left: Emerald / Cyan
    const c3x = width * 0.14, c3y = height * 0.76;
    if (!isDark) drawNebulaGas(data, width, height, c3x, c3y, 120 * p3, 110 * p3, [15, 23, 42], 0.38);
    drawNebulaGas(data, width, height, c3x, c3y, 110 * p3, 100 * p3, isDark ? [16, 185, 129] : [5, 150, 105], isDark ? 0.36 : 0.50);
    drawNebulaGas(data, width, height, c3x + 10, c3y - 12, 72 * p3, 62 * p3, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.30 : 0.42);

    // 4. Lower-Right: Amber / Gold
    const c4x = width * 0.86, c4y = height * 0.74;
    if (!isDark) drawNebulaGas(data, width, height, c4x, c4y, 115 * p4, 105 * p4, [30, 41, 59], 0.38);
    drawNebulaGas(data, width, height, c4x, c4y, 105 * p4, 95 * p4, isDark ? [245, 158, 11] : [217, 119, 6], isDark ? 0.36 : 0.52);
    drawNebulaGas(data, width, height, c4x - 10, c4y - 10, 70 * p4, 60 * p4, isDark ? [217, 119, 6] : [180, 83, 9], isDark ? 0.28 : 0.42);

    // Orbiting stardust sparks in all 4 clouds
    const centers = [[c1x, c1y], [c2x, c2y], [c3x, c3y], [c4x, c4y]];
    for (let c = 0; c < centers.length; c++) {
      const [cx, cy] = centers[c];
      for (let i = 0; i < 6; i++) {
        const angle = progress * Math.PI * 2 + (i * Math.PI * 2) / 6 + c * 0.8;
        const ox = cx + Math.cos(angle) * (26 + (i % 2) * 12);
        const oy = cy + Math.sin(angle) * (20 + (i % 2) * 8);
        drawDot(data, width, height, ox, oy, 1.8, isDark ? [255, 255, 255] : [217, 119, 6], 0.90);
      }
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// ========================================================
// 3. FULL-CANVAS COMETS & STARS (cosmic-sky-*)
// ========================================================
function createCosmicSkyCanvas({ width = 800, height = 640, isDark = true, totalFrames = 18, delay = 90 }) {
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

    drawAmbientAuras(data, width, height, isDark);
    drawStarfield(data, width, height, progress, isDark);

    // Continuous Edge-to-Edge Shooting Comets ("de una punta a la otra")
    // Comet 1: Crosses from upper-left to bottom-right across the whole screen
    {
      const cometProg = progress;
      const hx = -60 + cometProg * (width + 120);
      const hy = 60 + cometProg * (height * 0.60);
      const tx = hx - 90;
      const ty = hy - 45;
      const headColor = isDark ? [255, 255, 255] : [2, 132, 199];
      const tailColor = isDark ? [56, 189, 248] : [217, 119, 6];
      drawComet(data, width, height, hx, hy, tx, ty, headColor, tailColor, 3.4);

      // Trailing stardust sparks
      for (let s = 1; s <= 6; s++) {
        const sx = hx - s * 14 + Math.sin(progress * 10 + s) * 4;
        const sy = hy - s * 7 + Math.cos(progress * 10 + s) * 4;
        drawDot(data, width, height, sx, sy, 1.4, isDark ? [253, 230, 138] : [2, 132, 199], 0.80);
      }
    }

    // Comet 2: Crosses from lower-left to upper-right (interleaved timing)
    {
      const cometProg = (progress + 0.5) % 1.0;
      const hx = -50 + cometProg * (width + 100);
      const hy = height * 0.85 - cometProg * (height * 0.55);
      const tx = hx - 85;
      const ty = hy + 42;
      const headColor = isDark ? [255, 255, 255] : [2, 132, 199];
      const tailColor = isDark ? [16, 185, 129] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, headColor, tailColor, 3.2);

      // Trailing stardust sparks
      for (let s = 1; s <= 5; s++) {
        const sx = hx - s * 14 + Math.sin(progress * 10 + s) * 4;
        const sy = hy + s * 7 + Math.cos(progress * 10 + s) * 4;
        drawDot(data, width, height, sx, sy, 1.3, isDark ? [167, 139, 250] : [217, 119, 6], 0.75);
      }
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// Fallback mini banners & sides for backwards compatibility
function createMiniBanner({ isDark = true }) {
  const gif = GIFEncoder();
  const width = 100, height = 20;
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];
  const data = new Uint8Array(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    const idx = i * 4;
    data[idx] = bgColor[0];
    data[idx + 1] = bgColor[1];
    data[idx + 2] = bgColor[2];
    data[idx + 3] = 255;
  }
  const palette = quantize(data, 16);
  const index = applyPalette(data, palette);
  gif.writeFrame(index, width, height, { palette, delay: 500 });
  gif.finish();
  return Buffer.from(gif.bytes());
}

// Output destinations
const targetDirs = [
  path.join(__dirname, '../../web/assets'),
  path.join(__dirname, '../assets'),
];

for (const outDir of targetDirs) {
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  console.log('Generating unified full-canvas cosmic assets in:', outDir);

  // 1. Black Hole & Vortex
  console.log('  Generating blackhole canvases...');
  const bhDark = createBlackHoleCanvas({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'blackhole-sky-dark.gif'), bhDark);
  console.log('    -> blackhole-sky-dark.gif:', bhDark.length, 'bytes');

  const bhLight = createBlackHoleCanvas({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'blackhole-sky-light.gif'), bhLight);
  console.log('    -> blackhole-sky-light.gif:', bhLight.length, 'bytes');

  // 2. Nebula Cosmica
  console.log('  Generating nebula canvases...');
  const nebDark = createNebulaCanvas({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'nebula-sky-dark.gif'), nebDark);
  console.log('    -> nebula-sky-dark.gif:', nebDark.length, 'bytes');

  const nebLight = createNebulaCanvas({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'nebula-sky-light.gif'), nebLight);
  console.log('    -> nebula-sky-light.gif:', nebLight.length, 'bytes');

  // 3. Comets & Stars
  console.log('  Generating comet canvases...');
  const comDark = createCosmicSkyCanvas({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'cosmic-sky-dark.gif'), comDark);
  console.log('    -> cosmic-sky-dark.gif:', comDark.length, 'bytes');

  const comLight = createCosmicSkyCanvas({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'cosmic-sky-light.gif'), comLight);
  console.log('    -> cosmic-sky-light.gif:', comLight.length, 'bytes');

  // Mini compatibility dummies for obsolete banners/sides
  const miniDark = createMiniBanner({ isDark: true });
  const miniLight = createMiniBanner({ isDark: false });
  for (const prefix of ['cosmic', 'nebula', 'blackhole']) {
    fs.writeFileSync(path.join(outDir, `${prefix}-banner-dark.gif`), miniDark);
    fs.writeFileSync(path.join(outDir, `${prefix}-banner-light.gif`), miniLight);
    fs.writeFileSync(path.join(outDir, `${prefix}-side-dark.gif`), miniDark);
    fs.writeFileSync(path.join(outDir, `${prefix}-side-light.gif`), miniLight);
  }
}

console.log('All Cosmic Full-Canvas Backdrops generated successfully!');
