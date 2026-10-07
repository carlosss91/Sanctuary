const { GIFEncoder, quantize, applyPalette } = require('gifenc');
const fs = require('fs');
const path = require('path');

function createCosmicBanner({ width = 560, height = 75, isDark = true, totalFrames = 20, delay = 90 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240]; // #05080E or #D6E4F0

  // Fixed star positions and base sizes
  const stars = [
    { x: 35, y: 35, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0 },
    { x: 75, y: 18, r: 2.8, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.2 },
    { x: 120, y: 48, r: 2.0, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.5 },
    { x: 165, y: 22, r: 2.4, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.8 },
    { x: 215, y: 55, r: 1.8, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.1 },
    { x: 260, y: 15, r: 2.6, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.7 },
    { x: 310, y: 42, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.0 },
    { x: 360, y: 20, r: 3.0, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.1 },
    { x: 410, y: 52, r: 1.9, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.5 },
    { x: 460, y: 25, r: 2.5, color: isDark ? [16, 185, 129] : [217, 119, 6], phase: 3.6 },
    { x: 505, y: 45, r: 2.2, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.9 },
    { x: 535, y: 20, r: 1.8, color: isDark ? [245, 158, 11] : [124, 58, 237], phase: 4.5 },
    // Secondary faint background stars
    { x: 95, y: 60, r: 1.2, color: isDark ? [255, 255, 255] : [100, 116, 139], phase: 2.0 },
    { x: 185, y: 40, r: 1.3, color: isDark ? [253, 230, 138] : [100, 116, 139], phase: 3.5 },
    { x: 285, y: 62, r: 1.2, color: isDark ? [56, 189, 248] : [100, 116, 139], phase: 1.0 },
    { x: 385, y: 38, r: 1.4, color: isDark ? [245, 158, 11] : [100, 116, 139], phase: 4.8 },
    { x: 480, y: 58, r: 1.2, color: isDark ? [16, 185, 129] : [100, 116, 139], phase: 0.2 },
  ];

  for (let f = 0; f < totalFrames; f++) {
    const progress = f / totalFrames;
    // RGBA pixel buffer
    const data = new Uint8Array(width * height * 4);

    // 1. Fill background
    for (let i = 0; i < width * height; i++) {
      const idx = i * 4;
      data[idx] = bgColor[0];
      data[idx + 1] = bgColor[1];
      data[idx + 2] = bgColor[2];
      data[idx + 3] = 255;
    }

    // Helper: draw soft circle/dot
    function drawDot(cx, cy, radius, [r, g, b], alpha = 1.0) {
      const minX = Math.max(0, Math.floor(cx - radius * 1.5));
      const maxX = Math.min(width - 1, Math.ceil(cx + radius * 1.5));
      const minY = Math.max(0, Math.floor(cy - radius * 1.5));
      const maxY = Math.min(height - 1, Math.ceil(cy + radius * 1.5));

      for (let y = minY; y <= maxY; y++) {
        for (let x = minX; x <= maxX; x++) {
          const dist = Math.hypot(x - cx, y - cy);
          if (dist <= radius * 1.5) {
            const intensity = Math.max(0, Math.min(1, 1 - (dist / (radius * 1.5)))) * alpha;
            if (intensity > 0.05) {
              const idx = (y * width + x) * 4;
              data[idx] = Math.round(data[idx] * (1 - intensity) + r * intensity);
              data[idx + 1] = Math.round(data[idx + 1] * (1 - intensity) + g * intensity);
              data[idx + 2] = Math.round(data[idx + 2] * (1 - intensity) + b * intensity);
            }
          }
        }
      }
    }

    // Helper: draw comet with glowing tail
    function drawComet(hx, hy, tx, ty, headColor, tailColor, headRadius) {
      const steps = 30;
      for (let s = 0; s <= steps; s++) {
        const t = s / steps;
        const px = hx * (1 - t) + tx * t;
        const py = hy * (1 - t) + ty * t;
        const tailAlpha = (1 - t) * 0.85;
        const radius = headRadius * (1 - t * 0.65);
        const cr = Math.round(headColor[0] * (1 - t) + tailColor[0] * t);
        const cg = Math.round(headColor[1] * (1 - t) + tailColor[1] * t);
        const cb = Math.round(headColor[2] * (1 - t) + tailColor[2] * t);
        drawDot(px, py, radius, [cr, cg, cb], tailAlpha);
      }
      // Glowing incandescent nucleus
      drawDot(hx, hy, headRadius * 1.4, [255, 255, 255], 1.0);
    }

    // 2. Draw Twinkling Stars
    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.4 * pulse);
      const curAlpha = 0.4 + 0.6 * pulse;
      drawDot(s.x, s.y, curRadius, s.color, curAlpha);
    }

    // 3. Draw Shooting Comet 1 (Left to Right)
    // Starts at x: -40, ends at x: width + 60
    const c1Norm = (progress * 1.3) % 1.0;
    if (c1Norm < 0.75) {
      const t = c1Norm / 0.75;
      const hx = -30 + t * (width + 80);
      const hy = 12 + t * 45;
      const tx = hx - 55;
      const ty = hy - 25;
      const cometHead = isDark ? [255, 255, 255] : [2, 132, 199];
      const cometTail = isDark ? [16, 185, 129] : [5, 150, 105];
      drawComet(hx, hy, tx, ty, cometHead, cometTail, 3.2);
    }

    // 4. Draw Shooting Comet 2 (Right to Left)
    const c2Norm = ((progress + 0.5) * 1.1) % 1.0;
    if (c2Norm < 0.65) {
      const t = c2Norm / 0.65;
      const hx = (width + 30) - t * (width + 70);
      const hy = 15 + t * 40;
      const tx = hx + 48;
      const ty = hy - 20;
      const cometHead2 = [253, 230, 138];
      const cometTail2 = [245, 158, 11];
      drawComet(hx, hy, tx, ty, cometHead2, cometTail2, 2.6);
    }

    // Palette quantization & frame write
    const palette = quantize(data, 64);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

