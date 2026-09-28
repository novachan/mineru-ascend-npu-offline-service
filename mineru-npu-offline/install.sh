#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
python3.11 -m venv --system-site-packages /opt/mineru-venv
mkdir -p /opt/mineru-config
install -m 0644 "$ROOT_DIR/mineru.json" /opt/mineru-config/mineru.json

# Install only the downloaded MinerU dependency set. torch, torch_npu and
# torchvision remain provided by the base vllm-ascend image.
/opt/mineru-venv/bin/python -m pip install \
  --no-index \
  --find-links "$ROOT_DIR/wheelhouse" \
  --constraint "$ROOT_DIR/constraints.txt" \
  -r "$ROOT_DIR/requirements.txt"

# MinerU declares opencv-python, but the API is headless and the production
# image does not need libGL. Restore the headless cv2 files after resolution.
/opt/mineru-venv/bin/python -m pip uninstall -y opencv-python
/opt/mineru-venv/bin/python -m pip install \
  --no-index --no-deps --force-reinstall \
  --find-links "$ROOT_DIR/wheelhouse" opencv-python-headless==4.11.0.86

/opt/mineru-venv/bin/python -c \
  'import torch, torch_npu; print("torch", torch.__version__, "npu", torch_npu.npu.is_available())'
/opt/mineru-venv/bin/mineru-api --help >/dev/null
