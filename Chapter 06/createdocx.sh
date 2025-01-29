#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./6_wasmgit.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter6.docx