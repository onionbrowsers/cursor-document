#!/usr/bin/env node
/**
 * 将图片 URL 下载到 skill 临时目录，或清理该目录。
 * 用法：
 *   node download-image.js <图片URL>   → 下载并输出本地绝对路径
 *   node download-image.js --clean    → 删除本次会话下载的临时图片
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const SKILL_DIR = path.resolve(__dirname, '..');
const TEMP_DIR = path.join(SKILL_DIR, 'temp');

function getExtensionFromUrl(url) {
  try {
    const base = url.split('?')[0].toLowerCase();
    if (base.endsWith('.png')) return '.png';
    if (base.endsWith('.jpg') || base.endsWith('.jpeg')) return '.jpg';
    if (base.endsWith('.gif')) return '.gif';
    if (base.endsWith('.webp')) return '.webp';
  } catch (_) {}
  return '.png';
}

function download(url) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    protocol.get(url, { timeout: 15000 }, (res) => {
      const code = res.statusCode;
      if (code === 301 || code === 302) {
        const location = res.headers['location'];
        if (location) return download(location).then(resolve).catch(reject);
        return reject(new Error(`Redirect without Location header`));
      }
      if (code !== 200) {
        reject(new Error(`HTTP ${code}`));
        return;
      }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function main() {
  const args = process.argv.slice(2);
  if (args[0] === '--clean') {
    if (!fs.existsSync(TEMP_DIR)) {
      process.stdout.write('OK: no temp files\n');
      return;
    }
    const files = fs.readdirSync(TEMP_DIR).filter((f) => f !== '.gitkeep');
    for (const f of files) {
      fs.unlinkSync(path.join(TEMP_DIR, f));
    }
    process.stdout.write('OK: cleaned\n');
    return;
  }

  const url = args[0];
  if (!url || url.startsWith('--')) {
    process.stderr.write('Usage: node download-image.js <image_url> | --clean\n');
    process.exit(1);
  }

  if (!fs.existsSync(TEMP_DIR)) {
    fs.mkdirSync(TEMP_DIR, { recursive: true });
  }

  const ext = getExtensionFromUrl(url);
  const name = `img_${Date.now()}_${Math.random().toString(36).slice(2, 8)}${ext}`;
  const filePath = path.join(TEMP_DIR, name);

  try {
    const buf = await download(url);
    fs.writeFileSync(filePath, buf);
    process.stdout.write(path.resolve(filePath) + '\n');
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\n`);
    process.exit(1);
  }
}

main();
