# BastionDesk - HelpDesk Application for Incident Management

## Zmienne środowiskowe  
```
NODE_ENV=...

#Database
POSTGRES_USER=...
POSTGRES_PASSWORD=...
POSTGRES_DB=...
POSTGRES_PORT=...
DB_HOST=...

DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}

#LLM
HF_TOKEN=...  
```

## Proces uruchomienia

1. Wchodzimy w katalog BastionDesk.  
2. Uruchamiamy komendę "docker compose build" .  
3. Uruchamiamy komendę "docker compose up" lub "docker compose up -d", jeśli chcemy uruchomić w tle.    
