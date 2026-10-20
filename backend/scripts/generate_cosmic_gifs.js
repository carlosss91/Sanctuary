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
        if (intensity > 0.04) {
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
  const steps = 32;
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    const px = hx * (1 - t) + tx * t;
    const py = hy * (1 - t) + ty * t;
    const tailAlpha = (1 - t) * 0.88;
    const radius = headRadius * (1 - t * 0.70);
    const cr = Math.round(headColor[0] * (1 - t) + tailColor[0] * t);
    const cg = Math.round(headColor[1] * (1 - t) + tailColor[1] * t);
    const cb = Math.round(headColor[2] * (1 - t) + tailColor[2] * t);
    drawDot(data, width, height, px, py, radius, [cr, cg, cb], tailAlpha);
  }
  // Glowing incandescent nucleus
  drawDot(data, width, height, hx, hy, headRadius * 1.45, [255, 255, 255], 1.0);
}

// Shared celestial stars set (deterministic distribution)
const sharedSkyStars = [
  { x: 30, y: 40, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.1 },
  { x: 75, y: 90, r: 2.6, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 1.4 },
  { x: 120, y: 35, r: 1.6, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.7 },
  { x: 165, y: 110, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 0.8 },
  { x: 210, y: 45, r: 1.8, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 3.2 },
  { x: 260, y: 80, r: 2.8, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 1.9 },
  { x: 310, y: 30, r: 1.9, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.1 },
  { x: 360, y: 105, r: 2.5, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 2.3 },
  { x: 410, y: 50, r: 1.7, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.5 },
  { x: 450, y: 95, r: 2.3, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 3.7 },

  { x: 45, y: 160, r: 1.9, colorDark: [167, 139, 250], colorLight: [124, 58, 237], phase: 1.1 },
  { x: 95, y: 210, r: 2.4, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 2.9 },
  { x: 140, y: 175, r: 1.5, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.3 },
  { x: 190, y: 230, r: 2.7, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 3.5 },
  { x: 240, y: 165, r: 2.0, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 1.6 },
  { x: 290, y: 220, r: 1.8, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 4.3 },
  { x: 340, y: 170, r: 2.5, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 2.0 },
  { x: 390, y: 225, r: 1.9, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.7 },
  { x: 440, y: 180, r: 2.3, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 3.0 },

  { x: 35, y: 280, r: 2.1, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 1.8 },
  { x: 80, y: 340, r: 2.6, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 3.6 },
  { x: 130, y: 295, r: 1.7, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 0.9 },
  { x: 175, y: 350, r: 2.3, colorDark: [245, 158, 11], colorLight: [2, 132, 199], phase: 2.4 },
  { x: 225, y: 300, r: 1.9, colorDark: [56, 189, 248], colorLight: [124, 58, 237], phase: 4.5 },
  { x: 275, y: 360, r: 2.8, colorDark: [255, 255, 255], colorLight: [217, 119, 6], phase: 1.3 },
  { x: 325, y: 305, r: 1.6, colorDark: [167, 139, 250], colorLight: [124, 58, 237], phase: 3.1 },
  { x: 375, y: 355, r: 2.4, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.4 },
  { x: 425, y: 310, r: 2.0, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 2.8 },

  { x: 50, y: 410, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 1.5 },
  { x: 100, y: 450, r: 1.9, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 3.3 },
  { x: 150, y: 415, r: 2.5, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 0.6 },
  { x: 200, y: 455, r: 1.7, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 2.2 },
  { x: 250, y: 420, r: 2.3, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 4.0 },
  { x: 300, y: 450, r: 1.8, colorDark: [245, 158, 11], colorLight: [2, 132, 199], phase: 1.7 },
  { x: 350, y: 415, r: 2.7, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 3.8 },
  { x: 400, y: 455, r: 2.0, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 0.2 },
  { x: 445, y: 420, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 2.5 },
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
  { x: 95, y: 70, r: 1.3, colorDark: [255, 255, 255], colorLight: [100, 116, 139], phase: 2.0 },
  { x: 185, y: 50, r: 1.4, colorDark: [253, 230, 138], colorLight: [100, 116, 139], phase: 3.5 },
  { x: 285, y: 72, r: 1.3, colorDark: [56, 189, 248], colorLight: [100, 116, 139], phase: 1.0 },
  { x: 385, y: 48, r: 1.5, colorDark: [245, 158, 11], colorLight: [100, 116, 139], phase: 4.8 },
  { x: 480, y: 68, r: 1.3, colorDark: [16, 185, 129], colorLight: [100, 116, 139], phase: 0.2 },
];

