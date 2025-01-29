#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./13_wasm_kubernetes.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter13.docx