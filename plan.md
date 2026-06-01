# План изолированной имплементации AI endpoint через portable QEMU + Docker

## 1. Цель

Развернуть в данном репозитории `lms_rag_endpoint` изолированный AI endpoint для семантической навигации LMS, используя готовую реализацию из:

```text
C:\Users\k1NG\Desktop\BASTIANPROJECTS\MOSPOLI_LMS
```

Целевой endpoint:

```http
POST /api/navigation-search
GET /health
```

AI-сервис должен запускаться отдельно от LMS внутри Docker Compose, а Docker должен работать внутри portable QEMU Linux VM. На Windows-хосте Docker Desktop не требуется.

## 2. Итоговая архитектура

```text
Windows host
  |
  | localhost:2222 -> VM:22
  | localhost:3001 -> VM:3001
  | localhost:8080 -> VM:8080
  v
Portable QEMU Ubuntu VM
  |
  | Docker Compose
  v
Containers:
  - ai-navigation-service      # HTTP API :3001
  - llama-embedding-server     # llama.cpp embeddings :8080
```

Граница изоляции:

- LMS/frontend не импортирует код AI-сервиса.
- AI-сервис не читает `.vue`, HTML и внутренние frontend-файлы.
- Обмен только по HTTP.
- В embedding-модель не отправляются пароли, токены и персональные данные.

## 3. Что переносим из `MOSPOLI_LMS`

Минимальный набор файлов и директорий:

```text
ai-navigation-service/
docker-compose.ai.yml
docker-compose.ai.mock.yml
qemu/
deploy/vm/
deploy/nginx/mospoli-lms-ai-proxy.conf
models/README.md
.env.example
```

Локальные тяжелые артефакты переносить отдельно и не коммитить:

```text
qemu/bin/                              # portable QEMU for Windows
qemu/images/mospli-ai.qcow2            # portable Ubuntu VM disk
models/qwen3-embedding-4b-q5_k_m.gguf  # embedding model
qemu/ssh/mospli_ai                     # private SSH key, only local
```

Для репозитория сразу подготовить `.gitignore` под:

```text
models/*.gguf
qemu/bin/
qemu/downloads/
qemu/images/*.qcow2
qemu/images/*.img
qemu/ssh/*
!qemu/ssh/connect.ps1
ai-navigation-upstream.env
node_modules/
dist/
.env
```

## 4. Целевая структура репозитория

```text
lms_rag_endpoint/
├── ai-navigation-service/
│   ├── src/
│   ├── data/cards.ru.json
│   ├── scripts/test-api.mjs
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
├── deploy/
│   ├── nginx/mospoli-lms-ai-proxy.conf
│   └── vm/
├── models/
│   └── README.md
├── qemu/
│   ├── cloud-init/
│   ├── images/
│   ├── scripts/
│   ├── ssh/
│   ├── start-vm.ps1
│   ├── stop-vm.ps1
│   ├── README.md
│   └── ARTIFACTS.md
├── docker-compose.ai.yml
├── docker-compose.ai.mock.yml
├── .env.example
├── .gitignore
└── plan.md
```

## 5. AI endpoint contract

### Health

```http
GET /health
```

Ожидаемый ответ содержит:

```json
{
  "status": "ok",
  "service": "ai-navigation-service",
  "cards": 8,
  "embedding_model": "qwen3-embedding-q5-k-m",
  "embedding_mock": false
}
```

### Navigation search

```http
POST /api/navigation-search
Content-Type: application/json
```

Request:

```json
{
  "query": "как войти в лмс",
  "locale": "ru",
  "user_context": {
    "current_route": "/",
    "role": "guest"
  }
}
```

Response variants:

```text
redirect  # найден один уверенный раздел
suggest   # найдено несколько возможных разделов
fallback  # подходящий раздел не найден
```

## 6. Конфигурация runtime

Основные переменные окружения:

```env
PORT=3001
EMBEDDING_BASE_URL=http://llama-embedding-server:8080
EMBEDDING_MODEL=qwen3-embedding-q5-k-m
EMBEDDING_MOCK=false
ALLOW_EMBEDDING_FALLBACK=false
VECTOR_WEIGHT=0.7
KEYWORD_WEIGHT=0.3
PRIORITY_WEIGHT=0.05
T_REDIRECT=0.82
T_GAP=0.08
T_SUGGEST=0.62
SUGGESTIONS_COUNT=5
MAX_QUERY_LENGTH=180
```

Для локальной проверки без модели:

