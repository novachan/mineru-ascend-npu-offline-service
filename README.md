# MinerU Ascend NPU Offline Service

中文名称：**MinerU 昇腾 NPU 离线解析服务**

本仓库提供面向 Linux `aarch64` 昇腾服务器的 MinerU 2.7.6 离线 pipeline 服务。核心做法是复用 `vllm-ascend` 基座镜像中已经准备好的 `torch`、`torch_npu` 和 Ascend 运行时，在独立容器中借用闲置 NPU 资源运行 MinerU；不会启动 vLLM，也不会修改已有的 DeepSeek/VLLMWorker 容器。

服务只承担 MinerU 文档解析，不包含 MCP 转发层；如需通过 MCP 调用，请配合 `mineru-ascend-mcp-gateway` 使用。

## 版本和前置条件

| 项目 | 要求 |
| --- | --- |
| 基础镜像 | `quay.io/ascend/vllm-ascend:v0.20.2rc1` |
| Python | 3.11 |
| MinerU | 2.7.6 |
| torch | 基座提供 `2.10.0` |
| torch_npu | 基座提供 `2.10.0` |
| torchvision | 基座提供 `0.25.0` |
| transformers | 离线包提供 `4.57.1` |
| 服务 | 容器 `8856`，宿主机默认 `8857` |

必须提前准备匹配版本的 Ascend 驱动、固件、设备节点和 `npu-smi`。本仓库不包含这些宿主机依赖。

## 基座镜像与下载地址

本方案使用的基座镜像是：

```text
quay.io/ascend/vllm-ascend:v0.20.2rc1
```

官方镜像仓库：

- [Quay 镜像仓库：ascend/vllm-ascend](https://quay.io/repository/ascend/vllm-ascend)
- [Quay 标签页：v0.20.2rc1](https://quay.io/repository/ascend/vllm-ascend?tab=tags&tag=v0.20.2rc1)
- [vLLM-Ascend 官方仓库](https://github.com/vllm-project/vllm-ascend)

联网机器拉取镜像：

```bash
docker pull quay.io/ascend/vllm-ascend:v0.20.2rc1
```

如果部署服务器离线，请在联网机器执行：

```bash
docker pull quay.io/ascend/vllm-ascend:v0.20.2rc1
docker save quay.io/ascend/vllm-ascend:v0.20.2rc1 | gzip > vllm-ascend-v0.20.2rc1.tar.gz
```

再将 `vllm-ascend-v0.20.2rc1.tar.gz` 传到离线服务器：

```bash
gzip -dc vllm-ascend-v0.20.2rc1.tar.gz | docker load
```

> 镜像标签、架构支持和 Ascend 驱动兼容性以官方仓库当前说明为准。本仓库只记录本次部署验证所使用的标签，不替代官方发布说明。

## 离线包下载

约 3.2GB 的 wheelhouse 和模型目录不提交到 Git。请将真实地址补充到这里：

```text
百度网盘地址：<BAIDU_PAN_URL>
提取码：<BAIDU_PAN_CODE>
文件名：mineru-npu-2.7.6-deployment.tar.gz
SHA-256：25c025a9e44390440ed7a65365be1b838575527687876874df7c29e20fa29b3c
```

下载后校验并解压：

```bash
sha256sum mineru-npu-2.7.6-deployment.tar.gz
tar -xzf mineru-npu-2.7.6-deployment.tar.gz
cd mineru-npu-offline
```

解压后的目录应包含：

```text
mineru-npu-offline/
├── wheelhouse/
├── models-2.7.6-real/
├── create-container.sh
├── install.sh
├── start.sh
├── mineru.json
├── requirements.txt
└── constraints.txt
```

其中 `models-2.7.6-real/` 必须保留 `models/` 这一层，例如：

```text
models-2.7.6-real/models/MFD/YOLO/yolo_v8_ft.pt
```

## 创建和启动容器

先根据目标机器实际可用的 NPU 设备修改 `create-container.sh`。当前脚本保留了现场验证过的设备挂载方式，不建议未经检查直接占用整台机器的全部卡。

```bash
chmod +x create-container.sh install.sh start.sh
./create-container.sh

docker exec -it mineru-npu bash /opt/mineru-offline/install.sh
docker exec -d mineru-npu bash /opt/mineru-offline/start.sh
```

### 完整容器启动命令

`create-container.sh` 实际使用的基座镜像和端口如下。设备节点、驱动目录和 NPU 数量必须按目标服务器调整：

```bash
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
  -v "$PWD:/opt/mineru-offline" \
  -v "$PWD/models-2.7.6-real:/opt/mineru-models" \
  -w /opt/mineru-offline \
  quay.io/ascend/vllm-ascend:v0.20.2rc1 \
  bash
```

创建容器后安装并启动 MinerU：

```bash
docker exec -it mineru-npu bash /opt/mineru-offline/install.sh
docker exec -d mineru-npu bash /opt/mineru-offline/start.sh
```

服务启动后，MinerU API 地址为：

```text
http://<服务器地址>:8857
```

安装脚本会：

- 创建 `/opt/mineru-venv`
- 保留基座中的 `torch`、`torch_npu`、`torchvision`
- 使用 `--no-index --find-links wheelhouse` 离线安装 MinerU 依赖
- 替换为 headless OpenCV

启动脚本会固定：

```text
MINERU_DEVICE_MODE=npu:0
MINERU_MODEL_SOURCE=local
MINERU_TOOLS_CONFIG_JSON=/opt/mineru-config/mineru.json
HF_HUB_OFFLINE=1
TRANSFORMERS_OFFLINE=1
```

## 验证

```bash
curl -fsS http://127.0.0.1:8857/docs

curl -fsS http://127.0.0.1:8857/file_parse \
  -F 'files=@/path/to/test.pdf' \
  -F 'backend=pipeline' \
  -F 'return_md=true'
```

同时确认 NPU 运行时：

```bash
docker exec mineru-npu \
  /opt/mineru-venv/bin/python -c \
  'import torch, torch_npu; print(torch.__version__, torch_npu.npu.is_available())'

npu-smi info
```

API `/docs` 返回 200 不代表模型推理已经成功，必须再执行一次真实 PDF 解析。

## 重要限制

- NPU 包只针对 Linux `aarch64`、Python 3.11 和对应 Ascend 驱动组合。
- 不要把该包安装到正在运行的生产 DeepSeek/VLLMWorker 容器。
- 不要把 MinerU 2.7.6 的模型目录与 MinerU 3.4.5 模型目录混用。
- `docx/xlsx/pptx` 在 MinerU 2.7.6 上通常需要由上层 `mineru-mcp` 先转成 PDF。
- 设备映射、`--privileged`、`--shm-size` 和驱动挂载必须按现场环境复核。

## 目录说明

```text
mineru-deploy-npu-ascend/
├── README.md
├── .gitignore
└── mineru-npu-offline/
    ├── create-container.sh
    ├── install.sh
    ├── start.sh
    ├── mineru.json
    ├── requirements.txt
    └── constraints.txt
```

## 许可证和第三方依赖

发布前请补充许可证，并核对 Ascend 基座镜像、MinerU、模型权重、wheelhouse 和其他依赖的再分发许可。不要提交驱动文件、生产配置、Token 或真实业务文档。

公开提交前请先阅读 [PUBLISHING.md](./PUBLISHING.md)，避免提交记录暴露个人姓名或工具尾注。
