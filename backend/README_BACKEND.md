# BastionDesk - Backend API

Serwer backendowy oparty na **Express** + **Bun** z autoryzacją **Better-Auth**.

## Struktura projektu

```
backend/
├── src/
│   ├── index.ts              # Entry point - serwer Express
│   ├── lib/
│   │   ├── auth.ts           # Konfiguracja Better-Auth
│   │   ├── database.ts       # Bun SQL - natywny sterownik PostgreSQL
│   │   ├── env.ts            # Zarządzanie zmiennymi środowiskowymi
│   │   └── permissions.ts    # Role i uprawnienia (AC)
│   ├── middleware/           # Middleware (auth, error handling)
│   ├── routes/               # Routing API
│   ├── services/             # Logika biznesowa
│   ├── types/                # Definicje typów TypeScript
│   │   └── index.ts
│   └── utils/                # Funkcje pomocnicze
├── .env.example              # Przykładowe zmienne środowiskowe
├── package.json
├── tsconfig.json
└── README_BACKEND.md
```

## Połączenie z bazą danych

### Natywny sterownik Bun SQL

Backend wykorzystuje **natywny sterownik Bun SQL** do połączenia z PostgreSQL. Jest to wysokowydajny sterownik wbudowany w Bun, który używa tagged template literals.

```typescript
import { sql, transaction } from "@/lib/database";

// Proste zapytanie
const users = await sql`SELECT * FROM users WHERE active = ${true}`;

// Zapytanie z parametrami
const user = await sql`SELECT * FROM users WHERE id = ${userId}`;

// Transakcje
await transaction(async (tx) => {
  await tx`INSERT INTO users (name) VALUES (${"John"})`;
  await tx`INSERT INTO logs (action) VALUES (${"user_created"})`;
});
```

### Better-Auth

Better-Auth używa **pg Pool** (node-postgres) dla własnych operacji autoryzacyjnych. To oddzielne połączenie zapewnia kompatybilność z biblioteką Better-Auth.

## Funkcjonalności autoryzacji

- ✅ **Email/Password** - podstawowa autoryzacja
- ✅ **PassKeys (WebAuthn/U2F)** - klucze sprzętowe (YubiKey, Titan)
- ✅ **HaveIBeenPwned** - sprawdzanie kompromitacji haseł
- ✅ **Organizacje** - multi-tenancy z rolami
- ✅ **Zespoły (Teams)** - grupowanie użytkowników

## Role użytkowników

| Rola       | Opis                     | Uprawnienia                                         |
|------------|--------------------------|-----------------------------------------------------|
| `admin`    | Administrator/Właściciel | Pełne uprawnienia do organizacji, członków, raportów |
| `analityk` | Analityk danych          | Dostęp do raportów i analityk                       |
| `pracownik`| Pracownik                | Podstawowy dostęp (tylko odczyt)                    |

## Uruchomienie

### Wymagania

- [Bun](https://bun.sh/) >= 1.0
- PostgreSQL 18+ (lub Docker)
- Node.js 22

### Instalacja

```bash
cd backend

# Instalacja zależności
bun install

# Skopiuj i skonfiguruj zmienne środowiskowe
cp .env.example .env
# Edytuj .env i uzupełnij wartości
```

### Uruchomienie developerskie

```bash
# Z hot-reload
bun run dev

# Lub bez watch mode
bun run start
```

### Sprawdzenie typów

```bash
bun run typecheck
```

## API Endpoints

### Health Check

```bash
GET /health
```

Odpowiedź:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "service": "bastiondesk-backend"
}
```

### Better-Auth Endpoints

Wszystkie endpointy autoryzacji są dostępne pod `/api/auth/*`:

| Endpoint                          | Metoda | Opis                        |
|-----------------------------------|--------|-----------------------------|
| `/api/auth/sign-up/email`         | POST   | Rejestracja email/password  |
| `/api/auth/sign-in/email`         | POST   | Logowanie email/password    |
| `/api/auth/sign-out`              | POST   | Wylogowanie                 |
| `/api/auth/session`               | GET    | Pobierz aktualną sesję      |
| `/api/auth/passkey/register`      | POST   | Rejestracja PassKey         |
| `/api/auth/sign-in/passkey`       | POST   | Logowanie PassKey           |
| `/api/auth/organization/create`   | POST   | Utwórz organizację          |
| `/api/auth/organization/list`     | GET    | Lista organizacji           |

## Zmienne środowiskowe

| Zmienna                       | Opis                                    | Domyślna wartość          |
|-------------------------------|-----------------------------------------|---------------------------|
| `PORT`                        | Port serwera                            | `3333`                    |
| `NODE_ENV`                    | Środowisko (development/production)     | `development`             |
| `DATABASE_URL`                | Connection string PostgreSQL            | -                         |
| `BETTER_AUTH_SECRET`          | Sekret do tokenów (min. 32 znaki)       | -                         |
| `BETTER_AUTH_URL`             | Base URL API                            | `http://localhost:3333`   |
| `WEBAUTHN_RP_ID`              | Relying Party ID (domena)               | `localhost`               |
| `WEBAUTHN_RP_NAME`            | Nazwa aplikacji dla PassKey             | `BastionDesk`             |
| `CORS_ORIGIN`                 | Dozwolone originy dla CORS              | `http://localhost:5173`   |

## Docker

```bash
# Z docker-compose (z głównego katalogu projektu)
docker-compose up -d backend

# Lub osobno
docker build -t bastiondesk-backend .
docker run -p 3333:3333 --env-file .env bastiondesk-backend
```

## Architektura bazy danych

```
┌─────────────────────────────────────────────────────────────┐
│                      Backend (Express)                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────────────┐    ┌─────────────────────────┐   │
│   │    Better-Auth      │    │   Application Logic     │   │
│   │  (Autoryzacja)      │    │   (Incidents, etc.)     │   │
│   └─────────┬───────────┘    └───────────┬─────────────┘   │
│             │                            │                  │
│             │ pg Pool                    │ Bun SQL          │
│             │ (node-postgres)            │ (native driver)  │
│             │                            │                  │
└─────────────┼────────────────────────────┼──────────────────┘
              │                            │
              └────────────┬───────────────┘
                           │
                    ┌──────▼──────┐
                    │  PostgreSQL │
                    │   Database  │
                    └─────────────┘
```

## Następne kroki (TODO)

- [ ] Faza 2: Middleware autoryzacji
- [ ] Faza 3: Integracja z bazą danych (incidents)
- [ ] Faza 4: Rate limiting i security headers
- [ ] Faza 5: Integracja z LLM Service
- [ ] Faza 6: Testy jednostkowe i integracyjne
