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
  // Luminous core
  drawDot(data, width, height, hx, hy, headRadius * 1.5, [255, 255, 255], 1.0);
}

// Helper: draw relativistic black hole in flank position
function drawBlackHoleInstance(data, width, height, bhX, bhY, scale, progress, spinDir, isDark) {
  const rScale = scale || 1.0;

  // 1. Spacetime gravitational lensing well (deep contrast in light mode)
  if (!isDark) {
    drawNebulaGas(data, width, height, bhX, bhY, 74 * rScale, 52 * rScale, [15, 23, 42], 0.85);
    drawNebulaGas(data, width, height, bhX, bhY, 52 * rScale, 36 * rScale, [2, 6, 23], 0.92);
  } else {
    drawNebulaGas(data, width, height, bhX, bhY, 78 * rScale, 54 * rScale, [139, 92, 246], 0.35);
    drawNebulaGas(data, width, height, bhX, bhY, 56 * rScale, 38 * rScale, [6, 182, 212], 0.30);
  }

  // 2. Relativistic rotating plasma accretion disk
  const diskSteps = 54;
  const rotBase = progress * Math.PI * 2 * spinDir;
  for (let i = 0; i < diskSteps; i++) {
    const theta = rotBase + (i * Math.PI * 2) / diskSteps;
    const rx = (40 + Math.sin(theta * 2) * 5) * rScale;
    const ry = (17 + Math.cos(theta * 2) * 3) * rScale;
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
    drawDot(data, width, height, px, py, 2.7 * rScale, plasmaColor, 0.95);
  }

  // 3. Infalling matter streams spiraling into event horizon
  for (let s = 0; s < 5; s++) {
    const streamProg = (progress + s / 5.0) % 1.0;
    const spiralAngle = rotBase * 1.4 + (s * Math.PI * 2) / 5.0 + streamProg * Math.PI * 2;
    const dist = (12 + (1.0 - streamProg) * 30) * rScale;
    const sx = bhX + Math.cos(spiralAngle) * dist;
    const sy = bhY + Math.sin(spiralAngle) * dist * 0.42;
    drawDot(data, width, height, sx, sy, (1.8 * streamProg + 0.6) * rScale, isDark ? [253, 230, 138] : [217, 119, 6], 0.95);
  }

  // 4. Luminous Photon Sphere Ring
  for (let a = 0; a < 32; a++) {
    const rad = (a * Math.PI * 2) / 32;
    const px = bhX + Math.cos(rad) * (14 * rScale);
    const py = bhY + Math.sin(rad) * (12 * rScale);
    drawDot(data, width, height, px, py, 1.9 * rScale, isDark ? [56, 189, 248] : [2, 132, 199], 0.95);
  }

  // 5. Pitch-black Event Horizon core
  const coreR = Math.round(11 * rScale);
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

// 80 Deterministic celestial star coordinates
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
      starColor = isDark ? [245, 158, 11] : [217, 119, 6];
    } else if (mod === 1) {
      starColor = isDark ? [255, 255, 255] : [2, 132, 199];
    } else if (mod === 2) {
      starColor = isDark ? [56, 189, 248] : [3, 105, 161];
    } else if (mod === 3) {
      starColor = isDark ? [16, 185, 129] : [4, 120, 87];
    } else {
      starColor = isDark ? [167, 139, 250] : [109, 40, 217];
    }

    const baseR = (i % 3 === 0) ? 2.4 : ((i % 2 === 0) ? 1.7 : 1.1);
    const radius = baseR * (0.85 + 0.25 * twinkle);

    if (radius > 1.8) {
      drawDot(data, width, height, sx, sy, radius * 2.0, starColor, twinkle * (isDark ? 0.32 : 0.25));
    }
    drawDot(data, width, height, sx, sy, radius, starColor, twinkle);
  }
}

