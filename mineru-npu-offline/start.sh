#!/usr/bin/env bash
set -euo pipefail

# Pin MinerU to one NPU first. Map this container to a chosen physical card
# when it is created; do not expose all eight production cards.
sed -i 's/uvicorn\.run("mineru\.cli\.fast_api:app", host=host, port=port, reload=reload)/uvicorn.run("mineru.cli.fast_api:app", host=host, port=port, http="h11", reload=reload)/' /opt/mineru-venv/lib/python3.11/site-packages/mineru/cli/fast_api.py

export MINERU_DEVICE_MODE=${MINERU_DEVICE_MODE:-npu:0}
export MINERU_MODEL_SOURCE=local
export MINERU_TOOLS_CONFIG_JSON=/opt/mineru-config/mineru.json
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
exec /opt/mineru-venv/bin/mineru-api --host 0.0.0.0 --port 8856
