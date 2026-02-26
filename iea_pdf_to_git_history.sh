#!/usr/bin/env bash
set -euo pipefail

AUTHOR_NAME="HR"
AUTHOR_EMAIL="hr@auckland.ac.nz"
OUTPUT_MD="Professional-Staff-H-L-IEA.md"

# ---- deps check ----
for cmd in pdftotext git awk sed sort; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd"; exit 1; }
done

# ---- month mapping ----
month_to_num() {
  case "$1" in
    January) echo 01;;
    February) echo 02;;
    March) echo 03;;
    April) echo 04;;
    May) echo 05;;
    June) echo 06;;
    July) echo 07;;
    August) echo 08;;
    September) echo 09;;
    October) echo 10;;
    November) echo 11;;
    December) echo 12;;
    *) echo 01;;
  esac
}

extract_date() {
  local filename="$1"
  if [[ "$filename" =~ ([A-Za-z]+)-([0-9]{4}) ]]; then
    local month_name="${BASH_REMATCH[1]}"
    local year="${BASH_REMATCH[2]}"
    local month
    month=$(month_to_num "$month_name")
    echo "${year}-${month}-01 12:00:00"
  else
    echo "2000-01-01 12:00:00"
  fi
}

extract_year() {
  if [[ "$1" =~ ([0-9]{4}) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# ---- text cleanup pipeline ----
clean_text() {
  sed -E '
    s/[[:space:]]+$//;                # trim trailing whitespace
    /^[[:space:]]*$/d;               # drop empty lines
  ' |
  awk '
    # remove likely headers/footers (page numbers etc.)
    !/^[[:space:]]*[0-9]+[[:space:]]*$/ &&
    !/Page [0-9]+/ &&
    !/^[[:space:]]*Professional Staff/ 
  '
}

# ---- markdown structuring ----
to_markdown() {
  awk '
    # promote numbered clauses to markdown headings
    /^[0-9]+(\.[0-9]+)*[[:space:]]+/ {
      level=gsub(/\./,"&")
      prefix=""
      for(i=0;i<level;i++) prefix=prefix"#"
      print prefix" "$0
      next
    }
    { print }
  '
}

# ---- temp workspace ----
WORKDIR=".iea_tmp"
rm -rf "$WORKDIR"
mkdir "$WORKDIR"

git init

# ---- sort PDFs by extracted date ----
ls *.pdf | while read -r f; do
  d=$(extract_date "$f")
  echo "$d|$f"
done | sort | while IFS="|" read -r commit_date pdf; do

  echo "Processing $pdf"

  raw_txt="$WORKDIR/raw.txt"

  pdftotext -layout "$pdf" "$raw_txt"

  cat "$raw_txt" \
    | clean_text \
    | to_markdown \
    > "$OUTPUT_MD"

  git add "$OUTPUT_MD"

  GIT_AUTHOR_NAME="$AUTHOR_NAME" \
  GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
  GIT_AUTHOR_DATE="$commit_date" \
  GIT_COMMITTER_DATE="$commit_date" \
  git commit -m "Import $(basename "$pdf")"

  year=$(extract_year "$commit_date")
  git tag -f "iea-$year"
done

rm -rf "$WORKDIR"

echo
echo "Done. Try:"
echo "  git log --oneline --decorate"
echo "  git diff iea-2021 iea-2024"
