#!/usr/bin/env bash

git submodule update --init --recursive
git submodule foreach 'git fetch origin --prune && git checkout main-next && git pull origin main-next && (if [ $name = "web-uikit" ]; then bash ./scripts/submodule.sh --version=5; fi)'
