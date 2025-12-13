#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function removeBOM(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    if (content.charCodeAt(0) === 0xFEFF) {
        const fixedContent = content.slice(1);
        fs.writeFileSync(filePath, fixedContent, 'utf8');
        console.log(`Removed BOM from ${filePath}`);
    } else {
        console.log(`No BOM found in ${filePath}`);
    }
}

const files = [
    'assets/bible_kjv.json',
    'assets/bible_niv.json',
    'assets/bible_esv.json'
];

files.forEach(file => {
    const fullPath = path.join(__dirname, '..', file);
    if (fs.existsSync(fullPath)) {
        removeBOM(fullPath);
    } else {
        console.log(`File not found: ${fullPath}`);
    }
});