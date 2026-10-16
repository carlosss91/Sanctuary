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

// 1. TILEABLE FULL-SCREEN COSMIC SKY (Pure, serene starry universe with NO repetitive comets)
function createCosmicSkyTile({ width = 480, height = 480, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  // 50 carefully distributed twinkling stars across the tile (calm, asynchronous, elegant)
  const stars = [
    { x: 30, y: 40, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.1 },
    { x: 75, y: 90, r: 2.6, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.4 },
    { x: 120, y: 35, r: 1.6, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.7 },
    { x: 165, y: 110, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.8 },
    { x: 210, y: 45, r: 1.8, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.2 },
    { x: 260, y: 80, r: 2.8, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.9 },
    { x: 310, y: 30, r: 1.9, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.1 },
    { x: 360, y: 105, r: 2.5, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.3 },
    { x: 410, y: 50, r: 1.7, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.5 },
    { x: 450, y: 95, r: 2.3, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 3.7 },

    { x: 45, y: 160, r: 1.9, color: isDark ? [167, 139, 250] : [124, 58, 237], phase: 1.1 },
    { x: 95, y: 210, r: 2.4, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 2.9 },
    { x: 140, y: 175, r: 1.5, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.3 },
    { x: 190, y: 230, r: 2.7, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 3.5 },
    { x: 240, y: 165, r: 2.0, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 1.6 },
    { x: 290, y: 220, r: 1.8, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 4.3 },
    { x: 340, y: 170, r: 2.5, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 2.0 },
    { x: 390, y: 225, r: 1.9, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.7 },
    { x: 440, y: 180, r: 2.3, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 3.0 },

    { x: 35, y: 280, r: 2.1, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 1.8 },
    { x: 80, y: 340, r: 2.6, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 3.6 },
    { x: 130, y: 295, r: 1.7, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 0.9 },
    { x: 175, y: 350, r: 2.3, color: isDark ? [245, 158, 11] : [2, 132, 199], phase: 2.4 },
    { x: 225, y: 300, r: 1.9, color: isDark ? [56, 189, 248] : [124, 58, 237], phase: 4.5 },
    { x: 275, y: 360, r: 2.8, color: isDark ? [255, 255, 255] : [217, 119, 6], phase: 1.3 },
    { x: 325, y: 305, r: 1.6, color: isDark ? [167, 139, 250] : [124, 58, 237], phase: 3.1 },
    { x: 375, y: 355, r: 2.4, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.4 },
    { x: 425, y: 310, r: 2.0, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 2.8 },

    { x: 50, y: 410, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 1.5 },
    { x: 100, y: 450, r: 1.9, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 3.3 },
    { x: 150, y: 415, r: 2.5, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 0.6 },
    { x: 200, y: 455, r: 1.7, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 2.2 },
    { x: 250, y: 420, r: 2.3, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 4.0 },
    { x: 300, y: 450, r: 1.8, color: isDark ? [245, 158, 11] : [2, 132, 199], phase: 1.7 },
    { x: 350, y: 415, r: 2.7, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 3.8 },
    { x: 400, y: 455, r: 2.0, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 0.2 },
    { x: 445, y: 420, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 2.5 },
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

    // 2. Draw Tranquil Twinkling Stars (No repetitive comets in the tileable background!)
    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, s.color, curAlpha);
    }

    const palette = quantize(data, 32);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

// 2. EXPANSIVE BORDERLESS CANOPY (560x90 px) with 1 Single Majestic, Elegant Shooting Comet
function createCosmicBanner({ width = 560, height = 90, isDark = true, totalFrames = 24, delay = 110 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const stars = [
    { x: 35, y: 35, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0 },
    { x: 75, y: 22, r: 2.8, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.2 },
    { x: 120, y: 55, r: 1.8, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.5 },
    { x: 165, y: 28, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.8 },
    { x: 215, y: 65, r: 1.8, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.1 },
    { x: 260, y: 20, r: 2.6, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.7 },
    { x: 310, y: 52, r: 2.0, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.0 },
    { x: 360, y: 25, r: 2.9, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.1 },
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

    // Twinkling canopy stars
    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, s.color, curAlpha);
    }

    // 1 Single Majestic Shooting Comet with long, elegant trajectory & natural pause
    // Only visible during the first 65% of the loop, then leaves peaceful night sky
    const cometActive = progress < 0.65;
    if (cometActive) {
      const t = progress / 0.65;
      const hx = -40 + t * (width + 120);
      const hy = 12 + t * 48;
      const tx = hx - 90; // Long elegant tail (90px)
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

// 3. WIDE LATERAL CELESTIAL GUTTERS (110x650 px, pure calm twinkling star columns)
function createSideStars({ width = 110, height = 650, isDark = true, totalFrames = 24, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const stars = [
    { x: 25, y: 25, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.2 },
    { x: 75, y: 55, r: 2.6, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.5 },
    { x: 35, y: 85, r: 1.8, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.8 },
    { x: 80, y: 120, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.9 },
    { x: 30, y: 155, r: 1.9, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.4 },
    { x: 70, y: 190, r: 2.8, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.8 },
    { x: 25, y: 225, r: 2.1, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.1 },
    { x: 80, y: 260, r: 2.5, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.3 },
    { x: 35, y: 295, r: 1.9, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.6 },
    { x: 75, y: 330, r: 2.7, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 3.2 },
    { x: 25, y: 365, r: 2.0, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 1.4 },
    { x: 85, y: 400, r: 2.6, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.4 },
    { x: 30, y: 435, r: 1.9, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.1 },
    { x: 80, y: 470, r: 2.7, color: isDark ? [253, 230, 138] : [2, 132, 199], phase: 0.5 },
    { x: 35, y: 505, r: 2.2, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 3.7 },
    { x: 75, y: 540, r: 2.4, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 1.1 },
    { x: 25, y: 575, r: 2.0, color: isDark ? [245, 158, 11] : [2, 132, 199], phase: 2.9 },
    { x: 80, y: 610, r: 2.7, color: isDark ? [255, 255, 255] : [5, 150, 105], phase: 0.3 },
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
      const curRadius = s.r * (0.8 + 0.35 * pulse);
      const curAlpha = 0.35 + 0.65 * pulse;
      drawDot(data, width, height, s.x, s.y, curRadius, s.color, curAlpha);
    }

    const palette = quantize(data, 32);
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
