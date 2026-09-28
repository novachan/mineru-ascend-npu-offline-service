#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR=$(cd "$(dirname "$0")" && pwd)

test -d "$BUNDLE_DIR/models-2.7.6-real/models"

docker run -itd --privileged \
  --name=mineru-npu \
  -p 8857:8856 \
  --shm-size 500g \
  --device=/dev/davinci0 \
  --device=/dev/davinci1 \
  --device=/dev/davinci2 \
  --device=/dev/davinci3 \
  --device=/dev/davinci4 \
  --device=/dev/davinci5 \
  --device=/dev/davinci6 \
  --device=/dev/davinci7 \
  --device=/dev/davinci_manager \
  --device=/dev/hisi_hdc \
  --device=/dev/devmm_svm \
  -v /usr/local/Ascend/driver:/usr/local/Ascend/driver \
  -v /usr/local/Ascend/firmware:/usr/local/Ascend/firmware \
  -v /usr/local/sbin/npu-smi:/usr/local/sbin/npu-smi \
  -v /usr/local/sbin:/usr/local/sbin \
  -v /etc/hccn.conf:/etc/hccn.conf \
  -v "$BUNDLE_DIR:/opt/mineru-offline" \
  -v "$BUNDLE_DIR/models-2.7.6-real:/opt/mineru-models" \
  -w /opt/mineru-offline/ \
  quay.io/ascend/vllm-ascend:v0.20.2rc1 \
  bash

echo 'created mineru-npu; next: docker exec -it mineru-npu bash /opt/mineru-offline/install.sh'
