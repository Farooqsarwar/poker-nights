const { PDFParse } = require('pdf-parse');
const fs = require('fs');

const files = ['PNT Technical.pdf', 'PNT Checklist.pdf', 'PNT explanation.pdf'];

(async () => {
  for (const f of files) {
    const buf = fs.readFileSync(f);
    const parser = new PDFParse();
    const data = await parser.parse(buf);
    console.log('\n\n===== ' + f + ' =====');
    console.log(data.text);
  }
})();
