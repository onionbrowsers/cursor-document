#!/usr/bin/env node
/**
 * 从 docx_v1_documentBlock_list 接口返回的 JSON 中提取图片素材 file_token。
 * 用法：
 *   node extract-image-file-tokens.js <api-response.json>
 *   cat api-response.json | node extract-image-file-tokens.js
 *
 * 输出：每行一个 token，供分批调用 drive_v1_media_batchGetTmpDownloadUrl（每批最多 5 个）。
 */

const fs = require('fs');

const inputPath = process.argv[2];

const readInput = () => {
  if (inputPath && inputPath !== '-') {
    return fs.readFileSync(inputPath, 'utf8');
  }
  return fs.readFileSync(0, 'utf8');
};

const main = () => {
  const raw = readInput().trim();
  if (!raw) {
    process.stderr.write('错误：无输入 JSON\n');
    process.exit(1);
  }
  const parsed = JSON.parse(raw);
  const items = parsed.data?.items ?? parsed.items ?? [];
  const tokens = items
    .filter((b) => b.block_type === 27 && b.image?.token)
    .map((b) => b.image.token);
  tokens.forEach((t) => console.log(t));
};

main();
