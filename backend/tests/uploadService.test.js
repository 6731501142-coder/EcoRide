const fs = require('fs');
const os = require('os');
const path = require('path');
const { saveImage, removeImage, detectImageType } = require('../src/services/uploadService');

const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
// หัวไฟล์ JPEG / WebP จริง (พอสำหรับตรวจ magic bytes)
const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]).toString('base64');
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.from([0x1a, 0, 0, 0]), Buffer.from('WEBPVP8 ')]).toString('base64');
let dir;
beforeEach(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'eco-up-')); });
afterEach(() => { fs.rmSync(dir, { recursive: true, force: true }); });

describe('saveImage', () => {
  test('saves the file and returns a /uploads/ url', () => {
    const url = saveImage({ imageBase64: PNG, mime: 'image/png', prefix: 'avatar-1' }, dir);
    expect(url).toMatch(/^\/uploads\/avatar-1-[0-9a-f]{16}\.png$/);
    expect(fs.existsSync(path.join(dir, path.basename(url)))).toBe(true);
  });
  test('accepts a full data URL', () => {
    expect(saveImage({ imageBase64: `data:image/png;base64,${PNG}`, prefix: 'station-2' }, dir)).toMatch(/\.png$/);
  });
  test('jpeg -> .jpg, webp -> .webp', () => {
    expect(saveImage({ imageBase64: JPEG, mime: 'image/jpeg', prefix: 'a' }, dir)).toMatch(/\.jpg$/);
    expect(saveImage({ imageBase64: WEBP, mime: 'image/webp', prefix: 'a' }, dir)).toMatch(/\.webp$/);
  });
  test('extension follows the real content, not the mime the app sent', () => {
    expect(saveImage({ imageBase64: PNG, mime: 'image/jpeg', prefix: 'a' }, dir)).toMatch(/\.png$/);
  });
  test('rejects files that only pretend to be images', () => {
    const fakes = [
      Buffer.from('hello').toString('base64'),
      Buffer.from('<svg onload="alert(1)"></svg>').toString('base64'),
      Buffer.from('<html><script>alert(1)</script></html>').toString('base64'),
      Buffer.from('GIF89a').toString('base64'),
    ];
    for (const imageBase64 of fakes) {
      expect(() => saveImage({ imageBase64, mime: 'image/png', prefix: 'a' }, dir))
        .toThrow('This file is not a valid PNG, JPEG or WebP image');
    }
    expect(fs.readdirSync(dir)).toHaveLength(0); // nothing was written
  });
  test('detectImageType', () => {
    expect(detectImageType(Buffer.from(PNG, 'base64'))).toBe('image/png');
    expect(detectImageType(Buffer.from(JPEG, 'base64'))).toBe('image/jpeg');
    expect(detectImageType(Buffer.from(WEBP, 'base64'))).toBe('image/webp');
    expect(detectImageType(Buffer.from('RIFF0000WAVE'))).toBeNull();
    expect(detectImageType(Buffer.alloc(0))).toBeNull();
  });
  test('rejects other types (svg / gif / pdf can hide scripts)', () => {
    for (const mime of ['image/svg+xml', 'image/gif', 'application/pdf', '', undefined]) {
      expect(() => saveImage({ imageBase64: PNG, mime, prefix: 'a' }, dir)).toThrow('Only PNG, JPEG or WebP images are allowed');
    }
  });
  test('rejects an empty image', () => {
    expect(() => saveImage({ imageBase64: '', mime: 'image/png', prefix: 'a' }, dir)).toThrow('Image is empty');
    expect(() => saveImage({ imageBase64: undefined, mime: 'image/png', prefix: 'a' }, dir)).toThrow('Image is empty');
  });
  test('rejects an image over 2 MB', () => {
    const big = Buffer.alloc(2 * 1024 * 1024 + 1, 1).toString('base64');
    expect(() => saveImage({ imageBase64: big, mime: 'image/png', prefix: 'a' }, dir)).toThrow('Image is too large (max 2 MB)');
  });
  test('creates the folder if it does not exist', () => {
    const sub = path.join(dir, 'new', 'folder');
    saveImage({ imageBase64: PNG, mime: 'image/png', prefix: 'a' }, sub);
    expect(fs.readdirSync(sub)).toHaveLength(1);
  });
});

describe('removeImage', () => {
  test('deletes a saved image', () => {
    const url = saveImage({ imageBase64: PNG, mime: 'image/png', prefix: 'a' }, dir);
    removeImage(url, dir);
    expect(fs.readdirSync(dir)).toHaveLength(0);
  });
  test('never throws (missing file, null, other url)', () => {
    expect(() => removeImage('/uploads/nothing.png', dir)).not.toThrow();
    expect(() => removeImage(null, dir)).not.toThrow();
    expect(() => removeImage('https://example.com/x.png', dir)).not.toThrow();
  });
  test('cannot delete outside the uploads folder ("../" is stripped)', () => {
    const outside = path.join(path.dirname(dir), `outside-${path.basename(dir)}.txt`);
    fs.writeFileSync(outside, 'keep me');
    removeImage(`/uploads/../${path.basename(outside)}`, dir);
    expect(fs.existsSync(outside)).toBe(true);
    fs.unlinkSync(outside);
  });
});
