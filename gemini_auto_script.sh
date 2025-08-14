#!/usr/bin/env bash
set -euo pipefail
ITERATIONS_PER_FILE="${1:-3}"
PDF_SOURCE_FOLDER="./source_pdfs"
RESULTS_FOLDER="./results"
PROMPTS_DIR="./prompts"
MODEL="${MODEL:-gemini-2.5-pro}"
RATE_SLEEP="${RATE_SLEEP:-1.2}"
USE_CHUNK="${USE_CHUNK:-0}"
MAX_CHARS="${MAX_CHARS:-180000}"
mkdir -p "$RESULTS_FOLDER" "$PROMPTS_DIR"
POLICY_FILE="${PROMPTS_DIR}/policy.txt"
SCHEMA_FILE="${PROMPTS_DIR}/schema.txt"
if [[ ! -s "$POLICY_FILE" || ! -s "$SCHEMA_FILE" ]]; then
  echo "prompts/policy.txt 또는 prompts/schema.txt 작성 필요"; exit 1; fi
shopt -s nullglob
for pdf_file in "$PDF_SOURCE_FOLDER"/*.pdf; do
  base_name="$(basename "$pdf_file" .pdf)"
  out_csv="$RESULTS_FOLDER/${base_name}_analysis.csv"
  echo "번호,교과내용,교과역량,분석회차" > "$out_csv"
  echo "📄 처리 시작: $pdf_file"
  EXAM_TEXT="$(python3 extract_text.py "$pdf_file" || true)"
  [[ -z "$EXAM_TEXT" ]] && echo "⚠️ 추출 실패, 건너뜀" && continue
  CHUNKED="$EXAM_TEXT"
  for ((i=1;i<=ITERATIONS_PER_FILE;i++)); do
    echo "  [ $i/$ITERATIONS_PER_FILE ] 분석…"
    TMP_PROMPT="$(mktemp)"
    {
      echo "## 정책"; cat "$POLICY_FILE"
      echo; echo "## 분류 기준"; cat "$SCHEMA_FILE"
      echo; echo "## 시험지 텍스트"; printf "%s\n" "$CHUNKED"
      echo; echo "## 출력 형식"; echo "헤더 없이: 번호,교과내용,교과역량"
    } > "$TMP_PROMPT"
    RAW_OUT="$(gemini -m "$MODEL" -p "$(cat "$TMP_PROMPT")" 2>/dev/null || true)"
    rm -f "$TMP_PROMPT"
    CLEANED="$(printf "%s" "$RAW_OUT" | sed -E 's/^```[a-zA-Z]*$//g;s/^```$//g' | grep -E '^[0-9]+,')"
    if [[ -z "$CLEANED" ]]; then
      echo "  ⚠️ CSV 라인 없음. 원문 일부:"; echo "$RAW_OUT" | head -n 8; sleep "$RATE_SLEEP"; continue
    fi
    while IFS= read -r line; do echo "${line},${i}" >> "$out_csv"; done <<< "$CLEANED"
    echo "  ✅ 저장: $(wc -l < "$out_csv") 줄(헤더포함)"
    sleep "$RATE_SLEEP"
  done
  echo "✅ 완료: $pdf_file"; echo
done
echo "🎉 모든 작업 완료"