```env
EMBEDDING_MOCK=true
ALLOW_EMBEDDING_FALLBACK=true
```

## 7. Docker Compose

Основной compose должен запускать два контейнера:

```text
ai-navigation-service:
  build: ./ai-navigation-service
  ports:
    - "3001:3001"
  EMBEDDING_BASE_URL: http://llama-embedding-server:8080

llama-embedding-server:
  image: ghcr.io/ggml-org/llama.cpp:server
  ports:
    - "8080:8080"
  volumes:
    - ./models:/models:ro
  command:
    - -m
    - /models/qwen3-embedding-4b-q5_k_m.gguf
    - --embedding
    - -ub
    - "8192"
    - --host
    - 0.0.0.0
    - --port
    - "8080"
```

Запуск внутри VM из корня репозитория:

```bash
docker compose -f docker-compose.ai.yml up --build
```

Mock-запуск без `llama.cpp` и модели:

```bash
docker compose -f docker-compose.ai.mock.yml up --build
```

## 8. Portable QEMU VM

Требуемые host prerequisites:

```text
QEMU for Windows или portable qemu/bin/qemu-system-x86_64.exe
CPU virtualization enabled
Windows Hypervisor Platform enabled for WHPX
Python on host for cloud-init seed server
```

Ожидаемый диск:

```text
qemu/images/mospli-ai.qcow2
```

Запуск VM:

```powershell
.\qemu\start-vm.ps1
```

Fallback без WHPX:

```powershell
.\qemu\start-vm.ps1 -NoWhpx
```

SSH:

```powershell
.\qemu\ssh\connect.ps1 -User mospli
```

или:

```powershell
ssh -p 2222 mospli@localhost
```

Остановка:

```powershell
.\qemu\stop-vm.ps1
```

## 9. Docker внутри VM

После входа в VM:

```bash
sudo bash qemu/scripts/install-docker-ubuntu.sh
bash qemu/scripts/verify-docker.sh
```

Проверки должны пройти:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

Docker data остается внутри VM disk. Windows-хост не требует Docker Desktop.

## 10. Модель

Основной файл модели:

```text
models/qwen3-embedding-4b-q5_k_m.gguf
```

Требование:

```text
Qwen3-Embedding-4B GGUF Q5_K_M
```

Из проекта-источника зафиксирован SHA256:

```text
9fd05563211c2d69d74abb8769fa92983a102d11575b2517a119b0037dff217c
```

Проверка на Windows:

```powershell
Get-FileHash .\models\qwen3-embedding-4b-q5_k_m.gguf -Algorithm SHA256
```

Проверка внутри VM:

```bash
sha256sum models/qwen3-embedding-4b-q5_k_m.gguf
```

## 11. Логика поиска

MVP pipeline:

```text
query normalization
-> exact / alias match
-> keyword scoring
-> embedding request to llama.cpp
-> vector cosine similarity
-> hybrid scoring
-> decision: redirect / suggest / fallback
```

Карточки разделов хранятся в:

```text
ai-navigation-service/data/cards.ru.json
```

Минимальный набор карточек:

```text
/              # login
/register      # registration
/dashboard     # dashboard
/courses       # courses
/assignments   # assignments
/grades        # grades
/profile       # profile
/help          # help
```

Формула:

```text
final_score = vector_score * 0.7 + keyword_score * 0.3 + priority_boost
```

Decision thresholds:

```text
redirect: exact alias match
redirect: top1_score >= 0.82 and top1_score - top2_score >= 0.08
suggest:  top1_score >= 0.62
fallback: otherwise
```

## 12. Порядок имплементации

1. Подготовить репозиторий:
   - создать `.gitignore`;
   - перенести минимальную структуру из `MOSPOLI_LMS`;
   - не коммитить модель, VM disk, private SSH key и portable QEMU binaries.

2. Перенести и проверить `ai-navigation-service`:
   - `npm install`;
   - `npm run build`;
   - `EMBEDDING_MOCK=true npm start`;
   - проверить `GET /health`;
   - проверить `POST /api/navigation-search`.

3. Перенести Docker-файлы:
   - `ai-navigation-service/Dockerfile`;
   - `docker-compose.ai.yml`;
   - `docker-compose.ai.mock.yml`;
   - проверить mock compose без модели.

4. Перенести QEMU-слой:
   - `qemu/start-vm.ps1`;
   - `qemu/stop-vm.ps1`;
   - `qemu/scripts/*`;
   - `qemu/ssh/connect.ps1`;
   - `qemu/cloud-init/*`;
   - `qemu/README.md`;
   - `qemu/ARTIFACTS.md`.

