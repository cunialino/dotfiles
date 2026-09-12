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

# ROCm 10 (TheRock) ships its shared libraries inside Python packages, not /opt/rocm:
#   <site-packages>/_rocm_sdk_core/lib        -> libamdhip64.so.7, libhsa-runtime64.so.1, ...
#   <site-packages>/_rocm_sdk_libraries/lib   -> libhipblas.so.3, librocblas.so.5, libhipblaslt.so.1, ...
# Torch resolves them at import time (rocm_sdk.initialize_process + per-lib RPATH),
# but a standalone llama-server binary has no such hook, so it dies with
# "error while loading shared libraries: libhipblas.so.3". Register both
# directories with the dynamic linker so plain ld.so resolution works.
# torch depends on rocm[libraries], so the libraries package is normally already in
# the base image; install it here only if a future base image drops it again.
# The final ldconfig/ldd checks fail the build loudly rather than shipping an image
# that cannot start.
COPY --from=builder /out/ /usr/local/
RUN set -eux; \
    if ! ls /opt/venv/lib/python3.*/site-packages/_rocm_sdk_libraries/lib/libhipblas.so.3 >/dev/null 2>&1; then \
        . /opt/venv/bin/activate; \
        pip install --no-cache-dir --index-url https://stable.repo.amd.com/rocm/whl-next/ \
            "rocm[libraries]==$(python -c 'import rocm_sdk; print(rocm_sdk.__version__)')"; \
    fi; \
    mkdir -p /etc/ld.so.conf.d; \
    : > /etc/ld.so.conf.d/rocm-sdk.conf; \
    for d in /opt/venv/lib/python3.*/site-packages/_rocm_sdk_*/lib; do \
        echo "$d" >> /etc/ld.so.conf.d/rocm-sdk.conf; \
    done; \
    ldconfig; \
    ldconfig -p | grep -q 'libhipblas\.so\.3'; \
    ldconfig -p | grep -q 'libamdhip64\.so\.7'; \
    ! ldd /usr/local/bin/llama-server | grep -q 'not found'

# The models volume is bind-mounted at the *same absolute path* as on the host
# (hosts/strix_halo/default.nix: llamaModelsDir). llama.cpp resolves preset paths
# relative to the server CWD unless they are absolute, so host path == container
# path is what lets one single config.ini drive both this container and a native
# llama-server on the host. Keep MODELS_DIR in sync with llamaModelsDir.
ARG MODELS_DIR=/var/lib/llama-models

EXPOSE 11434

# Everything is env-driven: llama.cpp honours LLAMA_ARG_* for every CLI flag, so
# the preset path can be repointed from Nix (containers.llama-cpp.environment) in
# lockstep with the bind mount, without rebuilding the image. LLAMA_ARGS is kept so
# extra flags can still be appended at run time.
ENV LLAMA_ARG_HOST=0.0.0.0 \
    LLAMA_ARG_PORT=11434 \
    LLAMA_ARG_MODELS_PRESET=${MODELS_DIR}/config.ini

CMD ["sh", "-c", "exec /usr/local/bin/llama-server ${LLAMA_ARGS}"]
