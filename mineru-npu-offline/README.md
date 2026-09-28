# MinerU NPU offline bundle

Target: Linux aarch64, CPython 3.11, vllm-ascend base image with matching
`torch==2.10.0`, `torch_npu==2.10.0`, and `torchvision==0.25.0` preinstalled.

MinerU is pinned to 2.7.6 because this release contains the pipeline NPU path,
supports Python 3.11 and accepts torch 2.10. It is run directly by
`mineru-api`; no vLLM server is started.

Copy this directory into a newly created container based on the same
vllm-ascend image, then run:

```bash
chmod +x install.sh start.sh
./install.sh
./start.sh
```

Or create the isolated container from the bundle itself:

```bash
chmod +x create-container.sh install.sh start.sh
./create-container.sh
docker exec mineru-npu bash /opt/mineru-offline/install.sh
docker exec -d mineru-npu bash /opt/mineru-offline/start.sh
```

The script reproduces the production-tested container command: all eight
device nodes are mapped and host port 8857 forwards to container port 8856.
`start.sh` defaults MinerU to `npu:0`; no vLLM server is started.

The `models-2.7.6-real/` directory contains the pipeline files downloaded by
MinerU 2.7.6 itself and verified against the sample PDF. It is a model-root
directory (it contains `models/`). Mount it at `/opt/mineru-models:ro`.
`install.sh` installs `mineru.json` under `/opt/mineru-config`, while
`start.sh` forces `MINERU_MODEL_SOURCE=local` and Hugging Face offline mode.

Do not install this bundle into the running DeepSeek container. Use a separate
container and expose only one selected NPU. The exact `docker run` NPU device
arguments depend on the production server's existing Ascend container command.
