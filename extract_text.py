import sys, fitz
def extract_text_from_pdf(pdf_path):
    try:
        doc = fitz.open(pdf_path)
        parts=[]
        for i,p in enumerate(doc):
            parts.append(f"\n\n=== [PAGE {i+1}] ===\n")
            parts.append(p.get_text("text"))
        doc.close()
        return "".join(parts)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return ""
if __name__ == "__main__":
    if len(sys.argv)>1:
        print(extract_text_from_pdf(sys.argv[1]))
