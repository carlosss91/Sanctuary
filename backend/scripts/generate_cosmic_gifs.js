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

// 1. TILEABLE FULL-SCREEN COSMIC SKY (Tiles seamlessly across 100% of any widescreen monitor)
function createCosmicSkyTile({ width = 480, height = 480, isDark = true, totalFrames = 20, delay = 90 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  // 60 twinkling stars carefully placed across the tile (keeping margins away from boundaries to prevent clipping)
  const stars = [
    { x: 30, y: 40, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.1 },
    { x: 75, y: 90, r: 2.6, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.4 },
    { x: 120, y: 35, r: 1.8, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.7 },
    { x: 165, y: 110, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.8 },
    { x: 210, y: 45, r: 2.0, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.2 },
    { x: 260, y: 80, r: 2.8, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.9 },
    { x: 310, y: 30, r: 2.1, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.1 },
    { x: 360, y: 105, r: 2.7, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.3 },
    { x: 410, y: 50, r: 1.9, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.5 },
    { x: 450, y: 95, r: 2.5, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 3.7 },

    { x: 45, y: 160, r: 2.0, color: isDark ? [167, 139, 250] : [124, 58, 237], phase: 1.1 },
    { x: 95, y: 210, r: 2.5, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 2.9 },
    { x: 140, y: 175, r: 1.7, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.3 },
    { x: 190, y: 230, r: 2.8, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 3.5 },
    { x: 240, y: 165, r: 2.2, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 1.6 },
    { x: 290, y: 220, r: 1.9, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 4.3 },
    { x: 340, y: 170, r: 2.6, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 2.0 },
    { x: 390, y: 225, r: 2.1, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.7 },
    { x: 440, y: 180, r: 2.4, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 3.0 },

    { x: 35, y: 280, r: 2.3, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 1.8 },
    { x: 80, y: 340, r: 2.7, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 3.6 },
    { x: 130, y: 295, r: 1.9, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 0.9 },
    { x: 175, y: 350, r: 2.5, color: isDark ? [245, 158, 11] : [2, 132, 199], phase: 2.4 },
    { x: 225, y: 300, r: 2.1, color: isDark ? [56, 189, 248] : [124, 58, 237], phase: 4.5 },
    { x: 275, y: 360, r: 2.9, color: isDark ? [255, 255, 255] : [217, 119, 6], phase: 1.3 },
    { x: 325, y: 305, r: 1.8, color: isDark ? [167, 139, 250] : [124, 58, 237], phase: 3.1 },
    { x: 375, y: 355, r: 2.6, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.4 },
    { x: 425, y: 310, r: 2.2, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 2.8 },

    { x: 50, y: 410, r: 2.4, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 1.5 },
    { x: 100, y: 450, r: 2.1, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 3.3 },
    { x: 150, y: 415, r: 2.7, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 0.6 },
    { x: 200, y: 455, r: 1.9, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 2.2 },
    { x: 250, y: 420, r: 2.5, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 4.0 },
    { x: 300, y: 450, r: 2.0, color: isDark ? [245, 158, 11] : [2, 132, 199], phase: 1.7 },
    { x: 350, y: 415, r: 2.8, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 3.8 },
    { x: 400, y: 455, r: 2.2, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 0.2 },
    { x: 445, y: 420, r: 2.6, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 2.5 },
  ];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    const data = new Uint8Array(width * height * 4);

    // 1. Fill solid cosmic background
    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // 2. Draw Twinkling Stars
    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.45 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, s.color, curAlpha);
    }

    // 3. Draw Shooting Comet 1 (Sweeping across upper sky)
    const c1Norm = (progress * 1.35) % 1.0;
    if (c1Norm < 0.70) {
      const t = c1Norm / 0.70;
      const hx = -35 + t * (width + 90);
      const hy = 20 + t * 90;
      const tx = hx - 60;
      const ty = hy - 26;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [56, 189, 248] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.2);
    }

    // 4. Draw Shooting Comet 2 (Sweeping across lower sky)
    const c2Norm = ((progress + 0.52) * 1.25) % 1.0;
    if (c2Norm < 0.65) {
      const t = c2Norm / 0.65;
      const hx = (width + 35) - t * (width + 90);
      const hy = 250 + t * 110;
      const tx = hx + 55;
      const ty = hy - 24;
      const cometHead2 = [253, 230, 138];
      const cometTail2 = [245, 158, 11];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead2, cometTail2, 2.8);
    }

    const palette = quantize(data, 48);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// 2. EXPANSIVE BORDERLESS TOP CANOPY (560x90 px)
