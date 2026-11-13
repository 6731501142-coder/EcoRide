// Saves a base64 image (profile photo / station photo) into the uploads folder
// and returns the URL path to store in users.avatar_url / stations.photo_url.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const config = require('../config');
const { badRequest } = require('../utils/errors');

const EXT = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' };

/**
 * ดูชนิดรูปจาก "เนื้อไฟล์" (magic bytes) ไม่เชื่อชนิดที่แอปบอกมา
 * คืน 'image/png' | 'image/jpeg' | 'image/webp' หรือ null ถ้าไม่ใช่รูปที่รองรับ
 */
function detectImageType(buf) {
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.length >= 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return 'image/webp';
  }
  return null;
}

function saveImage({ imageBase64, mime, prefix }, dir = config.uploadDir) {
  let data = String(imageBase64 ?? '');
  let type = String(mime ?? '').toLowerCase();

  // allow a full data URL: "data:image/png;base64,AAAA..."
  const m = data.match(/^data:([\w/+.-]+);base64,(.*)$/s);
  if (m) {
    type = type || m[1].toLowerCase();
    data = m[2];
  }
  if (!EXT[type]) throw badRequest('Only PNG, JPEG or WebP images are allowed');
  if (!data) throw badRequest('Image is empty');

  const buf = Buffer.from(data, 'base64');
  if (buf.length === 0) throw badRequest('Image is empty');
  if (buf.length > config.maxImageBytes) throw badRequest('Image is too large (max 2 MB)');

  // เนื้อไฟล์ต้องเป็นรูปจริง (กันไฟล์อื่นที่แอบตั้งชื่อเป็น .png)
  const actual = detectImageType(buf);
  if (!actual) throw badRequest('This file is not a valid PNG, JPEG or WebP image');

  fs.mkdirSync(dir, { recursive: true });
  // นามสกุลไฟล์ใช้ตามชนิดจริงจากเนื้อไฟล์
  const name = `${prefix}-${crypto.randomBytes(8).toString('hex')}.${EXT[actual]}`;
  fs.writeFileSync(path.join(dir, name), buf);
  return `/uploads/${name}`;
}

/** best effort: delete an old image that this service saved. Never throws. */
function removeImage(url, dir = config.uploadDir) {
  try {
    if (!url || !String(url).startsWith('/uploads/')) return;
    const file = path.basename(url); // basename blocks "../" tricks
    fs.unlinkSync(path.join(dir, file));
  } catch {
    /* already gone */
  }
}

module.exports = { saveImage, removeImage, detectImageType };
