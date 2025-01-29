#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./4_optimizing_wasm.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter4.docx