# Serwis LLM

Ten folder zawiera serwis LLM dla aplikacji BastionDesk oparty na FastAPI i modelu Google Gemma 3 1B.

## Struktura

```
llm_service/
├── main.py - główny plik aplikacji FastAPI
├── pyproject.toml - zależności projektu
├── Dockerfile - konfiguracja Docker
├── start.sh - skrypt uruchomieniowy
├── README_LLM.md - dokumentacja
└── __pycache__/ - cache Pythona
```

## Konfiguracja

### Zależności

Projekt używa `uv` do zarządzania zależnościami. Zainstaluj `uv`:

```bash
# Na macOS i Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Na Windows
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Następnie zainstaluj zależności:

```bash
cd llm_service
uv sync
```

### Uruchomienie

```bash
uv run main.py
```

Serwer uruchomi się na porcie **8888**.

Alternatywnie, użyj Docker:

```bash
docker build -t llm-service .
docker run -p 8888:8888 llm-service
```

## Dostępne endpointy

Wszystkie endpointy są dostępne pod adresem `http://localhost:8888`.

## Rozwiązywanie problemów

### Błąd ładowania modelu
Upewnij się, że masz dostęp do internetu podczas pierwszego uruchomienia (model zostanie pobrany). Sprawdź logi aplikacji.

### Port zajęty
Jeśli port 8888 jest zajęty, zmień port w `main.py` lub użyj innego portu w Dockerze.

### Problemy z zależnościami
Upewnij się, że `uv` jest zainstalowany i uruchom `uv sync` w folderze `llm_service`.