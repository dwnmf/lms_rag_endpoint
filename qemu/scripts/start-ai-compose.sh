#!/usr/bin/env bash
set -euo pipefail

cd "${1:-$HOME/lms_rag_endpoint}"
docker compose -f docker-compose.ai.yml up --build
