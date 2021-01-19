name: CI

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - '*'

jobs:
  build:
    runs-on: macos-latest
    env:
      DEVELOPER_DIR: /Applications/Xcode_12.3.app
    steps:
      - uses: actions/checkout@v1
      - name: Run tests
        run: xcodebuild build -scheme "ZenTuner (iOS)" -destination platform="iOS Simulator,name=iPhone 12 Pro Max,OS=14.3"
  lint:
    runs-on: macos-latest
    env:
      DEVELOPER_DIR: /Applications/Xcode_12.3.app
    steps:
      - uses: actions/checkout@v1
      - name: Update Homebrew
        run: brew update
      - name: Install SwiftLint
        run: brew upgrade swiftlint || true
      - name: Run SwiftLint
        run: swiftlint lint --strict
