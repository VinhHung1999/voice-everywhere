#!/bin/bash
#
# VoiceEverywhere Python Service Setup
# Creates virtual environment and installs dependencies
#
# Usage:
#   ./setup.sh

set -e  # Exit on error

echo "🚀 VoiceEverywhere Python Service Setup"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check Python version
echo "📋 Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found. Please install Python 3.9 or later.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo -e "${GREEN}✓ Found Python $PYTHON_VERSION${NC}"

# Check if venv exists
VENV_DIR="venv"
if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠️  Virtual environment already exists at $VENV_DIR${NC}"
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing existing venv..."
        rm -rf "$VENV_DIR"
    else
        echo "Using existing venv..."
    fi
fi

# Create virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo ""
    echo "📦 Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

# Activate virtual environment
echo ""
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo ""
echo "⬆️  Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1
echo -e "${GREEN}✓ pip upgraded${NC}"

# Install dependencies
echo ""
echo "📥 Installing dependencies (this may take 5-10 minutes)..."
echo "   Installing: fastapi, uvicorn, python-multipart..."
pip install fastapi uvicorn[standard] python-multipart

echo ""
echo "   Installing: speechbrain (includes torch, torchaudio)..."
echo "   Note: torch/torchaudio are large (~2GB), please be patient..."
pip install speechbrain torch torchaudio numpy

echo ""
echo -e "${GREEN}✅ All dependencies installed!${NC}"

# Verify installation
echo ""
echo "🔍 Verifying installation..."
python3 -c "import fastapi; import speechbrain; import torch; import torchaudio" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All imports successful${NC}"
else
    echo -e "${RED}❌ Import verification failed${NC}"
    exit 1
fi

# Display torch version
TORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)")
echo -e "${GREEN}✓ PyTorch version: $TORCH_VERSION${NC}"

# Display next steps
echo ""
echo "========================================"
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Activate venv:  source python-service/venv/bin/activate"
echo "  2. Start service:  uvicorn verify_service:app --port 8765"
echo ""
echo "Or use the start script:"
echo "  ./start.sh"
echo ""
echo "Model will download (~80MB) on first run."
echo "========================================"