// Helper: draw ambient background auric glows
function drawAmbientAuras(data, width, height, isDark) {
  drawNebulaGas(data, width, height, width * 0.15, height * 0.15, 190, 160, isDark ? [16, 185, 129] : [5, 150, 105], isDark ? 0.18 : 0.14);
  drawNebulaGas(data, width, height, width * 0.85, height * 0.20, 200, 170, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.18 : 0.14);
  drawNebulaGas(data, width, height, width * 0.50, height * 0.90, 220, 170, isDark ? [59, 130, 246] : [37, 99, 235], isDark ? 0.14 : 0.12);
}

// ========================================================
// 1. FULL-CANVAS BLACK HOLE & VORTEX BY COUNT (1 to 4)
// ========================================================
function createBlackHoleCanvas({ count = 4, width = 980, height = 740, isDark = true, totalFrames = 14, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  // 4 Slot Coordinates placed well in the open flanks (Card width 420px is at X: 280 to 700)
  // Left flank center: X=140. Right flank center: X=840.
  const slots = [
    { x: 840, y: 180, scale: 1.02, spinDir: -1.0 }, // Slot 1: Upper-Right Flank
    { x: 140, y: 520, scale: 0.94, spinDir: -1.0 }, // Slot 2: Lower-Left Flank
    { x: 140, y: 180, scale: 0.88, spinDir: 1.0 },  // Slot 3: Upper-Left Flank
    { x: 840, y: 520, scale: 0.82, spinDir: 1.0 },  // Slot 4: Lower-Right Flank
  ];

  const activeCount = Math.min(Math.max(count, 1), 4);

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

    // Draw active black holes based on slider count
    for (let s = 0; s < activeCount; s++) {
      const slot = slots[s];
      drawBlackHoleInstance(data, width, height, slot.x, slot.y, slot.scale, progress, slot.spinDir, isDark);
    }

    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// ========================================================
// 2. FULL-CANVAS NEBULA COSMICA BY COUNT (1 to 4)
// ========================================================
function createNebulaCanvas({ count = 4, width = 980, height = 740, isDark = true, totalFrames = 14, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const nebulaSlots = [
    // Slot 1: Upper-Right (Sapphire / Indigo)
    { x: 840, y: 180, darkP: [59, 130, 246], darkS: [99, 102, 241], lightP: [37, 99, 235], lightS: [79, 70, 229], phase: 0 },
    // Slot 2: Lower-Left (Emerald / Cyan)
    { x: 140, y: 520, darkP: [16, 185, 129], darkS: [6, 182, 212], lightP: [5, 150, 105], lightS: [2, 132, 199], phase: 1.5 },
    // Slot 3: Upper-Left (Royal Violet / Pink)
    { x: 140, y: 180, darkP: [139, 92, 246], darkS: [236, 72, 153], lightP: [109, 40, 217], lightS: [190, 24, 93], phase: 0.8 },
    // Slot 4: Lower-Right (Amber / Gold)
    { x: 840, y: 520, darkP: [245, 158, 11], darkS: [217, 119, 6], lightP: [217, 119, 6], lightS: [180, 83, 9], phase: 2.2 },
  ];

  const activeCount = Math.min(Math.max(count, 1), 4);

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

    for (let s = 0; s < activeCount; s++) {
      const slot = nebulaSlots[s];
      const p = 0.88 + 0.22 * Math.sin(progress * Math.PI * 2 + slot.phase);

      if (!isDark) {
        drawNebulaGas(data, width, height, slot.x, slot.y, 120 * p, 110 * p, [20, 30, 48], 0.42);
      }
      drawNebulaGas(data, width, height, slot.x, slot.y, 110 * p, 100 * p, isDark ? slot.darkP : slot.lightP, isDark ? 0.38 : 0.54);
      drawNebulaGas(data, width, height, slot.x + 8, slot.y + 6, 72 * p, 62 * p, isDark ? slot.darkS : slot.lightS, isDark ? 0.32 : 0.46);

      // Stardust sparks
      for (let i = 0; i < 6; i++) {
        const angle = progress * Math.PI * 2 + (i * Math.PI * 2) / 6 + slot.phase;
        const ox = slot.x + Math.cos(angle) * (28 + (i % 2) * 12);
        const oy = slot.y + Math.sin(angle) * (22 + (i % 2) * 8);
        drawDot(data, width, height, ox, oy, 1.9, isDark ? [255, 255, 255] : [217, 119, 6], 0.90);
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
// 3. FULL-CANVAS COMETS & STARS BY COUNT (1 to 4)
// ========================================================
function createCosmicSkyCanvas({ count = 2, width = 980, height = 740, isDark = true, totalFrames = 14, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const cometDefs = [
    // Comet 1: Upper-left to Lower-right
    {
      calc: (prog) => ({
        hx: -50 + prog * (width + 100),
        hy: 80 + prog * (height * 0.65),
        txOffset: -90,
        tyOffset: -45,
      }),
      head: isDark ? [255, 255, 255] : [2, 132, 199],
      tail: isDark ? [56, 189, 248] : [217, 119, 6],
      radius: 3.5,
      progOffset: 0,
    },
    // Comet 2: Lower-left to Upper-right
    {
      calc: (prog) => ({
        hx: -40 + prog * (width + 90),
        hy: height * 0.85 - prog * (height * 0.60),
        txOffset: -85,
        tyOffset: 42,
      }),
      head: isDark ? [255, 255, 255] : [2, 132, 199],
      tail: isDark ? [16, 185, 129] : [5, 150, 105],
      radius: 3.2,
      progOffset: 0.50,
    },
    // Comet 3: Steep Upper-Right to Lower-Left
    {
      calc: (prog) => ({
        hx: width * 0.90 - prog * (width * 0.80),
        hy: -30 + prog * (height + 60),
        txOffset: 60,
        tyOffset: -75,
      }),
      head: isDark ? [255, 255, 255] : [124, 58, 237],
      tail: isDark ? [167, 139, 250] : [217, 119, 6],
      radius: 3.0,
      progOffset: 0.25,
    },
    // Comet 4: Steep Upper-Left to Lower-Right
    {
      calc: (prog) => ({
        hx: width * 0.15 + prog * (width * 0.75),
        hy: -30 + prog * (height + 60),
        txOffset: -55,
        tyOffset: -75,
      }),
      head: isDark ? [255, 255, 255] : [217, 119, 6],
      tail: isDark ? [245, 158, 11] : [2, 132, 199],
      radius: 3.2,
      progOffset: 0.75,
    },
  ];

  const activeCount = Math.min(Math.max(count, 1), 4);

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

    for (let c = 0; c < activeCount; c++) {
      const def = cometDefs[c];
      const prog = (progress + def.progOffset) % 1.0;
      const { hx, hy, txOffset, tyOffset } = def.calc(prog);
      const tx = hx + txOffset;
      const ty = hy + tyOffset;
      drawComet(data, width, height, hx, hy, tx, ty, def.head, def.tail, def.radius);

      // Trailing sparks
      for (let s = 1; s <= 5; s++) {
        const sx = hx + (txOffset / 36) * s * 6 + Math.sin(progress * 10 + s + c) * 4;
        const sy = hy + (tyOffset / 36) * s * 6 + Math.cos(progress * 10 + s + c) * 4;
        drawDot(data, width, height, sx, sy, 1.4, isDark ? [253, 230, 138] : [2, 132, 199], 0.80);
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
// 4. SEAMLESS STARFIELD BACKGROUND TILE (300x300)
// ========================================================
function createSeamlessStarsTile({ width = 300, height = 300, isDark = true, totalFrames = 14, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  // 36 stars with modulo wrapping so the tile repeats infinitely and seamlessly
  const tileStars = [];
  for (let i = 0; i < 36; i++) {
    tileStars.push({
      x: (i * 73 + 17) % width,
      y: (i * 127 + 29) % height,
      r: (i % 3 === 0) ? 2.1 : ((i % 2 === 0) ? 1.6 : 1.0),
      phase: (i * 0.45) % (Math.PI * 2),
      mod: i % 5,
    });
  }

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

    for (const s of tileStars) {
      const twinkle = 0.35 + 0.65 * Math.abs(Math.sin(progress * Math.PI * 2 + s.phase));
      let starColor;
      if (s.mod === 0) starColor = isDark ? [245, 158, 11] : [217, 119, 6];
      else if (s.mod === 1) starColor = isDark ? [255, 255, 255] : [2, 132, 199];
      else if (s.mod === 2) starColor = isDark ? [56, 189, 248] : [3, 105, 161];
      else if (s.mod === 3) starColor = isDark ? [16, 185, 129] : [4, 120, 87];
      else starColor = isDark ? [167, 139, 250] : [109, 40, 217];

      drawDot(data, width, height, s.x, s.y, s.r * (0.85 + 0.25 * twinkle), starColor, twinkle);
    }

    const palette = quantize(data, 32);
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

  console.log('Generating full-canvas and starfield assets in:', outDir);

  // 1. Seamless Starfield Tiles (for 100% monitor coverage with no empty void)
  console.log('  Generating seamless starfield tiles...');
  const starTileDark = createSeamlessStarsTile({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'stars-tile-dark.gif'), starTileDark);
  const starTileLight = createSeamlessStarsTile({ isDark: false });
  fs.writeFileSync(path.join(outDir, 'stars-tile-light.gif'), starTileLight);

  // 2. Black Hole Canvases for Count = 1, 2, 3, 4
  console.log('  Generating blackhole count variants (c1, c2, c3, c4)...');
  for (let c = 1; c <= 4; c++) {
    const d = createBlackHoleCanvas({ count: c, isDark: true });
    fs.writeFileSync(path.join(outDir, `blackhole-c${c}-dark.gif`), d);
    const l = createBlackHoleCanvas({ count: c, isDark: false });
    fs.writeFileSync(path.join(outDir, `blackhole-c${c}-light.gif`), l);
    if (c === 4) {
      // Default alias
      fs.writeFileSync(path.join(outDir, 'blackhole-sky-dark.gif'), d);
      fs.writeFileSync(path.join(outDir, 'blackhole-sky-light.gif'), l);
    }
  }

  // 3. Nebula Canvases for Count = 1, 2, 3, 4
  console.log('  Generating nebula count variants (c1, c2, c3, c4)...');
  for (let c = 1; c <= 4; c++) {
    const d = createNebulaCanvas({ count: c, isDark: true });
    fs.writeFileSync(path.join(outDir, `nebula-c${c}-dark.gif`), d);
    const l = createNebulaCanvas({ count: c, isDark: false });
    fs.writeFileSync(path.join(outDir, `nebula-c${c}-light.gif`), l);
    if (c === 4) {
      // Default alias
      fs.writeFileSync(path.join(outDir, 'nebula-sky-dark.gif'), d);
      fs.writeFileSync(path.join(outDir, 'nebula-sky-light.gif'), l);
    }
  }

  // 4. Comet Canvases for Count = 1, 2, 3, 4
  console.log('  Generating comet count variants (c1, c2, c3, c4)...');
  for (let c = 1; c <= 4; c++) {
    const d = createCosmicSkyCanvas({ count: c, isDark: true });
    fs.writeFileSync(path.join(outDir, `cosmic-c${c}-dark.gif`), d);
    const l = createCosmicSkyCanvas({ count: c, isDark: false });
    fs.writeFileSync(path.join(outDir, `cosmic-c${c}-light.gif`), l);
    if (c === 2) {
      // Default alias
      fs.writeFileSync(path.join(outDir, 'cosmic-sky-dark.gif'), d);
      fs.writeFileSync(path.join(outDir, 'cosmic-sky-light.gif'), l);
    }
  }

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

console.log('All Cosmic Backdrops & Count Variants generated successfully!');
