#!/bin/bash
# Unit tests for the quit decision. Compiles only the pure logic, so it needs no
# running app, no Accessibility permission, and no UI.
set -e
cd "$(dirname "$0")"
mkdir -p build   # gitignored, so it does not exist on a fresh clone
swiftc -O -o build/decision-tests Sources/Decision.swift Sources/Version.swift Tests/DecisionTests.swift
./build/decision-tests
