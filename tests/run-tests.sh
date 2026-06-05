#!/usr/bin/env bash
# Run all cmt extension tests.
# Exit code: 0 = all pass, 1 = one or more failures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

run_test() {
  local test_dir="$1"
  local test_name
  test_name="$(basename "$test_dir")"

  echo ""
  echo "==> $test_name"

  # Copy extension into test dir so quarto can find it
  local ext_target="$test_dir/_extensions/West-End-Statistics/cmt"
  mkdir -p "$ext_target"
  cp -r "$REPO_DIR/_extensions/cmt/." "$ext_target/"

  local check_fn="check_${test_name//-/_}"

  if declare -f "$check_fn" > /dev/null; then
    "$check_fn" "$test_dir"
  else
    echo -e "  ${YELLOW}SKIP${NC}: no check function for $test_name"
  fi

  # Cleanup
  rm -rf "$test_dir/_extensions" "$test_dir/test_files" \
         "$test_dir/test.html" "$test_dir/test.docx"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="${3:-$pattern}"
  if grep -qF "$pattern" "$file"; then
    echo -e "  ${GREEN}PASS${NC}: $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: expected to find: $label"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local label="${3:-NOT $pattern}"
  if ! grep -qF "$pattern" "$file"; then
    echo -e "  ${GREEN}PASS${NC}: $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: expected NOT to find: $label"
    FAIL=$((FAIL + 1))
  fi
}

render_html() {
  local test_dir="$1"
  if ! (cd "$test_dir" && quarto render test.qmd --output test.html --quiet) 2>&1; then
    echo -e "  ${RED}FAIL${NC}: quarto render (html) failed"
    FAIL=$((FAIL + 1))
    return 1
  fi
  if [ ! -f "$test_dir/test.html" ]; then
    echo -e "  ${RED}FAIL${NC}: html output not created"
    FAIL=$((FAIL + 1))
    return 1
  fi
  return 0
}

render_docx() {
  local test_dir="$1"
  if ! (cd "$test_dir" && quarto render test.qmd --output test.docx --quiet) 2>&1; then
    echo -e "  ${RED}FAIL${NC}: quarto render (docx) failed"
    FAIL=$((FAIL + 1))
    return 1
  fi
  if [ ! -f "$test_dir/test.docx" ]; then
    echo -e "  ${RED}FAIL${NC}: docx output not created"
    FAIL=$((FAIL + 1))
    return 1
  fi
  return 0
}

# Extract all XML from docx for inspection (docx is a zip of XML files)
docx_xml() {
  local docx="$1"
  # Combine document body and comments (author lives in comments.xml)
  { unzip -p "$docx" word/document.xml 2>/dev/null || true
    unzip -p "$docx" word/comments.xml 2>/dev/null || true; }
}

# ---------------------------------------------------------------------------
# Test-specific check functions
# ---------------------------------------------------------------------------

check_01_docx_comment() {
  local test_dir="$1"
  render_docx "$test_dir" || return

  local xml
  xml=$(docx_xml "$test_dir/test.docx")

  # pandoc emits w:ins or w:commentRangeStart for tracked changes / comments
  if echo "$xml" | grep -qE 'w:commentRangeStart|w:ins|w:comment'; then
    echo -e "  ${GREEN}PASS${NC}: docx contains comment/tracked-change markup"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: no comment markup found in docx XML"
    FAIL=$((FAIL + 1))
  fi

  # Author should appear in the XML
  if echo "$xml" | grep -qF "Test Author"; then
    echo -e "  ${GREEN}PASS${NC}: author name present in docx XML"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: author name not found in docx XML"
    FAIL=$((FAIL + 1))
  fi
}

check_02_html_fallback() {
  local test_dir="$1"
  render_html "$test_dir" || return
  local file="$test_dir/test.html"

  assert_contains "$file" "annotated text" "highlight text rendered"
  assert_contains "$file" "My comment" "comment text rendered"
  assert_contains "$file" "Test Author" "author rendered"
  assert_contains "$file" "Plain comment" "no-highlight comment rendered"
  # No Word comment markup should appear in HTML
  assert_not_contains "$file" "comment-start" "no Word comment markup in HTML"
}

check_03_author_resolution() {
  local test_dir="$1"
  render_html "$test_dir" || return
  local file="$test_dir/test.html"

  assert_contains "$file" "Doc Level Author" "doc-level cmt-author used"
  assert_contains "$file" "Override Author" "per-call author override used"
  # Make sure default "Author" is not used when cmt-author is set
  assert_not_contains "$file" "by Author at" "fallback author not used when cmt-author set"
}

check_04_highlight() {
  local test_dir="$1"
  render_html "$test_dir" || return
  local file="$test_dir/test.html"

  assert_contains "$file" "highlighted phrase" "first highlight rendered"
  assert_contains "$file" "First comment" "first comment text rendered"
  assert_contains "$file" "Second comment" "no-highlight comment rendered"
  assert_contains "$file" "third anchor" "third highlight rendered"
  assert_contains "$file" "Fourth comment" "fourth comment rendered"

  # IDs should be sequential (0, 1, 2, 3)
  if grep -qF "Comment id 0" "$file" && grep -qF "Comment id 1" "$file"; then
    echo -e "  ${GREEN}PASS${NC}: comment IDs are sequential"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC}: comment IDs not sequential"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "Running cmt extension tests..."

for dir in "$SCRIPT_DIR"/*/; do
  [ -f "$dir/test.qmd" ] && run_test "$dir"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
