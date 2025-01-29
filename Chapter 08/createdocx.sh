#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./8_quickjs.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter8.docx