import sharp from 'sharp';
import { promises as fs } from 'fs';

const INPUT = 'assets/images/YNFNY_Logo-1753709879889.png';
const OUTPUT_PNG = 'assets/images/ynfny_logo_compressed.png';
const OUTPUT_WEBP = 'assets/images/ynfny_logo_compressed.webp';

console.log('🖼️  Compressing YNFNY logo...');

// Get input file stats
const inputStats = await fs.stat(INPUT);
console.log(`📊 Original size: ${(inputStats.size / 1024 / 1024).toFixed(2)} MB`);

// Compress as optimized PNG
await sharp(INPUT)
  .resize(2048, 2048, { fit: 'inside', withoutEnlargement: true })
  .png({ quality: 70, compressionLevel: 9 })
  .toFile(OUTPUT_PNG);

const pngStats = await fs.stat(OUTPUT_PNG);
console.log(`✅ Compressed PNG: ${(pngStats.size / 1024).toFixed(2)} KB`);

// Also create WebP version (usually smaller)
await sharp(INPUT)
  .resize(2048, 2048, { fit: 'inside', withoutEnlargement: true })
  .webp({ quality: 75 })
  .toFile(OUTPUT_WEBP);

const webpStats = await fs.stat(OUTPUT_WEBP);
console.log(`✅ Compressed WebP: ${(webpStats.size / 1024).toFixed(2)} KB`);

console.log('🎉 Compression complete!');
