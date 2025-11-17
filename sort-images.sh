#!/usr/bin/env bash
# Simple image sorter: prefixes files based on how many digits are in the filename
# e.g., 5.jpg → 1.5.jpg | 42.webp → 2.42.webp | 1234.jpg → 4.1234.jpg

set -euo pipefail

# Config — edit if you want different extensions or digit handling
EXTENSIONS=("jpg" "webp")
SUPPORTED_DIGITS=(1 2 3 4)
DRY_RUN=false
CREATE_UNDO=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
error()  { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success(){ echo -e "${GREEN}[OK]${NC} $1"; }

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run) DRY_RUN=true ;;
        -u|--undo)    CREATE_UNDO=true ;;
        -e|--ext)
            IFS=',' read -ra EXTRA <<< "$2"
            EXTENSIONS+=("${EXTRA[@]}")
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [-d] [-u] [-e png,jpeg]"
            echo "  -d  dry-run only"
            echo "  -u  create undo.sh"
            echo "  -e  add extensions (comma-separated)"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Build file list
GLOB=""
for e in "${EXTENSIONS[@]}"; do GLOB+="*.$e "; done
mapfile -t files < <(ls -1v $GLOB 2>/dev/null || true)

[[ ${#files[@]} -eq 0 ]] && { warn "No files found matching extensions: ${EXTENSIONS[*]}"; exit 0; }

log "Found ${#files[@]} files."

# Create undo script if requested
if $CREATE_UNDO; then
    { echo "#!/usr/bin/env bash"; echo "# Run in this folder to undo"; } > undo.sh
    chmod +x undo.sh
fi

renamed=0 skipped=0

for f in "${files[@]}"; do
    ext="${f##*.}"
    base="${f%.*}"

    digits=$(grep -o '[0-9]' <<< "$base" | wc -l)
    prefix=""

    if [[ " ${SUPPORTED_DIGITS[*]} " =~ " $digits " ]] || [[ $digits -eq 0 && " ${SUPPORTED_DIGITS[*]} " =~ " 1 " ]]; then
        prefix="${digits:-1}."
    else
        warn "Skipping $f ($digits digits)"
        ((skipped++))
        continue
    fi

    new="${prefix}${base}.${ext}"

    [[ "$f" == "$new" ]] && continue

    if $DRY_RUN; then
        echo "[DRY-RUN] $f → $new"
    else
        mv -i "$f" "$new"
        success "$f → $new"
    fi

    $CREATE_UNDO && echo "mv -- \"$new\" \"$f\" 2>/dev/null || true" >> undo.sh
    ((renamed++))
done

echo
success "Done → Renamed: $renamed | Skipped: $skipped"
$DRY_RUN && log "Dry-run mode — nothing was changed"
$CREATE_UNDO && ! $DRY_RUN && success "Undo script: ./undo.sh"