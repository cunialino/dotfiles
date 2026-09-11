# stable-diffusion.cpp (sd-cli) on ROCm 10 (TheRock-based) for gfx1151 (Strix Halo).
# Build:
#   podman build -t localhost/sd-cli-rocm:rocm10 \
#     -f hosts/strix_halo/containers/sd-cli.Containerfile .
# One-shot CLI, not a server: run it through the `sd-cli` host wrapper defined
# in default.nix, which mounts /var/lib/sd-models read-only and the caller's
# current directory as /work for output.

ARG BASE=docker.io/rocm/pytorch:rocm10.0_ubuntu24.04_py3.13_pytorch_release_2.13.0

# Same lazy rocm[devel] expansion trick as llama-cpp.Containerfile: the HIP
# compiler and hip-lang CMake configs only materialize on first use. Build in a
# throwaway stage so the final image stays slim.
FROM ${BASE} AS builder

# Upstream ships rolling master-<n>-<hash> tags, no semver. Pinned to latest.
ARG SD_CPP_VERSION=master-853-b68d586
ARG AMDGPU_TARGET=gfx1151

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends git cmake build-essential; \
    . /opt/venv/bin/activate; \
    pip install --no-cache-dir --index-url https://stable.repo.amd.com/rocm/whl-next/ \
        "rocm[devel]==$(python -c 'import rocm_sdk; print(rocm_sdk.__version__)')"; \
    ROCM_ROOT=$(python -c 'from rocm_sdk import _devel; print(_devel.get_devel_root())'); \
    git clone --depth 1 --branch "${SD_CPP_VERSION}" --recurse-submodules --shallow-submodules \
        https://github.com/leejet/stable-diffusion.cpp /opt/stable-diffusion.cpp; \
    cmake -B /opt/stable-diffusion.cpp/build -S /opt/stable-diffusion.cpp \
        -DCMAKE_BUILD_TYPE=Release \
        -DSD_HIPBLAS=ON \
        -DCMAKE_HIP_COMPILER="${ROCM_ROOT}/bin/amdclang" \
        -DCMAKE_PREFIX_PATH="${ROCM_ROOT}/lib/cmake" \
        -DCMAKE_HIP_ARCHITECTURES="${AMDGPU_TARGET}"; \
    cmake --build /opt/stable-diffusion.cpp/build --config Release -j"$(nproc)"; \
    cmake --install /opt/stable-diffusion.cpp/build --prefix /out

FROM ${BASE}

COPY --from=builder /out/ /usr/local/
RUN ldconfig

CMD ["sd-cli"]
