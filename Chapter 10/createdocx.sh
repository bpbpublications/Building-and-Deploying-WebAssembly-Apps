#!/bin/bash
pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./10_async.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter10.docx