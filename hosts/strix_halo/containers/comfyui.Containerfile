# ComfyUI on ROCm 10 (TheRock-based) for gfx1151 (Strix Halo).
#
# Built by the host, not by nix (no ROCm 10 in nixpkgs): hosts/strix_halo/default.nix
# hashes this file plus its own comfyuiVersion into the tag localhost/comfyui-rocm:rocm10-<hash>
# and builds it on switch (systemd.services.comfyui-image-build) and again lazily in
# podman-comfyui.service's ExecStartPre. Editing this file therefore updates the image
# on the next switch -- no manual build.
#
# Debug builds only (the COMFYUI_VERSION here is NOT the authority, the one in
# default.nix is passed as --build-arg):
#   podman build -t localhost/comfyui-rocm:rocm10-debug \
#     -f hosts/strix_halo/containers/comfyui.Containerfile .
#
# No COPY instructions, so the build context is empty and can be any directory.
# Mutable state (models, custom_nodes, input, output, user) lives in /data.

ARG BASE=docker.io/rocm/pytorch:rocm10.0_ubuntu24.04_py3.13_pytorch_release_2.13.0
FROM ${BASE}

ARG COMFYUI_VERSION=v0.41.0

RUN git clone --depth 1 --branch "${COMFYUI_VERSION}" https://github.com/Comfy-Org/ComfyUI /opt/ComfyUI \
    && pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt \
    && mkdir -p /data

RUN pip install --no-cache-dir opencv-python-headless PyWavelets

LABEL ai.cunialino.comfyui.version="${COMFYUI_VERSION}"

EXPOSE 8188

CMD ["python", "/opt/ComfyUI/main.py", "--listen", "0.0.0.0", "--port", "8188", "--base-directory", "/data"]
