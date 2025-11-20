# Serwer proxy NGINX

Ten folder zawiera konfigurację serwera proxy NGINX dla aplikacji BastionDesk, który zarządza routingiem.

## Struktura

```
nginx/
├── nginx.conf - główna konfiguracja NGINX
├── Dockerfile - kontener Docker
└── README_PROXY.md - dokumentacja
```

## Konfiguracja

Konfiguracja NGINX jest zdefiniowana w pliku `nginx.conf`:

### Serwer główny (Port 4586)

## Budowanie i uruchamianie

### Docker / Podman

```bash
cd nginx
docker build -t bastiondesk-nginx .
docker run -p 4586:4586 bastiondesk-nginx
```

### Docker / Podman Compose
Serwer proxy jest częścią konfiguracji Docker Compose głównego projektu:

```bash
docker-compose up nginx
```

## Konfiguracja routingu

### Główny serwer (Port 4586)

## Nagłówki proxy

Wszystkie lokalizacje przekazują następujące nagłówki do usług docelowych:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

Serwer PgAdmin dodatkowo przekazuje:
```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

## Architektura

```
Internet → NGINX (Port: 4586)
```

## Rozwiązywanie problemów

### Port zajęte
Jeśli port 4586 jest zajęty, zmień konfigurację portu w `docker-compose.yml` lub uruchom NGINX na innym porcie.

### Problemy z routingiem
Sprawdź czy wszystkie serwisy są uruchomione i nasłuchują na oczekiwanych portach.

### Błędy połączenia
Upewnij się, że nazwy usług w Docker Compose odpowiadają nazwom w konfiguracji NGINX.

### Logi NGINX
Aby zobaczyć logi NGINX w kontenerze:

```bash
docker logs <container-name>
```