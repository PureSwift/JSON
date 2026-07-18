#!/bin/bash
#
# Builds the package for Embedded Swift using the WebAssembly Embedded SDK.
#
# Install the SDK first:
#   swift sdk install https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz
#

# Stop on error
set -e

SDK="${SWIFT_SDK:-swift-6.3.3-RELEASE_wasm-embedded}"
CONFIG="${CONFIG:-release}"

swift build -c "$CONFIG" --swift-sdk "$SDK"
