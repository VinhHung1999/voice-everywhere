#!/bin/bash
#
# Start VoiceEverywhere Python Service
#
# Usage:
#   ./start.sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if venv exists
if [ ! -d "venv" ]; then
    echo -e "${RED}❌ Virtual environment not found!${NC}"
    echo ""
    echo "Please run setup first:"
    echo "  ./setup.sh"
    exit 1
fi

# Activate venv
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Check if dependencies are installed
if ! python3 -c "import fastapi; import speechbrain; import torch" 2>/dev/null; then
    echo -e "${RED}❌ Dependencies not installed!${NC}"
    echo ""
    echo "Please run setup first:"
    echo "  ./setup.sh"
    exit 1
fi

# Start service
echo ""
echo "🚀 Starting Speaker Verification Service..."
echo "   Port: 8765"
echo "   Press Ctrl+C to stop"
echo ""

uvicorn verify_service:app --port 8765 --log-level info
