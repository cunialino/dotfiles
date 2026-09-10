# llama.cpp server on ROCm 10 (TheRock-based) for gfx1151 (Strix Halo).
# Build:
#   podman build -t localhost/llama-cpp-rocm:rocm10 \
#     -f hosts/strix_halo/containers/llama-cpp.Containerfile .
# Runs as a router server: every *.gguf in the mounted /models volume is served
# simultaneously and selected by name via the OpenAI API.

ARG BASE=docker.io/rocm/pytorch:rocm10.0_ubuntu24.04_py3.13_pytorch_release_2.13.0

# The base image ships only ROCm runtime wheels. The HIP compiler and hip-lang
# CMake configs live in the `rocm[devel]` wheel, which TheRock expands lazily
# into a sibling _rocm_sdk_devel_* package on first use. Build in a throwaway
# stage so the final image stays slim.
FROM ${BASE} AS builder

ARG LLAMA_CPP_VERSION=v0.4.0
ARG AMDGPU_TARGET=gfx1151

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends git cmake build-essential; \
    . /opt/venv/bin/activate; \
    pip install --no-cache-dir --index-url https://stable.repo.amd.com/rocm/whl-next/ \
        "rocm[devel]==$(python -c 'import rocm_sdk; print(rocm_sdk.__version__)')"; \
    ROCM_ROOT=$(python -c 'from rocm_sdk import _devel; print(_devel.get_devel_root())'); \
    git clone --depth 1 --branch "${LLAMA_CPP_VERSION}" https://github.com/ggml-org/llama.cpp /opt/llama.cpp; \
    cmake -B /opt/llama.cpp/build -S /opt/llama.cpp \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_HIP=ON \
        -DCMAKE_HIP_COMPILER="${ROCM_ROOT}/bin/amdclang" \
        -DCMAKE_PREFIX_PATH="${ROCM_ROOT}/lib/cmake" \
        -DCMAKE_HIP_ARCHITECTURES="${AMDGPU_TARGET}" \
        -DLLAMA_CURL=OFF; \
    cmake --build /opt/llama.cpp/build --config Release -j"$(nproc)"; \
    cmake --install /opt/llama.cpp/build --prefix /out

FROM ${BASE}

COPY --from=builder /out/ /usr/local/
RUN ldconfig

EXPOSE 11434

CMD ["sh", "-c", "exec /usr/local/bin/llama-server --host 0.0.0.0 --port 11434 --models-dir /models ${LLAMA_ARGS}"]
