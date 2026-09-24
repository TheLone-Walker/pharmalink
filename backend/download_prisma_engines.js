const fs = require('fs');
const path = require('path');
const https = require('https');
const zlib = require('zlib');

const COMMIT = '605197351a3c8bdd595af2d2a9bc3025bca48ea2';
const targetDir = path.join(__dirname, 'node_modules/@prisma/engines');

const targets = [
  {
    url: `https://binaries.prisma.sh/all_commits/${COMMIT}/windows/query_engine.dll.node.gz`,
    dest: path.join(targetDir, 'query_engine-windows.dll.node'),
  },
  {
    url: `https://binaries.prisma.sh/all_commits/${COMMIT}/windows/schema-engine.exe.gz`,
    dest: path.join(targetDir, 'schema-engine-windows.exe'),
  },
];

function downloadFile({ url, dest }) {
  return new Promise((resolve, reject) => {
    if (fs.existsSync(dest) && fs.statSync(dest).size > 1000000) {
      console.log(`[ALREADY EXISTS] ${path.basename(dest)}`);
      return resolve();
    }

    const tempGz = dest + '.tmp.gz';
    const tempDest = dest + '.tmp';
    console.log(`[START] Downloading ${path.basename(dest)}...`);

    const file = fs.createWriteStream(tempGz);
    https.get(url, (res) => {
      if (res.statusCode !== 200) {
        return reject(new Error(`Failed with status ${res.statusCode} for ${url}`));
      }
      const total = parseInt(res.headers['content-length'] || '0', 10);
      let downloaded = 0;
      let lastReport = Date.now();

      res.on('data', (chunk) => {
        downloaded += chunk.length;
        if (Date.now() - lastReport > 5000 || downloaded === total) {
          const pct = total ? Math.round((downloaded / total) * 100) : '?';
          console.log(`[PROGRESS] ${path.basename(dest)}: ${Math.round(downloaded / 1024 / 1024 * 10) / 10}MB / ${Math.round(total / 1024 / 1024 * 10) / 10}MB (${pct}%)`);
          lastReport = Date.now();
        }
      });

      res.pipe(file);

      file.on('finish', () => {
        file.close(() => {
          console.log(`[DECOMPRESSING] ${path.basename(dest)}...`);
          try {
            const gunzip = zlib.createGunzip();
            const inp = fs.createReadStream(tempGz);
            const out = fs.createWriteStream(tempDest);
            inp.pipe(gunzip).pipe(out);
            out.on('finish', () => {
              fs.unlinkSync(tempGz);
              fs.renameSync(tempDest, dest);
              console.log(`[DONE] ${path.basename(dest)} installed!`);
              resolve();
            });
            out.on('error', reject);
          } catch (err) {
            reject(err);
          }
        });
      });
    }).on('error', (err) => {
      fs.unlink(tempGz, () => {});
      reject(err);
    });
  });
}

async function main() {
  console.log('Prisma Engine Downloader starting...');
  for (const t of targets) {
    await downloadFile(t);
  }
  console.log('All engines downloaded successfully!');
}

main().catch(err => {
  console.error('Download error:', err.message);
  process.exit(1);
});
