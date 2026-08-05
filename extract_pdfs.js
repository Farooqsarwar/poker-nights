const { PDFParse, VerbosityLevel } = require('pdf-parse');
const fs = require('fs');
const path = require('path');

const files = ['PNT Technical.pdf', 'PNT Checklist.pdf', 'PNT explanation.pdf'];

(async () => {
  for (const f of files) {
    const absPath = path.resolve(f);
    const fileUrl = 'file:///' + absPath.replace(/\\/g, '/');
    const parser = new PDFParse({ verbosity: VerbosityLevel.ERRORS });
    const result = await parser.getText({ url: fileUrl });
    console.log('\n\n===== ' + f + ' =====');
    if (result && result.pages) {
      for (const page of result.pages) {
        if (page.text) console.log(page.text);
      }
    } else {
      console.log(JSON.stringify(result).substring(0, 3000));
    }
  }
})();
