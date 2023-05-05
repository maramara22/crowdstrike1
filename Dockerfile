# Build the manager binary
FROM golang:1.18 as builder
ARG TARGETOS
ARG TARGETARCH
ARG VERSION

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY main.go main.go
COPY version/ version/
COPY apis/ apis/
COPY controllers/ controllers/
COPY pkg/ pkg/

# Build
# the GOARCH has not a default value to allow the binary be built according to the host where the command
# was called. For example, if we call make docker-build in a local env which has the Apple Silicon M1 SO
# the docker BUILDPLATFORM arg will be linux/arm64 when for Apple x86 it will be linux/amd64. Therefore,
# by leaving it empty we can ensure that the container and binary shipped on it will have the same platform.
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -a -tags \
    "exclude_graphdriver_devicemapper exclude_graphdriver_btrfs containers_image_openpgp" \
    --ldflags="-X 'github.com/crowdstrike/falcon-operator/version.Version=${VERSION}'" \
    -o manager main.go

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM registry.access.redhat.com/ubi8/ubi-minimal
ARG VERSION
WORKDIR /
LABEL name="CrowdStrike Falcon Operator" \
      description="The CrowdStrike Falcon Operator deploys the CrowdStrike Falcon Sensor to protect Kubernetes clusters." \
      maintainer="integrations@crowdstrike.com" \
      summary="The CrowdStrike Falcon Operator" \
      release="0" \
      vendor="CrowdStrike, Inc" \
      version="${VERSION}"
COPY LICENSE /licenses/
COPY --from=builder /workspace/manager .

RUN microdnf update -y && microdnf clean all && rm -rf /var/cache/yum/*
USER 65532:65532

ENTRYPOINT ["/manager"]
