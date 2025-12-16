#!/bin/bash
# Multi-architecture build script for MediaCMS
# Builds and pushes images for both amd64 and arm64
#
# Prerequisites:
#   - Docker Buildx installed and configured
#   - Logged into Docker Hub: docker login
#
# Usage:
#   ./build-multiarch.sh                    # Build and push with 'latest' tag
#   ./build-multiarch.sh v1.0.0             # Build and push with specific version tag
#   ./build-multiarch.sh --local            # Build for local architecture only (no push)
#
# Images:
#   - azataiot/mediacms-web       - Django + uWSGI + Nginx (API server)
#   - azataiot/mediacms-worker    - Celery worker + FFmpeg + Bento4
#   - azataiot/mediacms-worker:full - Celery worker + Whisper transcription
#   - azataiot/mediacms-beat      - Celery Beat scheduler
#   - azataiot/mediacms-frontend  - Nginx reverse proxy

set -e

# Configuration
DOCKER_USER="${DOCKER_USER:-azataiot}"
WEB_IMAGE="${DOCKER_USER}/mediacms-web"
WORKER_IMAGE="${DOCKER_USER}/mediacms-worker"
BEAT_IMAGE="${DOCKER_USER}/mediacms-beat"
FRONTEND_IMAGE="${DOCKER_USER}/mediacms-frontend"
PLATFORMS="linux/amd64,linux/arm64"

# Parse arguments
VERSION="${1:-latest}"
LOCAL_ONLY=false

if [ "$1" = "--local" ]; then
    LOCAL_ONLY=true
    VERSION="latest"
fi

echo "=============================================="
echo "MediaCMS Multi-Architecture Docker Build"
echo "=============================================="
echo "Docker User: $DOCKER_USER"
echo "Version: $VERSION"
echo "Platforms: $PLATFORMS"
echo "Local Only: $LOCAL_ONLY"
echo "=============================================="

# Check if buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    echo "Error: Docker Buildx is required for multi-architecture builds"
    echo "Install it with: docker buildx install"
    exit 1
fi

# Create or use existing builder
BUILDER_NAME="mediacms-multiarch-builder"
if ! docker buildx inspect $BUILDER_NAME > /dev/null 2>&1; then
    echo "Creating new buildx builder: $BUILDER_NAME"
    docker buildx create --name $BUILDER_NAME --use --bootstrap
else
    echo "Using existing builder: $BUILDER_NAME"
    docker buildx use $BUILDER_NAME
fi

if [ "$LOCAL_ONLY" = true ]; then
    echo ""
    echo "Building for local architecture only..."
    echo ""

    # Build web
    echo ">>> Building Web (Django + uWSGI + Nginx)..."
    docker buildx build \
        --file Dockerfile.web \
        --tag "${WEB_IMAGE}:${VERSION}" \
        --load \
        .

    # Build worker (base)
    echo ">>> Building Worker (Celery + FFmpeg + Bento4)..."
    docker buildx build \
        --file Dockerfile.worker \
        --target base \
        --tag "${WORKER_IMAGE}:${VERSION}" \
        --load \
        .

    # Build worker (full - with Whisper)
    echo ">>> Building Worker Full (with Whisper)..."
    docker buildx build \
        --file Dockerfile.worker \
        --target full \
        --tag "${WORKER_IMAGE}:full" \
        --load \
        .

    # Build beat
    echo ">>> Building Beat (Celery scheduler)..."
    docker buildx build \
        --file Dockerfile.beat \
        --tag "${BEAT_IMAGE}:${VERSION}" \
        --load \
        .

    # Build frontend
    echo ">>> Building Frontend (Nginx)..."
    docker buildx build \
        --file Dockerfile.frontend \
        --tag "${FRONTEND_IMAGE}:${VERSION}" \
        --load \
        .

    echo ""
    echo "=============================================="
    echo "Local build complete!"
    echo "Images created:"
    echo "  - ${WEB_IMAGE}:${VERSION}"
    echo "  - ${WORKER_IMAGE}:${VERSION}"
    echo "  - ${WORKER_IMAGE}:full"
    echo "  - ${BEAT_IMAGE}:${VERSION}"
    echo "  - ${FRONTEND_IMAGE}:${VERSION}"
    echo "=============================================="
else
    echo ""
    echo "Building and pushing multi-architecture images..."
    echo ""

    # Build and push web
    echo ">>> Building and pushing Web..."
    docker buildx build \
        --file Dockerfile.web \
        --platform $PLATFORMS \
        --tag "${WEB_IMAGE}:${VERSION}" \
        --push \
        .

    # Build and push worker (base)
    echo ">>> Building and pushing Worker..."
    docker buildx build \
        --file Dockerfile.worker \
        --target base \
        --platform $PLATFORMS \
        --tag "${WORKER_IMAGE}:${VERSION}" \
        --push \
        .

    # Build and push worker (full)
    echo ">>> Building and pushing Worker Full..."
    docker buildx build \
        --file Dockerfile.worker \
        --target full \
        --platform $PLATFORMS \
        --tag "${WORKER_IMAGE}:full" \
        --push \
        .

    # Build and push beat
    echo ">>> Building and pushing Beat..."
    docker buildx build \
        --file Dockerfile.beat \
        --platform $PLATFORMS \
        --tag "${BEAT_IMAGE}:${VERSION}" \
        --push \
        .

    # Build and push frontend
    echo ">>> Building and pushing Frontend..."
    docker buildx build \
        --file Dockerfile.frontend \
        --platform $PLATFORMS \
        --tag "${FRONTEND_IMAGE}:${VERSION}" \
        --push \
        .

    # If version is not 'latest', also tag as latest
    if [ "$VERSION" != "latest" ]; then
        echo ">>> Also tagging as 'latest'..."

        docker buildx build \
            --file Dockerfile.web \
            --platform $PLATFORMS \
            --tag "${WEB_IMAGE}:latest" \
            --push \
            .

        docker buildx build \
            --file Dockerfile.worker \
            --target base \
            --platform $PLATFORMS \
            --tag "${WORKER_IMAGE}:latest" \
            --push \
            .

        docker buildx build \
            --file Dockerfile.beat \
            --platform $PLATFORMS \
            --tag "${BEAT_IMAGE}:latest" \
            --push \
            .

        docker buildx build \
            --file Dockerfile.frontend \
            --platform $PLATFORMS \
            --tag "${FRONTEND_IMAGE}:latest" \
            --push \
            .
    fi

    echo ""
    echo "=============================================="
    echo "Multi-architecture build complete!"
    echo "Images pushed (amd64 + arm64):"
    echo "  - ${WEB_IMAGE}:${VERSION}"
    echo "  - ${WORKER_IMAGE}:${VERSION}"
    echo "  - ${WORKER_IMAGE}:full"
    echo "  - ${BEAT_IMAGE}:${VERSION}"
    echo "  - ${FRONTEND_IMAGE}:${VERSION}"
    if [ "$VERSION" != "latest" ]; then
        echo "  - Plus :latest tags for all images"
    fi
    echo "=============================================="
fi
