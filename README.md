# lms_rag_endpoint

Изолированный HTTP-сервис семантического поиска по навигации для LMS MOSPOLI. Принимает запросы на `/api/navigation-search` и ничего лишнего не делает. Можно запускать внутри портативной QEMU-VM с Docker Compose.

## Структура

```text
ai-navigation-service/      # самостоятельный HTTP API на Node.js/TypeScript
docker-compose.ai.yml       # AI-сервис + embedding-сервер llama.cpp
docker-compose.ai.mock.yml  # AI-сервис без llama.cpp, моковые эмбеддинги
qemu/                       # скрипты и документация для QEMU-VM
models/                     # папка для GGUF-моделей, в git не попадает
deploy/                     # конфиги nginx, скрипты деплоя на VM и Vast.ai
```

## API

Два эндпоинта:

```http
GET /health
POST /api/navigation-search
```

Пример:

```powershell
curl http://localhost:3001/health
curl -X POST http://localhost:3001/api/navigation-search -H "Content-Type: application/json" -d '{"query":"войти","locale":"ru"}'
```

## Локальный запуск без Docker

Чтобы проверить API без Docker, QEMU, llama.cpp и GGUF-модели:

```powershell
cd ai-navigation-service
npm install
npm run build
$env:EMBEDDING_MOCK="true"; npm start
```

В другом терминале:

```powershell
cd ai-navigation-service
$env:AI_NAVIGATION_URL="http://localhost:3001"; npm run test:api
```

## Docker с моковыми эмбеддингами

```bash
docker compose -f docker-compose.ai.mock.yml up --build
```

## Полный стек с реальной моделью

Положить модель в:

```text
models/qwen3-embedding-4b-q5_k_m.gguf
```

Затем внутри Linux-VM или на любом Linux-хосте с Docker:

```bash
docker compose -f docker-compose.ai.yml up --build
```

Запускаются два контейнера: `ai-navigation-service` на порту 3001 и embedding-сервер llama.cpp на 8080.

## QEMU-VM

Запуск из Windows:

```powershell
.\qemu\start-vm.ps1
```

SSH:

```powershell
.\qemu\ssh\connect.ps1 -User mospli
```

Внутри VM — установка и проверка Docker:

```bash
sudo bash qemu/scripts/install-docker-ubuntu.sh
bash qemu/scripts/verify-docker.sh
```

Остановка:

```powershell
.\qemu\stop-vm.ps1
```

Подробнее про требования к VM, проброс портов и известные ограничения — в `qemu/README.md`.

## Интеграция с LMS

LMS отправляет запросы на тот же origin:

```text
/api/navigation-search
```

LMS-сервер или dev-прокси пробрасывает их на:

```env
AI_NAVIGATION_UPSTREAM=http://AI_HOST:3001
```

Конфиг nginx: `deploy/nginx/mospoli-lms-ai-proxy.conf`.
