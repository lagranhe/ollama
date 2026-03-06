# vim: filetype=dockerfile

ARG FLAVOR=cpu
ARG PARALLEL=8

ARG ROCMVERSION=6.3.3
ARG JETPACK5VERSION=r35.4.1
ARG JETPACK6VERSION=r36.4.0
ARG CMAKEVERSION=3.31.2
ARG VULKANVERSION=1.4.321.1

FROM base-${TARGETARCH} AS base
ARG CMAKEVERSION
RUN curl -fsSL https://github.com/Kitware/CMake/releases/download/v${CMAKEVERSION}/cmake-${CMAKEVERSION}-linux-$(uname -m).tar.gz | tar xz -C /usr/local --strip-components 1
ENV LDFLAGS=-s

FROM base AS cpu
RUN dnf install -y gcc-toolset-11-gcc gcc-toolset-11-gcc-c++
ENV PATH=/opt/rh/gcc-toolset-11/root/usr/bin:$PATH
ARG PARALLEL
COPY CMakeLists.txt CMakePresets.json .
COPY ml/backend/ggml/ggml ml/backend/ggml/ggml
RUN --mount=type=cache,target=/root/.ccache \
    cmake --preset 'CPU' \
        && cmake --build --parallel ${PARALLEL} --preset 'CPU' \
        && cmake --install build --component CPU --strip --parallel ${PARALLEL}

FROM base AS build
WORKDIR /go/src/github.com/ollama/ollama
COPY go.mod go.sum .
RUN curl -fsSL https://golang.org/dl/go$(awk '/^go/ { print $2 }' go.mod).linux-$(case $(uname -m) in x86_64) echo amd64 ;; aarch64) echo arm64 ;; esac).tar.gz | tar xz -C /usr/local
ENV PATH=/usr/local/go/bin:$PATH
RUN go mod download
COPY . .
# Clone mlx-c headers for CGO (version from MLX_VERSION file)
RUN git clone --depth 1 --branch "$(cat MLX_VERSION)" https://github.com/ml-explore/mlx-c.git build/_deps/mlx-c-src
ARG GOFLAGS="'-ldflags=-w -s'"
ENV CGO_ENABLED=1
ARG CGO_CFLAGS
ARG CGO_CXXFLAGS
ENV CGO_CFLAGS="${CGO_CFLAGS} -I/go/src/github.com/ollama/ollama/build/_deps/mlx-c-src"
ENV CGO_CXXFLAGS="${CGO_CXXFLAGS}"
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -tags mlx -trimpath -buildmode=pie -o /bin/ollama .

FROM --platform=linux/amd64 scratch AS amd64
# COPY --from=cuda-11 dist/lib/ollama/ /lib/ollama/
COPY --from=cuda-12 dist/lib/ollama /lib/ollama/
COPY --from=cuda-13 dist/lib/ollama /lib/ollama/
COPY --from=vulkan  dist/lib/ollama  /lib/ollama/
COPY --from=mlx     /go/src/github.com/ollama/ollama/dist/lib/ollama /lib/ollama/

FROM ${FLAVOR} AS archive
ARG VULKANVERSION
COPY --from=cpu dist/lib/ollama /lib/ollama
COPY --from=build /bin/ollama /bin/ollama

FROM ubuntu:24.04
RUN apt-get update \
    && apt-get install -y ca-certificates libvulkan1 libopenblas0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
COPY --from=archive /bin /usr/bin
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY --from=archive /lib/ollama /usr/lib/ollama
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV NVIDIA_VISIBLE_DEVICES=all
ENV OLLAMA_HOST=0.0.0.0:11434
EXPOSE 11434
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
