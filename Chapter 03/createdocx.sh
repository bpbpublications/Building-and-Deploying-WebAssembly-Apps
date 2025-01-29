#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./3_fast_webassembly.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter3.docx
