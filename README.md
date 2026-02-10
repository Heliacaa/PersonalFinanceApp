<p align="center">
  <img src="figs/Screenshot%202026-02-10%20at%2017.52.04.png" width="200" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.53.03.png" width="200" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.54.02.png" width="200" />
</p>

<h1 align="center">SentixInvest — AI-Powered Personal Finance Platform</h1>

<p align="center">
  <strong>A full-stack investment platform combining real-time market data, AI-driven analysis with RAG (Retrieval-Augmented Generation), and a Model Context Protocol (MCP) server architecture.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Spring%20Boot-3.4-6DB33F?logo=springboot&logoColor=white" />
  <img src="https://img.shields.io/badge/FastAPI-0.109-009688?logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-16%20+%20pgvector-4169E1?logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white" />
</p>

---

## Table of Contents

- [Overview](#overview)
- [Screenshots](#screenshots)
- [System Architecture](#system-architecture)
- [Key Features](#key-features)
  - [RAG Pipeline (Retrieval-Augmented Generation)](#-rag-pipeline-retrieval-augmented-generation)
  - [MCP Server (Model Context Protocol)](#-mcp-server-model-context-protocol)
  - [AI-Powered Stock Analysis & Chat](#-ai-powered-stock-analysis--chat)
  - [Real-Time Market Data](#-real-time-market-data)
  - [Portfolio & Risk Analytics](#-portfolio--risk-analytics)
  - [Trading & Payments](#-trading--payments)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
- [Roadmap](#roadmap)

---

## Overview

**SentixInvest** is a comprehensive personal finance and investment platform that demonstrates the integration of modern AI techniques into a production-grade mobile application. The project highlights two key technologies:

1. **RAG (Retrieval-Augmented Generation)** — A custom-built pipeline that ingests financial education content, live news articles, and research data into a pgvector-powered vector store. When users ask questions or request stock analysis, semantically relevant context is retrieved and injected into LLM prompts, producing grounded, accurate financial insights rather than hallucinated responses.

2. **MCP (Model Context Protocol) Server** — A FastAPI-based microservice that acts as the data and intelligence layer. It aggregates data from multiple external APIs (Yahoo Finance, CoinGecko, GNews, Finnhub, ExchangeRate-API), performs NLP sentiment analysis, orchestrates the RAG pipeline, and communicates with Groq's LLM (Llama 3.3 70B) for AI-powered analysis — all behind a unified, cacheable API surface.

The platform supports **US & Turkish (BIST)** stock markets, cryptocurrency tracking, forex conversion, economic calendar monitoring, portfolio risk analysis, dividend tracking, earnings calendars, real-time price alerts with push notifications, and secure payments via Iyzico.

---

## Screenshots

<p align="center">
  <img src="figs/Screenshot%202026-02-10%20at%2017.52.04.png" width="230" alt="Dashboard" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.52.40.png" width="230" alt="Markets" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.52.50.png" width="230" alt="Stock Detail" />
</p>
<p align="center">
  <img src="figs/Screenshot%202026-02-10%20at%2017.53.03.png" width="230" alt="AI Analysis" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.53.35.png" width="230" alt="Portfolio" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.53.55.png" width="230" alt="Risk Analytics" />
</p>
<p align="center">
  <img src="figs/Screenshot%202026-02-10%20at%2017.54.02.png" width="230" alt="AI Chat" />
  <img src="figs/Screenshot%202026-02-10%20at%2017.54.09.png" width="230" alt="Crypto & Forex" />
</p>

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Flutter Mobile App                           │
│  (Riverpod · Dio · go_router · fl_chart · Firebase Messaging)      │
└────────────────────────────┬────────────────────────────────────────┘
                             │ REST / JWT
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Spring Boot Backend (:8080)                       │
│  Java 21 · Spring Security · JPA · Redis · WebClient · MapStruct   │
│                                                                     │
│  Auth · Portfolio · Trading · Watchlist · Alerts · Payments         │
│  Push Notifications (FCM) · Iyzico Payment Gateway                 │
└──────────┬──────────────────────────────────┬───────────────────────┘
           │ WebClient (HTTP)                 │ JDBC
           ▼                                  ▼
┌──────────────────────────┐    ┌────────────────────────────────────┐
│  MCP Server (:8000)      │    │  PostgreSQL 16 + pgvector          │
│  FastAPI · Python 3.11   │───▶│                                    │
│                          │    │  Users · Portfolios · Transactions │
│  • Stock/Crypto/Forex    │    │  Watchlists · Alerts · Payments    │
│  • Sentiment Analysis    │    │  rag_documents (vector(384))       │
│  • RAG Pipeline          │    │  rag_chat_history                  │
│  • AI Analysis (Groq)    │    │  rag_ingestion_log                 │
│  • News + Earnings       │    └────────────────────────────────────┘
│  • Economic Calendar     │
│  • Risk Analytics        │                  ┌──────────────────────┐
│                          │◀────────────────▶│  Redis 7 (Cache)     │
└──────────────────────────┘                  │  TTL-based caching   │
           │                                  │  per data type       │
           ▼                                  └──────────────────────┘
   ┌───────────────────┐
   │  External APIs     │
   │  • Yahoo Finance   │
   │  • CoinGecko       │
   │  • GNews           │
   │  • Finnhub         │
   │  • ExchangeRate    │
   │  • Groq LLM        │
   └───────────────────┘
```

All services are orchestrated via **Docker Compose** with a single `docker compose up --build` command.

---

## Key Features

### 🧠 RAG Pipeline (Retrieval-Augmented Generation)

The RAG system is the intelligence backbone of SentixInvest. It ensures AI responses are **grounded in real financial data** rather than relying solely on an LLM's training knowledge.

**How it works:**

```
User Query
    │
    ▼
┌─────────────────┐     ┌───────────────────────┐     ┌──────────────────┐
│ Embedding Model  │────▶│ pgvector Similarity   │────▶│ Context Builder   │
│ all-MiniLM-L6-v2│     │ Search (cosine)       │     │ Top-K + Threshold │
│ 384-dim vectors  │     │ Filtered by symbol,   │     │ Char-limit        │
└─────────────────┘     │ source type, expiry   │     │ truncation        │
                        └───────────────────────┘     └────────┬─────────┘
                                                                │
                                                                ▼
                                                    ┌─────────────────────┐
                                                    │ Groq LLM Prompt     │
                                                    │ (Llama 3.3 70B)    │
                                                    │ + Retrieved Context │
                                                    │ + Stock Data        │
                                                    │ + User Portfolio    │
                                                    └─────────────────────┘
```

**Three ingestion sources feed the vector store:**

| Source | Content | Lifecycle |
|--------|---------|-----------|
| **EDUCATION** | 15 financial literacy documents (DCA, P/E ratios, beta, Sharpe ratio, diversification, technical analysis, etc.) | Seeded on startup, never expires |
| **NEWS** | Stock-specific news articles with sentiment scores | Auto-ingested when `/news/{symbol}` is called, expires in 30 days |
| **RESEARCH** | Risk metrics, dividend data, earnings reports | Ingested during AI analysis, expires in 7 days |

**Key implementation details:**
- **Embedding Model:** `all-MiniLM-L6-v2` from sentence-transformers — lightweight, fast, 384-dimensional vectors
- **Vector Store:** PostgreSQL + pgvector extension — cosine similarity search via the `<=>` operator
- **Tables:** `rag_documents` (content + embeddings), `rag_chat_history` (multi-turn conversations), `rag_ingestion_log` (tracking)
- **Retrieval:** Score threshold filtering (default 0.3), max context character limits, source citation support
- **Chat History:** Last 8 messages per session stored in PostgreSQL and included in subsequent LLM calls

---

### 🔌 MCP Server (Model Context Protocol)

The MCP server is a **FastAPI microservice** that acts as a unified data and intelligence layer, decoupling the Spring Boot backend from external API dependencies and AI logic.

**Why a separate MCP server?**
- **Language flexibility:** Python is the de facto ecosystem for ML/NLP (sentence-transformers, TextBlob, pandas)
- **Independent scaling:** The data-heavy MCP layer can scale independently from the business logic backend
- **Caching layer:** Redis caching with per-endpoint TTLs reduces external API calls and latency
- **Fault tolerance:** Mock data fallbacks ensure the app remains functional when external APIs are rate-limited or down

**Endpoints provided by the MCP server:**

| Category | Endpoints | Data Source |
|----------|-----------|-------------|
| **Stocks** | Quote, History, Search, News | Yahoo Finance, GNews |
| **AI** | Stock Analysis, Chat, RAG Status, Manual Ingestion | Groq (Llama 3.3 70B) + RAG |
| **Crypto** | Markets, Quote | CoinGecko |
| **Forex** | Rates, Convert | ExchangeRate-API |
| **Analytics** | Portfolio Risk (Beta, VaR, Sharpe, Max Drawdown) | Yahoo Finance (computed) |
| **Dividends** | Yield, History, Next Payment | Yahoo Finance |
| **Earnings** | EPS, Revenue, Calendar | Yahoo Finance + Finnhub |
| **Calendar** | Economic Events (CPI, NFP, Interest Rates) | Finnhub |
| **Sentiment** | NLP Text Analysis (BULLISH/BEARISH/NEUTRAL) | TextBlob |

**Caching strategy (Redis):**

| Data Type | TTL | Rationale |
|-----------|-----|-----------|
| Quotes, Crypto | 1 min | Near real-time price freshness |
| History, Forex | 5 min | Moderate update frequency |
| News | 15 min | Articles don't change frequently |
| Risk, Calendar | 30 min | Computationally expensive to recalculate |
| Dividends, Earnings, AI | 1 hour | Stable data that changes infrequently |

---

### 🤖 AI-Powered Stock Analysis & Chat

**Stock Analysis (`/ai/analyze/{symbol}`):**
- Fetches real-time stock data, news, risk metrics, dividends, and earnings
- Retrieves relevant RAG context (financial education + past research)
- Sends enriched prompt to Groq's Llama 3.3 70B model
- Returns structured analysis: summary, technical outlook, fundamental assessment, risk factors, and recommendation

**AI Chat (`/ai/chat`):**
- Multi-turn conversational interface with session-based history
- Portfolio-aware: injects user's holdings and watchlist into context
- RAG-enhanced: retrieves relevant documents for each message
- Source citations from RAG documents included in responses
- Chat history persisted in PostgreSQL (last 8 messages per session)

---

### 📈 Real-Time Market Data

- **US & Turkish (BIST) Markets** — Live quotes, historical charts, and market indices (S&P 500, NASDAQ, BIST 100)
- **Cryptocurrency** — Top markets by market cap, individual coin quotes via CoinGecko
- **Forex** — 15 major currency pairs with real-time conversion
- **News** — Stock-specific news with NLP sentiment scoring (BULLISH/BEARISH/NEUTRAL)
- **Economic Calendar** — Global events with impact levels (HIGH/MEDIUM/LOW)
- **Graceful Degradation** — Mock data fallbacks when external APIs are rate-limited

---

### 📊 Portfolio & Risk Analytics

- **Holdings Tracking** — Buy/sell transactions with real-time P&L calculation
- **Portfolio Summary** — Total value, daily change, gain/loss percentages
- **Risk Metrics** — Per-stock Beta, Volatility, Sharpe Ratio, Value at Risk (95%), Max Drawdown
- **Diversification Score** — Quantified portfolio diversification assessment
- **Dividend Tracking** — Yield, payout frequency, next payment date, payment history
- **Earnings Calendar** — EPS actual vs estimate, surprise percentage, beat/miss tracking

---

### 💳 Trading & Payments

- **Stock Trading** — Buy and sell stocks with real-time market prices
- **Transaction History** — Full audit trail of all trades, filterable by symbol
- **Price Alerts** — Set target prices with push notifications via Firebase Cloud Messaging
- **Fund Management** — Add funds via Iyzico payment gateway (WebView checkout)
- **JWT Authentication** — Secure, stateless authentication with role-based access

---

## Tech Stack

### Frontend
| Technology | Purpose |
|------------|---------|
| **Flutter 3.10** | Cross-platform mobile framework (iOS, Android, Web, Desktop) |
| **Dart** | Programming language |
| **Riverpod** | State management |
| **Dio** | HTTP client with interceptors |
| **go_router** | Declarative navigation |
| **fl_chart** | Interactive financial charts |
| **Firebase Messaging** | Push notifications |
| **flutter_secure_storage** | Secure token persistence |
| **WebView** | Iyzico payment integration |

### Backend
| Technology | Purpose |
|------------|---------|
| **Spring Boot 3.4** | Application framework |
| **Java 21** | Language |
| **Spring Security + JWT** | Authentication & authorization |
| **Spring Data JPA** | ORM & database access |
| **Spring Data Redis** | Cache integration |
| **Spring WebClient** | Reactive HTTP client for MCP server calls |
| **MapStruct** | DTO ↔ Entity mapping |
| **SpringDoc OpenAPI** | API documentation |
| **Firebase Admin SDK** | Server-side push notifications |
| **Iyzipay** | Payment gateway |
| **Testcontainers** | Integration testing with real PostgreSQL |

### MCP Server
| Technology | Purpose |
|------------|---------|
| **FastAPI** | High-performance async API framework |
| **Python 3.11** | Language |
| **sentence-transformers** | `all-MiniLM-L6-v2` embedding model for RAG |
| **psycopg2 + pgvector** | Vector store with similarity search |
| **TextBlob** | NLP sentiment analysis |
| **yfinance** | Yahoo Finance market data |
| **Groq SDK** | LLM inference (Llama 3.3 70B) |
| **Redis** | Response caching |
| **pandas** | Data processing |
| **httpx** | Async HTTP client |

### Infrastructure
| Technology | Purpose |
|------------|---------|
| **Docker Compose** | Multi-service orchestration |
| **PostgreSQL 16 + pgvector** | Relational DB + vector similarity search |
| **Redis 7 Alpine** | In-memory cache |

---

## Project Structure

```
PersonalFinanceApp/
│
├── sentix_invest_frontend/          # Flutter mobile application
│   └── lib/
│       ├── main.dart                # App entry point
│       ├── config/theme/            # Dark theme configuration
│       ├── core/
│       │   ├── network/             # Dio HTTP client + interceptors
│       │   └── services/            # Push notification service
│       └── features/
│           ├── ai_analysis/         # AI stock analysis + RAG chat
│           ├── alert/               # Price alert management
│           ├── analytics/           # Portfolio risk analytics
│           ├── auth/                # Login & registration
│           ├── crypto/              # Cryptocurrency markets
│           ├── dashboard/           # Main dashboard hub
│           ├── dividends/           # Dividend tracking
│           ├── earnings/            # Earnings calendar
│           ├── economic_calendar/   # Global economic events
│           ├── forex/               # Foreign exchange rates
│           ├── market/              # Stock markets & detail view
│           ├── news/                # Stock news with sentiment
│           ├── payment/             # Iyzico checkout integration
│           ├── portfolio/           # Portfolio holdings & summary
│           ├── trading/             # Buy & sell stocks
│           └── watchlist/           # Watchlist management
│
├── sentix-invest-backend/           # Spring Boot backend
│   ├── docker-compose.yml           # Full stack orchestration
│   ├── Dockerfile                   # Backend container
│   ├── init-pgvector.sql            # pgvector extension setup
│   ├── pom.xml                      # Maven dependencies
│   └── src/main/java/com/sentix/
│       ├── api/                     # REST controllers & DTOs
│       │   ├── ai/                  # AI analysis endpoints
│       │   ├── auth/                # Auth (register, login)
│       │   ├── crypto/              # Crypto endpoints
│       │   ├── forex/               # Forex endpoints
│       │   ├── calendar/            # Economic calendar
│       │   ├── portfolio/           # Portfolio management
│       │   ├── stock/               # Stock data & analytics
│       │   ├── trading/             # Trade execution
│       │   ├── watchlist/           # Watchlist CRUD
│       │   ├── alert/               # Price alerts
│       │   ├── payment/             # Payment processing
│       │   └── user/                # User profile
│       ├── domain/                  # JPA entities
│       ├── infrastructure/          # Repos, security, integrations
│       ├── service/                 # Push notifications
│       └── config/                  # Security, Firebase, WebClient
│
├── mcp-server/                      # FastAPI MCP server
│   ├── Dockerfile                   # MCP container
│   ├── main.py                      # All API endpoints (~2200 lines)
│   ├── requirements.txt             # Python dependencies
│   └── rag/                         # RAG pipeline
│       ├── embeddings.py            # sentence-transformers embeddings
│       ├── vector_store.py          # pgvector operations
│       ├── retriever.py             # Semantic retrieval + context building
│       └── ingestion.py             # Document ingestion pipeline
│
└── figs/                            # App screenshots
```

---

## Getting Started

### Prerequisites

- **Docker** & **Docker Compose** (v2+)
- **Flutter SDK** (3.10+)
- **Java 21** (for local backend development)

### 1. Clone the Repository

```bash
git clone https://github.com/beyazittur/PersonalFinanceApp.git
cd PersonalFinanceApp
```

### 2. Configure Environment Variables

Create a `.env` file in `sentix-invest-backend/`:

```env
# API Keys (free tiers available)
GNEWS_API_KEY=your_gnews_api_key
FINNHUB_API_KEY=your_finnhub_api_key
GROQ_API_KEY=your_groq_api_key
EXCHANGERATE_API_KEY=your_exchangerate_api_key

# JWT
JWT_SECRET=your_jwt_secret_key

# Firebase (optional, for push notifications)
FIREBASE_CREDENTIALS_PATH=/path/to/firebase-credentials.json

# Iyzico (optional, for payments)
IYZIPAY_API_KEY=your_iyzico_api_key
IYZIPAY_SECRET_KEY=your_iyzico_secret_key
```

### 3. Start the Backend Stack

```bash
cd sentix-invest-backend
docker compose up --build
```

This starts **4 services:**
- Spring Boot backend on `:8080`
- FastAPI MCP server on `:8000`
- PostgreSQL 16 (pgvector) on `:5432`
- Redis 7 on `:6380`

### 4. Run the Flutter App

```bash
cd sentix_invest_frontend
flutter pub get
flutter run
```

---

## API Reference

### Backend Endpoints (`localhost:8080`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/auth/register` | — | Register new user |
| `POST` | `/api/v1/auth/authenticate` | — | Login, returns JWT |
| `GET` | `/api/v1/users/me` | JWT | Get current user profile |
| `GET` | `/api/v1/stocks/{symbol}` | — | Get stock quote |
| `GET` | `/api/v1/stocks/{symbol}/history` | — | Historical data |
| `GET` | `/api/v1/stocks/{symbol}/news` | — | Stock news + sentiment |
| `GET` | `/api/v1/stocks/analytics/risk` | — | Portfolio risk analysis |
| `GET` | `/api/v1/stocks/dividends/{symbol}` | — | Dividend data |
| `GET` | `/api/v1/stocks/earnings/{symbol}` | — | Earnings data |
| `GET` | `/api/v1/markets/summary` | — | Market indices |
| `GET` | `/api/v1/ai/analyze/{symbol}` | — | AI stock analysis |
| `POST` | `/api/v1/ai/chat` | JWT | AI chat with RAG |
| `GET` | `/api/v1/ai/rag/status` | — | RAG system health |
| `GET` | `/api/v1/crypto/markets` | — | Top cryptocurrencies |
| `GET` | `/api/v1/forex/rates` | — | Forex rates |
| `GET` | `/api/v1/forex/convert` | — | Currency conversion |
| `GET` | `/api/v1/calendar/economic` | — | Economic events |
| `GET` | `/api/v1/portfolio` | JWT | Portfolio holdings |
| `POST` | `/api/v1/trading/buy` | JWT | Buy stock |
| `POST` | `/api/v1/trading/sell` | JWT | Sell stock |
| `GET` | `/api/v1/watchlist` | JWT | Watchlist items |
| `POST` | `/api/v1/alerts` | JWT | Create price alert |

### MCP Server Endpoints (`localhost:8000`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/stock/{symbol}` | Real-time stock quote |
| `GET` | `/market-summary` | BIST 100, NASDAQ, S&P 500 |
| `GET` | `/stock/{symbol}/history` | OHLCV historical data |
| `GET` | `/news/{symbol}` | News + sentiment + RAG ingestion |
| `GET` | `/analytics/risk` | Risk metrics (Beta, VaR, Sharpe) |
| `GET` | `/dividends/{symbol}` | Dividend tracking |
| `GET` | `/earnings/{symbol}` | Earnings calendar |
| `GET` | `/calendar/economic` | Economic events |
| `GET` | `/ai/analyze/{symbol}` | RAG-enhanced AI analysis |
| `POST` | `/ai/chat` | RAG-enhanced conversational AI |
| `GET` | `/ai/rag/status` | RAG health check |
| `POST` | `/ai/rag/ingest` | Manual RAG ingestion |
| `GET` | `/crypto/markets` | Crypto market data |
| `GET` | `/crypto/quote/{symbol}` | Crypto quote |
| `GET` | `/forex/rates` | Forex rates |
| `GET` | `/forex/convert` | Currency conversion |
| `POST` | `/analyze-sentiment` | NLP sentiment analysis |

---

## Roadmap

| Feature | Effort | Status |
|---------|--------|--------|
| Scheduled price alert checking (cron) | Low | Planned |
| Real portfolio performance snapshots | Medium | Planned |
| WebSocket live price streaming | Medium | Planned |
| Paper trading mode | Low | Planned |
| Pagination on list endpoints | Low | Planned |
| Rate limiting on public endpoints | Low | Planned |
| Two-factor authentication (TOTP) | Medium | Planned |
| Tax reporting (capital gains/losses) | Medium | Planned |
| Multi-currency portfolio normalization | Medium | Planned |
| Social / copy trading | High | Planned |

---

<p align="center">
  Built with ❤️ using Flutter, Spring Boot, FastAPI, and AI
</p>
