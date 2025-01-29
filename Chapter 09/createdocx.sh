#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./9_wasm2c.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter9.docx