5. Подключить portable artifacts:
   - положить `qemu/bin/qemu-system-x86_64.exe`;
   - положить `qemu/images/mospli-ai.qcow2`;
   - положить `models/qwen3-embedding-4b-q5_k_m.gguf`;
   - проверить hash модели.

6. Запустить VM:
   - `.\qemu\start-vm.ps1`;
   - дождаться SSH;
   - войти в VM;
   - проверить доступность проброшенных портов.

7. Установить Docker внутри VM:
   - `sudo bash qemu/scripts/install-docker-ubuntu.sh`;
   - `bash qemu/scripts/verify-docker.sh`.

8. Доставить код в VM:
   - либо клонировать/скопировать этот репозиторий внутрь VM;
   - либо использовать shared folder, если будет включен стабильный механизм обмена;
   - рабочий путь внутри VM зафиксировать как `~/lms_rag_endpoint`.

9. Запустить real AI stack:
   - `cd ~/lms_rag_endpoint`;
   - `docker compose -f docker-compose.ai.yml up --build`;
   - убедиться, что `llama-embedding-server` поднялся на `:8080`;
   - убедиться, что `ai-navigation-service` поднялся на `:3001`.

10. Проверить с Windows-хоста:
    - `curl http://localhost:3001/health`;
    - `curl -X POST http://localhost:3001/api/navigation-search -H "Content-Type: application/json" -d "{\"query\":\"войти\",\"locale\":\"ru\"}"`.

11. Подготовить интеграционный proxy для LMS:
    - для dev: Vite proxy `/api -> http://localhost:3001`;
    - для prod: nginx `location /api/navigation-search -> AI_NAVIGATION_UPSTREAM`;
    - в браузерный код не прокидывать публичный URL AI-сервиса, если используется same-origin proxy.

## 13. Verification checklist

Mock mode:

```bash
docker compose -f docker-compose.ai.mock.yml up --build
```

Real mode:

```bash
docker compose -f docker-compose.ai.yml up --build
```

Host checks:

```powershell
curl http://localhost:3001/health
```

```powershell
curl -X POST http://localhost:3001/api/navigation-search `
  -H "Content-Type: application/json" `
  -d '{"query":"войти","locale":"ru"}'
```

Required scenarios:

```text
GET /health
  -> status ok

query: войти
  -> action redirect, target.url /

query: регистрация
  -> action redirect, target.url /register

query: аккаунт
  -> action suggest

query: абсолютно непонятный запрос без смысла
  -> action fallback
```

Автотест из сервиса:

```bash
cd ai-navigation-service
AI_NAVIGATION_URL=http://localhost:3001 npm run test:api
```

## 14. Production integration

LMS должен обращаться к:

```text
/api/navigation-search
```

Сервер LMS проксирует на:

```env
AI_NAVIGATION_UPSTREAM=http://AI_VM_OR_HOST:3001
```

Nginx location:

```nginx
location /api/navigation-search {
    proxy_pass http://mospoli_ai_navigation/api/navigation-search;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 10s;
    proxy_send_timeout 120s;
    proxy_read_timeout 120s;
    client_max_body_size 32k;
}
```

## 15. Риски и ограничения

- CPU-only embeddings на QEMU могут быть медленными; это приемлемо для MVP.
- WHPX ускоряет CPU virtualization, но не дает простого GPU passthrough.
- GPU passthrough из Windows в QEMU не входит в MVP.
- VM disk и model file являются локальными артефактами и должны храниться вне git.
- Если модель отсутствует, real compose не стартует корректно; для разработки использовать mock compose.
- Endpoint пока решает только навигационный поиск, не чат и не RAG по учебным материалам.

## 16. Definition of Done

Имплементация считается готовой, когда:

- структура `lms_rag_endpoint` содержит изолированный `ai-navigation-service`;
- mock mode запускается и проходит API tests;
- portable QEMU VM стартует локальным скриптом;
- Docker Engine и Compose работают внутри VM;
- real compose запускает `ai-navigation-service` и `llama.cpp`;
- `GET /health` доступен с Windows-хоста через `localhost:3001`;
- `POST /api/navigation-search` проходит сценарии `redirect`, `suggest`, `fallback`;
- документация фиксирует модель, порты, запуск, остановку и ограничения;
- LMS может подключиться через same-origin `/api/navigation-search` proxy без знания деталей QEMU/Docker/llama.cpp.