function createSideStars({ width = 70, height = 500, isDark = true, totalFrames = 18, delay = 100 }) {
  const gif = GIFEncoder();
  const bgColor = isDark ? [5, 8, 14] : [214, 228, 240];

  const stars = [
    { x: 25, y: 30, r: 2.4, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 0.2 },
    { x: 50, y: 75, r: 2.8, color: isDark ? [255, 255, 255] : [2, 132, 199], phase: 1.5 },
    { x: 20, y: 130, r: 2.0, color: isDark ? [56, 189, 248] : [5, 150, 105], phase: 2.8 },
    { x: 45, y: 180, r: 2.5, color: isDark ? [253, 230, 138] : [217, 119, 6], phase: 0.9 },
    { x: 25, y: 235, r: 1.8, color: isDark ? [16, 185, 129] : [2, 132, 199], phase: 3.4 },
    { x: 55, y: 290, r: 3.0, color: isDark ? [255, 255, 255] : [124, 58, 237], phase: 1.8 },
    { x: 22, y: 350, r: 2.2, color: isDark ? [245, 158, 11] : [217, 119, 6], phase: 4.1 },
    { x: 48, y: 405, r: 2.6, color: isDark ? [56, 189, 248] : [2, 132, 199], phase: 2.3 },
    { x: 28, y: 460, r: 2.0, color: isDark ? [253, 230, 138] : [5, 150, 105], phase: 0.6 },
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

    function drawDot(cx, cy, radius, [r, g, b], alpha = 1.0) {
      const minX = Math.max(0, Math.floor(cx - radius * 1.5));
      const maxX = Math.min(width - 1, Math.ceil(cx + radius * 1.5));
      const minY = Math.max(0, Math.floor(cy - radius * 1.5));
      const maxY = Math.min(height - 1, Math.ceil(cy + radius * 1.5));

      for (let y = minY; y <= maxY; y++) {
        for (let x = minX; x <= maxX; x++) {
          const dist = Math.hypot(x - cx, y - cy);
          if (dist <= radius * 1.5) {
            const intensity = Math.max(0, Math.min(1, 1 - (dist / (radius * 1.5)))) * alpha;
            if (intensity > 0.05) {
              const idx = (y * width + x) * 4;
              data[idx] = Math.round(data[idx] * (1 - intensity) + r * intensity);
              data[idx + 1] = Math.round(data[idx + 1] * (1 - intensity) + g * intensity);
              data[idx + 2] = Math.round(data[idx + 2] * (1 - intensity) + b * intensity);
            }
          }
        }
      }
    }

    for (const s of stars) {
      const pulse = 0.5 + 0.5 * Math.sin(progress * Math.PI * 2 + s.phase);
      const curRadius = s.r * (0.8 + 0.4 * pulse);
      const curAlpha = 0.4 + 0.6 * pulse;
      drawDot(s.x, s.y, curRadius, s.color, curAlpha);
    }

    const palette = quantize(data, 32);
    const index = applyPalette(data, palette);
    gif.writeFrame(index, width, height, { palette, delay });
  }

  gif.finish();
  return Buffer.from(gif.bytes());
}

const outDir = path.join(__dirname, '../assets');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

console.log('Generating cosmic animated GIFs...');

const bannerDark = createCosmicBanner({ isDark: true });
fs.writeFileSync(path.join(outDir, 'cosmic-banner-dark.gif'), bannerDark);
console.log('Created cosmic-banner-dark.gif:', bannerDark.length, 'bytes');

const bannerLight = createCosmicBanner({ isDark: false });
fs.writeFileSync(path.join(outDir, 'cosmic-banner-light.gif'), bannerLight);
console.log('Created cosmic-banner-light.gif:', bannerLight.length, 'bytes');

const sideDark = createSideStars({ isDark: true });
fs.writeFileSync(path.join(outDir, 'cosmic-side-dark.gif'), sideDark);
console.log('Created cosmic-side-dark.gif:', sideDark.length, 'bytes');

const sideLight = createSideStars({ isDark: false });
fs.writeFileSync(path.join(outDir, 'cosmic-side-light.gif'), sideLight);
console.log('Created cosmic-side-light.gif:', sideLight.length, 'bytes');

console.log('All GIFs generated successfully!');
