#!/bin/sh
# Build and test without Xcode: core tests via swift-testing package, app sources compiled via LocalApp.
set -e
cd "$(dirname "$0")/.."
DMX_LOCAL_TESTING=1 swift test --package-path Packages/DMXCore "$@"
swift build --package-path LocalApp