function createCosmicBanner({ width = 560, height = 90, isDark = true, totalFrames = 20, delay = 90 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const stars = [
    { x: 35, y: 35, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0 },
    { x: 75, y: 22, r: 2.8, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.2 },
    { x: 120, y: 55, r: 2.0, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.5 },
    { x: 165, y: 28, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.8 },
    { x: 215, y: 65, r: 1.8, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.1 },
    { x: 260, y: 20, r: 2.6, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.7 },
    { x: 310, y: 52, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.0 },
    { x: 360, y: 25, r: 3.0, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.1 },
    { x: 410, y: 62, r: 1.9, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.5 },
    { x: 460, y: 30, r: 2.5, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 3.6 },
    { x: 505, y: 55, r: 2.2, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.9 },
    { x: 535, y: 25, r: 1.8, color: isDark ? [245, 158, 11] : [124, 58, 237], phase: 4.5 },
    { x: 95, y: 70, r: 1.3, color: isDark ? [255, 255, 255] : [100, 116, 139], phase: 2.0 },
    { x: 185, y: 50, r: 1.4, color: isDark ? [253, 230, 138] : [100, 116, 139], phase: 3.5 },
    { x: 285, y: 72, r: 1.3, color: isDark ? [56, 189, 248] : [100, 116, 139], phase: 1.0 },
    { x: 385, y: 48, r: 1.5, color: isDark ? [245, 158, 11] : [100, 116, 139], phase: 4.8 },
    { x: 480, y: 68, r: 1.3, color: isDark ? [16, 185, 129] : [100, 116, 139], phase: 0.2 },
  ];

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

    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.4 * pulse);
      const curAlpha = 0.4 + 0.6 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, s.color, curAlpha);
    }

    const c1Norm = (progress * 1.3) % 1.0;
    if (c1Norm < 0.75) {
      const t = c1Norm / 0.75;
      const hx = -30 + t * (width + 80);
      const hy = 18 + t * 45;
      const tx = hx - 55;
      const ty = hy - 25;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [16, 185, 129] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 3.2);
    }

    const c2Norm = ((progress + 0.5) * 1.1) % 1.0;
    if (c2Norm < 0.65) {
      const t = c2Norm / 0.65;
      const hx = (width + 30) - t * (width + 70);
      const hy = 22 + t * 40;
      const tx = hx + 48;
      const ty = hy - 20;
      const cometHead2 = [253, 230, 138];
      const cometTail2 = [245, 158, 11];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead2, cometTail2, 2.6);
    }

    const palette = quantize(data, 48);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// 3. WIDE LATERAL CELESTIAL GUTTERS (110x650 px, double column of stars with comets)
function createSideStars({ width = 110, height = 650, isDark = true, totalFrames = 20, delay = 90 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const stars = [
    { x: 25, y: 25, r: 2.4, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.2 },
    { x: 75, y: 50, r: 2.8, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.5 },
    { x: 35, y: 75, r: 2.0, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.8 },
    { x: 85, y: 105, r: 2.5, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.9 },
    { x: 30, y: 135, r: 1.9, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.4 },
    { x: 70, y: 165, r: 3.0, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.8 },
    { x: 25, y: 200, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.1 },
    { x: 80, y: 230, r: 2.6, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.3 },
    { x: 35, y: 260, r: 2.1, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.6 },
    { x: 75, y: 290, r: 2.9, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 3.2 },
    { x: 25, y: 325, r: 2.2, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 1.4 },
    { x: 85, y: 355, r: 2.7, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.4 },
    { x: 30, y: 390, r: 2.0, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.1 },
    { x: 80, y: 420, r: 2.8, color: isDark ? [253, 230, 138] : [2, 132, 199], phase: 0.5 },
    { x: 35, y: 455, r: 2.3, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 3.7 },
    { x: 75, y: 485, r: 2.5, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 1.1 },
    { x: 25, y: 520, r: 2.1, color: isDark ? [245, 158, 11] : [2, 132, 199], phase: 2.9 },
    { x: 85, y: 550, r: 2.9, color: isDark ? [255, 255, 255] : [5, 150, 105], phase: 0.3 },
    { x: 30, y: 585, r: 2.0, color: isDark ? [56, 189, 248] : [124, 58, 237], phase: 4.2 },
    { x: 75, y: 615, r: 2.6, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 1.7 },
  ];

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

    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.45 * pulse);
      const curAlpha = 0.4 + 0.6 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, s.color, curAlpha);
    }

    // Occasional mini comet sweep on the side strip
    const sNorm = (progress * 1.35) % 1.0;
    if (sNorm < 0.65) {
      const t = sNorm / 0.65;
      const hx = (width + 15) - t * (width + 35);
      const hy = 160 + t * 85;
      const tx = hx + 36;
      const ty = hy - 16;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [56, 189, 248] : [5, 150, 105];
      drawComet(data, width, height, hx, hy, tx, ty, cometHead, cometTail, 2.3);
    }

    const palette = quantize(data, 40);
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

  console.log('Generating cosmic assets in:', outDir);

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
}

console.log('All Cosmic GIFs generated successfully!');
