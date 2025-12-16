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
# Image variants:
#   - mediacms-backend:lite   - Django only (for web, celery_beat, migrations)
#   - mediacms-backend:latest - Django + FFmpeg + Bento4 (for celery workers)
#   - mediacms-backend:full   - Django + FFmpeg + Bento4 + Whisper
#   - mediacms-frontend:latest - Nginx frontend

set -e

# Configuration
DOCKER_USER="${DOCKER_USER:-azataiot}"
BACKEND_IMAGE="${DOCKER_USER}/mediacms-backend"
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

    # Build backend (lite - no FFmpeg)
    echo ">>> Building Backend (lite - no FFmpeg/Bento4)..."
    docker buildx build \
        --file Dockerfile.backend \
        --target base-lite \
        --tag "${BACKEND_IMAGE}:lite" \
        --load \
        .

    # Build backend (base - with FFmpeg)
    echo ">>> Building Backend (base - with FFmpeg/Bento4)..."
    docker buildx build \
        --file Dockerfile.backend \
        --target base \
        --tag "${BACKEND_IMAGE}:${VERSION}" \
        --load \
        .

    # Build backend (full - with Whisper)
    echo ">>> Building Backend (full - with Whisper)..."
    docker buildx build \
        --file Dockerfile.backend \
        --target full \
        --tag "${BACKEND_IMAGE}:full" \
        --load \
        .

    # Build frontend
    echo ">>> Building Frontend..."
    docker buildx build \
        --file Dockerfile.frontend \
        --tag "${FRONTEND_IMAGE}:${VERSION}" \
        --load \
        .

    echo ""
    echo "=============================================="
    echo "Local build complete!"
    echo "Images created:"
    echo "  - ${BACKEND_IMAGE}:lite     (Django only - for web/celery_beat)"
    echo "  - ${BACKEND_IMAGE}:${VERSION}  (Django + FFmpeg/Bento4 - for workers)"
    echo "  - ${BACKEND_IMAGE}:full     (Django + FFmpeg/Bento4 + Whisper)"
    echo "  - ${FRONTEND_IMAGE}:${VERSION}"
    echo "=============================================="
else
    echo ""
    echo "Building and pushing multi-architecture images..."
    echo ""

    # Build and push backend (lite - no FFmpeg)
    echo ">>> Building and pushing Backend (lite)..."
    docker buildx build \
        --file Dockerfile.backend \
        --target base-lite \
        --platform $PLATFORMS \
        --tag "${BACKEND_IMAGE}:lite" \
        --push \
        .

    # Build and push backend (base - with FFmpeg)
    echo ">>> Building and pushing Backend (base)..."
    docker buildx build \
        --file Dockerfile.backend \
        --target base \
        --platform $PLATFORMS \
        --tag "${BACKEND_IMAGE}:${VERSION}" \
        --push \
        .

    # Build and push backend (full - with Whisper)
    echo ">>> Building and pushing Backend (full)..."
    docker buildx build \
        --file Dockerfile.backend \
        --target full \
        --platform $PLATFORMS \
        --tag "${BACKEND_IMAGE}:full" \
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
            --file Dockerfile.backend \
            --target base-lite \
            --platform $PLATFORMS \
            --tag "${BACKEND_IMAGE}:lite" \
            --push \
            .

        docker buildx build \
            --file Dockerfile.backend \
            --target base \
            --platform $PLATFORMS \
            --tag "${BACKEND_IMAGE}:latest" \
            --push \
            .

        docker buildx build \
            --file Dockerfile.backend \
            --target full \
            --platform $PLATFORMS \
            --tag "${BACKEND_IMAGE}:full" \
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
    echo "Images pushed:"
    echo "  - ${BACKEND_IMAGE}:lite (amd64, arm64) - Django only"
    echo "  - ${BACKEND_IMAGE}:${VERSION} (amd64, arm64) - Django + FFmpeg/Bento4"
    echo "  - ${BACKEND_IMAGE}:full (amd64, arm64) - Django + FFmpeg/Bento4 + Whisper"
    echo "  - ${FRONTEND_IMAGE}:${VERSION} (amd64, arm64)"
    if [ "$VERSION" != "latest" ]; then
        echo "  - ${BACKEND_IMAGE}:latest (amd64, arm64)"
        echo "  - ${FRONTEND_IMAGE}:latest (amd64, arm64)"
    fi
    echo ""
    echo "Usage recommendation:"
    echo "  - Web server, celery_beat, migrations: use :lite"
    echo "  - Celery workers (encoding): use :latest"
    echo "  - Celery workers (with transcription): use :full"
    echo "=============================================="
fi
