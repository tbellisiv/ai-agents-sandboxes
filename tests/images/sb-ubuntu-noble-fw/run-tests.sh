#!/bin/bash
# run-tests.sh - Host-side test runner for sb-ubuntu-noble-fw firewall tests
#
# This script:
# 1. Builds the sb-ubuntu-noble-fw image
# 2. Starts a container with required capabilities (NET_ADMIN, NET_RAW)
# 3. Installs Bats in the container (BEFORE firewall - apt needs network access)
# 4. Initializes the firewall
# 5. Copies and runs the Bats tests
# 6. Reports results and cleans up

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)

# Configuration
IMAGE_TAG="sb-ubuntu-noble-fw"
CONTAINER_NAME="${IMAGE_TAG}-test-$$"
TEST_DIR_CONTAINER="/tmp/firewall-tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up container: $CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Parse arguments
SKIP_BUILD=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $SCRIPT_NAME [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-build    Skip building the Docker image"
            echo "  -v, --verbose   Show verbose output"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Step 1: Build the image
if [ "$SKIP_BUILD" = false ]; then
    log_info "Building $IMAGE_TAG image..."
    BUILD_SCRIPT="$PROJECT_ROOT/templates/sandboxes/$IMAGE_TAG/image/build.sh"

    if [ ! -f "$BUILD_SCRIPT" ]; then
        log_error "Build script not found: $BUILD_SCRIPT"
        exit 1
    fi

    if ! "$BUILD_SCRIPT"; then
        log_error "Failed to build image"
        exit 1
    fi
    log_info "Image build complete"
else
    log_info "Skipping image build (--skip-build)"
fi

# Step 2: Start the container with required capabilities
log_info "Starting test container: $CONTAINER_NAME"
docker run -d \
    --name "$CONTAINER_NAME" \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --cap-add CHOWN \
    "$IMAGE_TAG" \
    sleep infinity

# Wait for container to be ready
sleep 2

# Step 3: Install Bats in the container (BEFORE firewall - apt needs network access)
log_info "Checking/installing Bats..."
docker exec "$CONTAINER_NAME" bash -c '
    if ! command -v bats &>/dev/null; then
        echo "Installing Bats..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq bats
    else
        echo "Bats already installed"
    fi
'

# Step 4: Initialize the firewall
log_info "Initializing firewall inside container..."
if ! docker exec "$CONTAINER_NAME" sudo /usr/local/bin/init-firewall.sh; then
    log_error "Firewall initialization failed"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
log_info "Firewall initialization complete"

# Step 5: Copy test files to container
log_info "Copying test files to container..."
docker exec "$CONTAINER_NAME" mkdir -p "$TEST_DIR_CONTAINER"
docker cp "$SCRIPT_DIR/firewall.bats" "$CONTAINER_NAME:$TEST_DIR_CONTAINER/"
docker cp "$SCRIPT_DIR/test_helper.bash" "$CONTAINER_NAME:$TEST_DIR_CONTAINER/"

# Step 6: Run the tests
log_info "Running firewall tests..."
echo ""
echo "================================================================"
echo "                    FIREWALL TEST RESULTS"
echo "================================================================"
echo ""

BATS_OPTS=""
if [ "$VERBOSE" = true ]; then
    BATS_OPTS="--verbose-run"
fi

# Run bats and capture exit code
set +e
docker exec "$CONTAINER_NAME" bats $BATS_OPTS "$TEST_DIR_CONTAINER/firewall.bats"
TEST_EXIT_CODE=$?
set -e

echo ""
echo "================================================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    log_info "All tests passed!"
else
    log_error "Some tests failed (exit code: $TEST_EXIT_CODE)"
fi

exit $TEST_EXIT_CODE
