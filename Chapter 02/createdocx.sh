pandoc --reference-doc ../template.docx --lua-filter ../apply-code-style.lua -F mermaid-filter ./2_webassembly_from_scratch.md -o temp.docx
python3 ../changestyle.py ./temp.docx ./chapter2.docx
