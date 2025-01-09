# Package

version = "0.1.0"
author = "Primoz Susa"
description = "A new awesome nimble package"
license = "MIT"
srcDir = "src"

task buildpeaks, "Build peaks prod":
  exec "nim c -d:release --mm:orc -d:danger --passC:-flto --passC:-march=native -o=bin/peaks src/peaks.nim"

task buildpeaksdev, "Build peaks dev":
  exec "nim c --mm:orc -d:danger -o=bin/peaks src/peaks.nim"
# Dependencies

requires "nim >= 2.2.0"

requires "spacy >= 0.0.4"
requires "vmath >= 2.0.0"
requires "bumpy >= 1.1.2"
requires "progress >= 1.1.3"
requires "results >= 0.5.0"

requires "print >= 1.0.2"
requires "tabby >= 0.6.0"
requires "git@github.com:primozs/osm_utils.git >= 0.1.0"