const sharedSideStars = [
  { x: 25, y: 25, r: 2.2, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 0.2 },
  { x: 75, y: 55, r: 2.6, colorDark: [255, 255, 255], colorLight: [2, 132, 199], phase: 1.5 },
  { x: 35, y: 85, r: 1.8, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.8 },
  { x: 80, y: 120, r: 2.4, colorDark: [253, 230, 138], colorLight: [217, 119, 6], phase: 0.9 },
  { x: 30, y: 155, r: 1.9, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 3.4 },
  { x: 70, y: 190, r: 2.8, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 1.8 },
  { x: 25, y: 225, r: 2.1, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.1 },
  { x: 80, y: 260, r: 2.5, colorDark: [56, 189, 248], colorLight: [2, 132, 199], phase: 2.3 },
  { x: 35, y: 295, r: 1.9, colorDark: [253, 230, 138], colorLight: [5, 150, 105], phase: 0.6 },
  { x: 75, y: 330, r: 2.7, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 3.2 },
  { x: 25, y: 365, r: 2.0, colorDark: [16, 185, 129], colorLight: [2, 132, 199], phase: 1.4 },
  { x: 85, y: 400, r: 2.6, colorDark: [245, 158, 11], colorLight: [217, 119, 6], phase: 4.4 },
  { x: 30, y: 435, r: 1.9, colorDark: [56, 189, 248], colorLight: [5, 150, 105], phase: 2.1 },
  { x: 80, y: 470, r: 2.7, colorDark: [253, 230, 138], colorLight: [2, 132, 199], phase: 0.5 },
  { x: 35, y: 505, r: 2.2, colorDark: [255, 255, 255], colorLight: [124, 58, 237], phase: 3.7 },
  { x: 75, y: 540, r: 2.4, colorDark: [16, 185, 129], colorLight: [217, 119, 6], phase: 1.1 },
  { x: 25, y: 575, r: 2.0, colorDark: [245, 158, 11], colorLight: [2, 132, 199], phase: 2.9 },
  { x: 80, y: 610, r: 2.7, colorDark: [255, 255, 255], colorLight: [5, 150, 105], phase: 0.3 },
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

    for (const s of sharedSkyStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 32);
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
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const cometActive = progress < 0.65;
    if (cometActive) {
      const t = progress / 0.65;
      const hx = -40 + t * (width + 120);
      const hy = 12 + t * 48;
      const tx = hx - 90;
      const ty = hy - 32;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [56, 189, 248] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.2);
    }

    const palette = quantize(data, 40);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createSideStars({ width = 110, height = 650, isDark = true, totalFrames = 24, delay = 100 }) {
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

    for (const s of sharedSideStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 32);
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

    // Breathing pulse for nebula cloud layers
    const p1 = 0.85 + 0.25 * Math.sin(progress * Math.PI * 2);
    const p2 = 0.85 + 0.25 * Math.cos(progress * Math.PI * 2);

    // Nebula Layer 1: Ethereal Violet/Pink Cloud (upper left)
    drawNebulaGas(data, width, height, 110, 120, 130 * p1, 100 * p1, isDark ? [139, 92, 246] : [124, 58, 237], isDark ? 0.35 : 0.20);
    drawNebulaGas(data, width, height, 135, 145, 80 * p1, 65 * p1, isDark ? [236, 72, 153] : [219, 39, 119], isDark ? 0.28 : 0.16);

    // Nebula Layer 2: Emerald / Cyan Cloud (lower right)
    drawNebulaGas(data, width, height, 370, 360, 140 * p2, 110 * p2, isDark ? [16, 185, 129] : [5, 150, 105], isDark ? 0.32 : 0.18);
    drawNebulaGas(data, width, height, 345, 335, 85 * p2, 70 * p2, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.26 : 0.15);

    // Twinkling canopy stars
    for (const s of sharedSkyStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // Floating Stardust orbiting within nebula
    for (let i = 0; i < 12; i++) {
      const angle = progress * Math.PI * 2 + (i * Math.PI * 2) / 12;
      const ox = (i % 2 === 0 ? 110 : 370) + Math.cos(angle) * (35 + (i % 4) * 15);
      const oy = (i % 2 === 0 ? 120 : 360) + Math.sin(angle) * (25 + (i % 4) * 10);
      drawDot(data, width, height, ox, oy, 1.8, isDark ? [255, 255, 255] : [245, 158, 11], 0.65);
    }

    const palette = quantize(data, 48);
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

    // Drifting horizontal nebula veil across canopy
    const shift = Math.sin(progress * Math.PI * 2) * 25;
    drawNebulaGas(data, width, height, 140 + shift, 45, 160, 42, isDark ? [139, 92, 246] : [124, 58, 237], isDark ? 0.38 : 0.22);
    drawNebulaGas(data, width, height, 380 - shift, 45, 180, 40, isDark ? [16, 185, 129] : [5, 150, 105], isDark ? 0.34 : 0.20);
    drawNebulaGas(data, width, height, 260 + shift * 0.5, 45, 120, 36, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.25 : 0.16);

    for (const s of sharedBannerStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // Luminous drifting stardust
    for (let i = 0; i < 14; i++) {
      const px = ((progress + i / 14) % 1.0) * width;
      const py = 20 + Math.sin(progress * Math.PI * 2 + i) * 28;
      drawDot(data, width, height, px, py, 1.8, isDark ? [253, 230, 138] : [217, 119, 6], 0.75);
    }

    const palette = quantize(data, 48);
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
    drawNebulaGas(data, width, height, 55, 160 + p * 15, 55, 120, isDark ? [139, 92, 246] : [124, 58, 237], isDark ? 0.30 : 0.18);
    drawNebulaGas(data, width, height, 55, 450 - p * 15, 55, 130, isDark ? [16, 185, 129] : [5, 150, 105], isDark ? 0.28 : 0.16);

    for (const s of sharedSideStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 36);
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

    // Outer gravitational lensing ripples
    const p = Math.sin(progress * Math.PI * 2);
    drawNebulaGas(data, width, height, 240, 240, 180 + p * 10, 180 + p * 10, isDark ? [139, 92, 246] : [124, 58, 237], isDark ? 0.16 : 0.10);
    drawNebulaGas(data, width, height, 240, 240, 120 + p * 6, 120 + p * 6, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.18 : 0.12);

    // Stars drawn inward by gravitational curvature
    for (const s of sharedSkyStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 36);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createBlackHoleBanner({ width = 560, height = 90, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];
  const bhX = 430;
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
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    // 1. Gravitational lensing halo around black hole
    drawNebulaGas(data, width, height, bhX, bhY, 80, 50, isDark ? [139, 92, 246] : [124, 58, 237], isDark ? 0.38 : 0.20);
    drawNebulaGas(data, width, height, bhX, bhY, 65, 38, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.32 : 0.18);

    // 2. Relativistic rotating plasma accretion disk
    const diskSteps = 60;
    const rotBase = progress * Math.PI * 2;
    for (let i = 0; i < diskSteps; i++) {
      const theta = rotBase + (i * Math.PI * 2) / diskSteps;
      const rx = 44 + Math.sin(theta * 2) * 5;
      const ry = 16 + Math.cos(theta * 2) * 2;
      const px = bhX + Math.cos(theta) * rx;
      const py = bhY + Math.sin(theta) * ry;

      // Color sweep: Amber -> Cyan -> Crimson -> Amber
      const norm = (i / diskSteps);
      let plasmaColor;
      if (norm < 0.33) {
        plasmaColor = [245, 158, 11]; // Amber
      } else if (norm < 0.66) {
        plasmaColor = [56, 189, 248]; // Cyan
      } else {
        plasmaColor = [220, 38, 38]; // Crimson
      }
      drawDot(data, width, height, px, py, 2.8, plasmaColor, 0.85);
    }

    // 3. Infalling matter spiraling into event horizon
    for (let s = 0; s < 6; s++) {
      const streamProg = (progress + s / 6.0) % 1.0;
      const spiralAngle = rotBase * 1.5 + (s * Math.PI) / 3.0 + streamProg * Math.PI * 2;
      const dist = 14 + (1.0 - streamProg) * 36;
      const sx = bhX + Math.cos(spiralAngle) * dist;
      const sy = bhY + Math.sin(spiralAngle) * dist * 0.38;
      drawDot(data, width, height, sx, sy, 2.0 * streamProg + 0.6, [253, 230, 138], 0.9);
    }

    // 4. Luminous Photon Sphere Ring
    for (let a = 0; a < 36; a++) {
      const rad = (a * Math.PI * 2) / 36;
      const px = bhX + Math.cos(rad) * 14;
      const py = bhY + Math.sin(rad) * 14;
      drawDot(data, width, height, px, py, 1.8, [56, 189, 248], 0.95);
    }

    // 5. Pitch-black event horizon core
    for (let y = Math.max(0, bhY - 12); y <= Math.min(height - 1, bhY + 12); y++) {
      for (let x = Math.max(0, bhX - 12); x <= Math.min(width - 1, bhX + 12); x++) {
        if (Math.hypot(x - bhX, y - bhY) <= 12) {
          const idx = (y * width + x) * 4;
          data[idx] = 3;
          data[idx + 1] = 7;
          data[idx + 2] = 18;
          data[idx + 3] = 255;
        }
      }
    }

    const palette = quantize(data, 48);
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

    const p = Math.sin(progress * Math.PI * 2);
    drawNebulaGas(data, width, height, 55, 300 + p * 20, 55, 140, isDark ? [6, 182, 212] : [2, 132, 199], isDark ? 0.28 : 0.16);

    for (const s of sharedSideStars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, isDark ? s.colorDark : s.colorLight, curAlpha);
    }

    const palette = quantize(data, 36);
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

  const sideDark = createSideStars({ isDark: true });
  fs.writeFileSync(path.join(outDir, 'cosmic-side-dark.gif'), sideDark);
  console.log('  -> cosmic-side-dark.gif:', sideDark.length, 'bytes');

  const sideLight = createSideStars({ isDark: false });
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
