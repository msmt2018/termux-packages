#!/usr/bin/env bash
set -euo pipefail

# Full Docker pipeline for personal Termux forks.
#
# Builds, tags, optionally pulls and pushes images for the following repositories:
# - <namespace>/termux-package-builder
# - <namespace>/termux-package-builder-cgct
# - <namespace>/termux-docker
# - <namespace>/terminal-packaging
#
# Defaults:
#   namespace=androidzeros
#   tag=latest
#
# Examples:
#   DOCKER_TOKEN=... ./scripts/docker/androidzeros-full-pipeline.sh --login
#   ./scripts/docker/androidzeros-full-pipeline.sh --build --push --tag 2026.04.04
#   ./scripts/docker/androidzeros-full-pipeline.sh --pull --tag latest

NAMESPACE="${DOCKER_NAMESPACE:-androidzeros}"
TAG="latest"
DO_LOGIN=false
DO_PULL=false
DO_BUILD=false
DO_PUSH=false
VERBOSE=false

usage() {
  cat <<USAGE
Usage: $0 [options]

Options:
  --namespace <name>   Docker Hub namespace (default: ${NAMESPACE})
  --tag <tag>          Image tag to use (default: latest)
  --login              Perform docker login with DOCKER_USER/DOCKER_TOKEN
  --pull               Pull all managed images for the selected tag
  --build              Build package-builder and cgct images locally
  --push               Push all managed images for the selected tag
  --verbose            Print each resolved image reference
  -h, --help           Show this help

Environment variables:
  DOCKER_USER          Docker Hub username for --login (default: same as namespace)
  DOCKER_TOKEN         Docker Hub token/password for --login
  DOCKER_NAMESPACE     Default namespace if --namespace is not set
USAGE
}

log() {
  printf '[pipeline] %s\n' "$*"
}

run() {
  if [[ "$VERBOSE" == true ]]; then
    log "RUN: $*"
  fi
  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --login)
      DO_LOGIN=true
      shift
      ;;
    --pull)
      DO_PULL=true
      shift
      ;;
    --build)
      DO_BUILD=true
      shift
      ;;
    --push)
      DO_PUSH=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$DO_LOGIN" == true ]]; then
  DOCKER_USER="${DOCKER_USER:-$NAMESPACE}"
  if [[ -z "${DOCKER_TOKEN:-}" ]]; then
    echo "DOCKER_TOKEN is required when --login is used" >&2
    exit 1
  fi
  log "Logging in to Docker Hub as ${DOCKER_USER}"
  printf '%s' "$DOCKER_TOKEN" | run docker login -u "$DOCKER_USER" --password-stdin
fi

IMAGE_BUILDER="${NAMESPACE}/termux-package-builder:${TAG}"
IMAGE_CGCT="${NAMESPACE}/termux-package-builder-cgct:${TAG}"
IMAGE_DOCKER="${NAMESPACE}/termux-docker:${TAG}"
IMAGE_TERMINAL_PACKAGING="${NAMESPACE}/terminal-packaging:${TAG}"

if [[ "$VERBOSE" == true ]]; then
  log "Images:"
  log "  ${IMAGE_BUILDER}"
  log "  ${IMAGE_CGCT}"
  log "  ${IMAGE_DOCKER}"
  log "  ${IMAGE_TERMINAL_PACKAGING}"
fi

if [[ "$DO_PULL" == true ]]; then
  log "Pulling images"
  run docker pull "$IMAGE_BUILDER"
  run docker pull "$IMAGE_CGCT"
  run docker pull "$IMAGE_DOCKER"
  run docker pull "$IMAGE_TERMINAL_PACKAGING"
fi

if [[ "$DO_BUILD" == true ]]; then
  log "Building termux-package-builder"
  run docker build -t "$IMAGE_BUILDER" scripts/

  log "Building termux-package-builder-cgct"
  run docker build -t "$IMAGE_CGCT" -f scripts/Dockerfile.cgct scripts/

  # Keep alias repositories in sync with package-builder so user can choose
  # any of the official-style repository names.
  log "Tagging aliases from termux-package-builder"
  run docker tag "$IMAGE_BUILDER" "$IMAGE_DOCKER"
  run docker tag "$IMAGE_BUILDER" "$IMAGE_TERMINAL_PACKAGING"
fi

if [[ "$DO_PUSH" == true ]]; then
  log "Pushing images"
  run docker push "$IMAGE_BUILDER"
  run docker push "$IMAGE_CGCT"
  run docker push "$IMAGE_DOCKER"
  run docker push "$IMAGE_TERMINAL_PACKAGING"
fi

if [[ "$DO_BUILD" == true ]]; then
  cat <<EOF_SUMMARY

Build complete.
Use this image for package/bootstrap builds:
  export TERMUX_BUILDER_IMAGE_NAME=${IMAGE_BUILDER}
  ./scripts/run-docker.sh true
  ./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures aarch64 -f
EOF_SUMMARY
fi
