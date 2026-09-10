# ComfyUI on ROCm 10 (TheRock-based) for gfx1151 (Strix Halo).
# Build:
#   podman build -t localhost/comfyui-rocm:rocm10 \
#     -f hosts/strix_halo/containers/comfyui.Containerfile .
# Mutable state (models, custom_nodes, input, output, user) lives in /data.

ARG BASE=docker.io/rocm/pytorch:rocm10.0_ubuntu24.04_py3.13_pytorch_release_2.13.0
FROM ${BASE}

ARG COMFYUI_VERSION=v0.35.0

RUN git clone --depth 1 --branch "${COMFYUI_VERSION}" https://github.com/Comfy-Org/ComfyUI /opt/ComfyUI \
    && pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt \
    && mkdir -p /data

EXPOSE 8188

CMD ["python", "/opt/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188", "--base-directory", "/data"]
