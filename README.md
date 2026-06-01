# lms_rag_endpoint

Isolated AI navigation endpoint for MOSPOLI LMS.

The service is intentionally separated from the LMS frontend. It exposes HTTP endpoints for semantic navigation search and can run inside a portable QEMU Linux VM with Docker Compose.

## Main Files

```text
ai-navigation-service/      # standalone Node.js/TypeScript HTTP API
docker-compose.ai.yml       # AI service + llama.cpp embedding server
docker-compose.ai.mock.yml  # AI service only, mock embeddings
qemu/                       # portable QEMU VM scripts and docs
models/                     # local GGUF model folder, ignored by git
deploy/                     # nginx, VM and Vast.ai deployment helpers
plan.md                     # implementation plan
goal.md                     # source architecture goal
tz.md                       # source technical specification
```

## API

```http
GET /health
POST /api/navigation-search
```

Example:

```powershell
curl http://localhost:3001/health
curl -X POST http://localhost:3001/api/navigation-search -H "Content-Type: application/json" -d '{"query":"войти","locale":"ru"}'
```

## Local Mock Mode

Use this to verify the API without Docker, QEMU, llama.cpp or the GGUF model:

```powershell
cd ai-navigation-service
npm install
npm run build
$env:EMBEDDING_MOCK="true"; npm start
```

In another shell:

```powershell
cd ai-navigation-service
$env:AI_NAVIGATION_URL="http://localhost:3001"; npm run test:api
```

## Docker Mock Mode

```bash
docker compose -f docker-compose.ai.mock.yml up --build
```

## Real AI Stack

Place the required model at:

```text
models/qwen3-embedding-4b-q5_k_m.gguf
```

Then, inside the Linux VM or any Docker-capable Linux host:

```bash
docker compose -f docker-compose.ai.yml up --build
```

The real stack starts:

```text
ai-navigation-service      :3001
llama.cpp embedding server :8080
```

## Portable QEMU VM

Start from Windows:

```powershell
.\qemu\start-vm.ps1
```

SSH:

```powershell
.\qemu\ssh\connect.ps1 -User mospli
```

Install and verify Docker inside the VM:

```bash
sudo bash qemu/scripts/install-docker-ubuntu.sh
bash qemu/scripts/verify-docker.sh
```

Stop the VM:

```powershell
.\qemu\stop-vm.ps1
```

See `qemu/README.md` for full VM requirements, port forwarding and known limitations.

## LMS Integration

The LMS should call same-origin:

```text
/api/navigation-search
```

The LMS server or dev proxy forwards that request to:

```env
AI_NAVIGATION_UPSTREAM=http://AI_HOST:3001
```

See `deploy/nginx/mospoli-lms-ai-proxy.conf`.

## Current Limitations

- This is navigation search, not a chatbot.
- There is no RAG over course files, lectures or PDFs.
- QEMU mode is CPU-first.
- GPU passthrough from Windows host into QEMU is out of scope for MVP.
- VM images, portable QEMU binaries, SSH keys and GGUF models are local artifacts and are ignored by git.
