from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uvicorn
import pandas as pd
import io
from textblob import TextBlob
import yfinance as yf
from datetime import datetime, timedelta
import random
import redis
import json
import os
import httpx
import logging
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ===== Redis Cache Configuration =====
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

# Initialize Redis client with connection pool
try:
    redis_client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5
    )
    redis_client.ping()
    print(f"✅ Connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
    REDIS_AVAILABLE = True
except Exception as e:
    print(f"⚠️ Redis not available: {e}. Running without caching.")
    redis_client = None
    REDIS_AVAILABLE = False

# Cache TTL settings (in seconds)
CACHE_TTL = {
    "stock_quote": 60,          # 1 minute for real-time quotes
    "market_summary": 60,       # 1 minute for market indices
    "stock_history": 300,       # 5 minutes for historical data
    "news": 900,                # 15 minutes for news
    "dividends": 3600,          # 1 hour for dividend data
    "earnings": 3600,           # 1 hour for earnings data
    "risk": 1800,               # 30 minutes for risk metrics
    "crypto": 60,               # 1 minute for crypto prices
    "forex": 300,               # 5 minutes for forex rates
    "economic_calendar": 1800,  # 30 minutes for economic events
    "ai_analysis": 3600,        # 1 hour for AI analysis
}

# ===== Free API Keys (from environment variables) =====
GNEWS_API_KEY = os.getenv("GNEWS_API_KEY", "")  # Free tier: 100 requests/day
FINNHUB_API_KEY = os.getenv("FINNHUB_API_KEY", "")  # Free tier: 60 calls/minute
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")  # Free tier available
COINGECKO_API_URL = "https://api.coingecko.com/api/v3"  # No key needed for basic
EXCHANGERATE_API_KEY = os.getenv("EXCHANGERATE_API_KEY", "")  # Free tier available

# ===== RAG Configuration =====
RAG_ENABLED = os.getenv("RAG_ENABLED", "true").lower() == "true"

# Initialize RAG components (lazy, only if enabled)
rag_retriever = None
rag_ingestion = None
rag_embedding_service = None
rag_vector_store = None

def initialize_rag():
    """Initialize RAG components. Gracefully degrades if unavailable."""
    global rag_retriever, rag_ingestion, rag_embedding_service, rag_vector_store
    if not RAG_ENABLED:
        logger.info("⏭️ RAG is disabled via RAG_ENABLED=false")
        return

    try:
        from rag.embeddings import EmbeddingService
        from rag.vector_store import VectorStore
        from rag.retriever import RAGRetriever
        from rag.ingestion import IngestionPipeline

        rag_embedding_service = EmbeddingService()
        rag_vector_store = VectorStore()
        rag_vector_store.initialize()

        if rag_embedding_service.is_available and rag_vector_store.is_available:
            rag_retriever = RAGRetriever(rag_embedding_service, rag_vector_store)
            rag_ingestion = IngestionPipeline(rag_embedding_service, rag_vector_store)

            # Seed financial education content on first run
            rag_ingestion.ingest_financial_education()

            logger.info("✅ RAG system initialized successfully")
        else:
            logger.warning("⚠️ RAG components partially unavailable, running without RAG")
    except Exception as e:
        logger.error(f"❌ RAG initialization failed: {e}. Running without RAG.")
        rag_retriever = None
        rag_ingestion = None

def cache_get(key: str) -> Optional[Any]:
    """Get value from cache"""
    if not REDIS_AVAILABLE or redis_client is None:
        return None
    try:
        value = redis_client.get(key)
        if value:
            return json.loads(value)
    except Exception as e:
        print(f"Cache get error for {key}: {e}")
    return None

def cache_set(key: str, value: Any, ttl_type: str = "stock_quote") -> bool:
    """Set value in cache with TTL"""
    if not REDIS_AVAILABLE or redis_client is None:
        return False
    try:
        ttl = CACHE_TTL.get(ttl_type, 60)
        redis_client.setex(key, ttl, json.dumps(value))
        return True
    except Exception as e:
        print(f"Cache set error for {key}: {e}")
    return False

@asynccontextmanager
async def lifespan(app):
    """Application lifespan: initialize RAG on startup."""
    initialize_rag()
    yield

app = FastAPI(title="SentixInvest MCP Server", version="2.0.0", lifespan=lifespan)

# ===== Sentiment Analysis Models =====
class SentinelRequest(BaseModel):
    text: str

class SentinelResponse(BaseModel):
    polarity: float
    subjectivity: float
    sentiment: str

# ===== Stock Data Models =====
class StockQuote(BaseModel):
    symbol: str
    name: str
    price: float
    change: float
    changePercent: float
    currency: str
    marketState: str
    timestamp: str

class MarketIndex(BaseModel):
    symbol: str
    name: str
    price: float
    change: float
    changePercent: float

class MarketSummary(BaseModel):
    bist100: Optional[MarketIndex] = None
    nasdaq: Optional[MarketIndex] = None
    sp500: Optional[MarketIndex] = None
    timestamp: str

class StockHistory(BaseModel):
    symbol: str
    data: List[Dict[str, Any]]
    period: str

# ===== Health Check =====
@app.get("/")
def read_root():
    return {"status": "healthy", "service": "sentix-mcp-server"}

# ===== Sentiment Analysis Endpoints =====
@app.post("/analyze-sentiment", response_model=SentinelResponse)
def analyze_sentiment(request: SentinelRequest):
    analysis = TextBlob(request.text)
    polarity = analysis.sentiment.polarity
    
    sentiment = "NEUTRAL"
    if polarity > 0.1:
        sentiment = "BULLISH"
    elif polarity < -0.1:
        sentiment = "BEARISH"
        
    return SentinelResponse(
        polarity=polarity,
        subjectivity=analysis.sentiment.subjectivity,
        sentiment=sentiment
    )

# ===== Portfolio Analysis Endpoint =====
@app.post("/analyze-portfolio")
async def analyze_portfolio(file: UploadFile = File(...)):
    if not file.filename.endswith(('.xlsx', '.xls', '.csv')):
        raise HTTPException(status_code=400, detail="Invalid file format. Please upload Excel or CSV.")
    
    try:
        contents = await file.read()
        if file.filename.endswith('.csv'):
            df = pd.read_csv(io.BytesIO(contents))
        else:
            df = pd.read_excel(io.BytesIO(contents))
            
        summary = {
            "total_rows": len(df),
            "columns": list(df.columns),
            "preview": df.head(5).to_dict(orient='records')
        }
        
        return {"status": "success", "analysis": summary}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error analyzing portfolio: {str(e)}")

# ===== Stock Data Endpoints =====

# Simple cache for stock names (to avoid rate limited info calls)
STOCK_NAMES = {
    "AAPL": "Apple Inc.",
    "GOOGL": "Alphabet Inc.",
    "MSFT": "Microsoft Corporation",
    "AMZN": "Amazon.com Inc.",
    "TSLA": "Tesla Inc.",
    "META": "Meta Platforms Inc.",
    "NVDA": "NVIDIA Corporation",
    "JPM": "JPMorgan Chase & Co.",
    "V": "Visa Inc.",
    "JNJ": "Johnson & Johnson",
    "THYAO.IS": "Turkish Airlines",
    "GARAN.IS": "Garanti BBVA",
    "AKBNK.IS": "Akbank",
    "ISCTR.IS": "Türkiye İş Bankası",
    "KCHOL.IS": "Koç Holding",
    "SAHOL.IS": "Sabancı Holding",
    "SISE.IS": "Şişecam",
    "TUPRS.IS": "Tüpraş",
    "EREGL.IS": "Erdemir",
    "BIMAS.IS": "BİM Mağazaları",
    "XU100.IS": "BIST 100",
    "^IXIC": "NASDAQ Composite",
    "^GSPC": "S&P 500",
}

# Mock price data for fallback when Yahoo Finance rate limits
MOCK_PRICES = {
    "AAPL": 228.50,
    "GOOGL": 195.25,
    "MSFT": 420.30,
    "AMZN": 225.75,
    "TSLA": 410.50,
    "META": 625.80,
    "NVDA": 142.90,
    "JPM": 260.40,
    "V": 310.75,
    "JNJ": 145.20,
    "THYAO.IS": 312.50,
    "GARAN.IS": 156.80,
    "AKBNK.IS": 72.45,
    "ISCTR.IS": 19.85,
    "KCHOL.IS": 245.60,
    "SAHOL.IS": 98.75,
    "SISE.IS": 68.90,
    "TUPRS.IS": 185.30,
    "EREGL.IS": 58.25,
    "BIMAS.IS": 615.40,
    "XU100.IS": 9856.42,
    "^IXIC": 19832.15,
    "^GSPC": 6058.27,
}

def get_mock_stock_data(symbol: str) -> Optional[StockQuote]:
    """Generate mock stock data when Yahoo Finance is rate limited"""
    symbol_upper = symbol.upper()
    base_price = MOCK_PRICES.get(symbol_upper, 100.0)
    
    # Add small random variation to simulate live data
    variation = random.uniform(-0.02, 0.02)  # -2% to +2%
    current_price = base_price * (1 + variation)
    change = current_price - base_price
    change_percent = variation * 100
    
    name = STOCK_NAMES.get(symbol_upper, symbol)
    currency = "TRY" if ".IS" in symbol_upper else "USD"
    
    return StockQuote(
        symbol=symbol_upper,
        name=f"{name} (Demo)",  # Mark as demo data
        price=round(current_price, 2),
        change=round(change, 2),
        changePercent=round(change_percent, 2),
        currency=currency,
        marketState="DEMO",
        timestamp=datetime.now().isoformat()
    )

def get_stock_data(symbol: str) -> Optional[StockQuote]:
    """Fetch current stock data from Yahoo Finance, with mock fallback"""
    try:
        ticker = yf.Ticker(symbol)
        # Use history instead of info - it's less rate-limited
        hist = ticker.history(period="5d")
        
        if hist.empty:
            print(f"No history data for {symbol} - using mock data")
            return get_mock_stock_data(symbol)
        
        # Get latest price from history
        current_price = float(hist['Close'].iloc[-1])
        prev_close = float(hist['Close'].iloc[-2]) if len(hist) > 1 else current_price
        
        change = current_price - prev_close
        change_percent = (change / prev_close * 100) if prev_close else 0
        
        # Get name from cache or use symbol
        name = STOCK_NAMES.get(symbol.upper(), symbol)
        
        # Determine currency based on symbol
        currency = "TRY" if ".IS" in symbol.upper() else "USD"
        
        return StockQuote(
            symbol=symbol.upper(),
            name=name,
            price=round(current_price, 2),
            change=round(change, 2),
            changePercent=round(change_percent, 2),
            currency=currency,
            marketState="REGULAR",
            timestamp=datetime.now().isoformat()
        )
    except Exception as e:
        print(f"Error fetching {symbol}: {e} - using mock data")
        return get_mock_stock_data(symbol)

def get_mock_index_data(symbol: str, name: str) -> MarketIndex:
    """Generate mock index data when Yahoo Finance is rate limited"""
    base_price = MOCK_PRICES.get(symbol, 10000.0)
    variation = random.uniform(-0.01, 0.01)  # -1% to +1%
    current_price = base_price * (1 + variation)
    change = current_price - base_price
    
    return MarketIndex(
        symbol=symbol,
        name=f"{name} (Demo)",
        price=round(current_price, 2),
        change=round(change, 2),
        changePercent=round(variation * 100, 2)
    )

def get_index_data(symbol: str, name: str) -> Optional[MarketIndex]:
    """Fetch index data from Yahoo Finance with mock fallback"""
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period="2d")
        
        if hist.empty:
            print(f"No index data for {symbol} - using mock data")
            return get_mock_index_data(symbol, name)
            
        current_price = float(hist['Close'].iloc[-1])
        prev_close = float(hist['Close'].iloc[-2]) if len(hist) > 1 else current_price
        
        change = current_price - prev_close
        change_percent = (change / prev_close * 100) if prev_close else 0
        
        return MarketIndex(
            symbol=symbol,
            name=name,
            price=round(current_price, 2),
            change=round(change, 2),
            changePercent=round(change_percent, 2)
        )
    except Exception as e:
        print(f"Error fetching index {symbol}: {e} - using mock data")
        return get_mock_index_data(symbol, name)

@app.get("/stock/{symbol}", response_model=StockQuote)
def get_stock(symbol: str):
    """Get current stock quote by symbol (e.g., AAPL, THYAO.IS for Turkish stocks)"""
    # Check cache first
    cache_key = f"stock_quote:{symbol.upper()}"
    cached = cache_get(cache_key)
    if cached:
        print(f"📦 Cache hit for {symbol}")
        return StockQuote(**cached)
    
    data = get_stock_data(symbol)
    if not data:
        raise HTTPException(status_code=404, detail=f"Stock {symbol} not found")
    
    # Cache the result
    cache_set(cache_key, data.model_dump(), "stock_quote")
    return data

@app.get("/market-summary", response_model=MarketSummary)
def get_market_summary():
    """Get market summary for BIST100, NASDAQ, and S&P500"""
    # Check cache first
    cache_key = "market_summary"
    cached = cache_get(cache_key)
    if cached:
        print("📦 Cache hit for market summary")
        return MarketSummary(**cached)
    
    result = MarketSummary(
        bist100=get_index_data("XU100.IS", "BIST 100"),
        nasdaq=get_index_data("^IXIC", "NASDAQ Composite"),
        sp500=get_index_data("^GSPC", "S&P 500"),
        timestamp=datetime.now().isoformat()
    )
    
    cache_set(cache_key, result.model_dump(), "market_summary")
    return result

def get_mock_history_data(symbol: str, period: str) -> List[Dict[str, Any]]:
    """Generate mock historical data when Yahoo Finance is unavailable"""
    symbol_upper = symbol.upper()
    base_price = MOCK_PRICES.get(symbol_upper, 100.0)
    
    # Determine number of data points based on period
    period_days = {
        "1d": 1,
        "5d": 5,
        "1mo": 22,
        "3mo": 66,
        "6mo": 132,
        "1y": 252,
        "2y": 504,
        "5y": 1260,
        "10y": 2520,
        "ytd": 100,
        "max": 500
    }
    
    num_days = period_days.get(period, 22)
    data = []
    
    current_date = datetime.now()
    current_price = base_price
    
    for i in range(num_days, 0, -1):
        date = current_date - timedelta(days=i)
        if date.weekday() >= 5:  # Skip weekends
            continue
            
        # Generate realistic-looking price movement
        daily_change = random.uniform(-0.03, 0.03)  # -3% to +3%
        current_price = current_price * (1 + daily_change)
        
        high = current_price * (1 + random.uniform(0, 0.02))
        low = current_price * (1 - random.uniform(0, 0.02))
        open_price = low + (high - low) * random.random()
        
        data.append({
            "date": date.strftime("%Y-%m-%d"),
            "open": round(open_price, 2),
            "high": round(high, 2),
            "low": round(low, 2),
            "close": round(current_price, 2),
            "volume": random.randint(10000000, 100000000)
        })
    
    return data

@app.get("/stock/{symbol}/history", response_model=StockHistory)
def get_stock_history(symbol: str, period: str = "1mo"):
    """
    Get historical stock data.
    Valid periods: 1d, 5d, 1mo, 3mo, 6mo, 1y, 2y, 5y, 10y, ytd, max
    """
    valid_periods = ["1d", "5d", "1mo", "3mo", "6mo", "1y", "2y", "5y", "10y", "ytd", "max"]
    if period not in valid_periods:
        raise HTTPException(status_code=400, detail=f"Invalid period. Use one of: {valid_periods}")
    
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period=period)
        
        if hist.empty:
            print(f"No history data for {symbol} with period {period} - using mock data")
            data = get_mock_history_data(symbol, period)
            return StockHistory(
                symbol=symbol.upper(),
                data=data,
                period=period
            )
        
        data = []
        for date, row in hist.iterrows():
            data.append({
                "date": date.strftime("%Y-%m-%d"),
                "open": round(row['Open'], 2),
                "high": round(row['High'], 2),
                "low": round(row['Low'], 2),
                "close": round(row['Close'], 2),
                "volume": int(row['Volume'])
            })
        
        return StockHistory(
            symbol=symbol.upper(),
            data=data,
            period=period
        )
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching history for {symbol}: {e} - using mock data")
        data = get_mock_history_data(symbol, period)
        return StockHistory(
            symbol=symbol.upper(),
            data=data,
            period=period
        )



@app.get("/search/{query}")
def search_stocks(query: str, limit: int = 10):
    """Search for stocks by name or symbol (basic implementation)"""
    # Common Turkish stocks for quick search
    turkish_stocks = {
        "THYAO.IS": "Turkish Airlines",
        "GARAN.IS": "Garanti BBVA",
        "AKBNK.IS": "Akbank",
        "ISCTR.IS": "Türkiye İş Bankası",
        "KCHOL.IS": "Koç Holding",
        "SAHOL.IS": "Sabancı Holding",
        "SISE.IS": "Şişecam",
        "TUPRS.IS": "Tüpraş",
        "EREGL.IS": "Erdemir",
        "BIMAS.IS": "BİM Mağazaları"
    }
    
    # Common US stocks
    us_stocks = {
        "AAPL": "Apple Inc.",
        "GOOGL": "Alphabet Inc.",
        "MSFT": "Microsoft Corporation",
        "AMZN": "Amazon.com Inc.",
        "TSLA": "Tesla Inc.",
        "META": "Meta Platforms Inc.",
        "NVDA": "NVIDIA Corporation",
        "JPM": "JPMorgan Chase & Co.",
        "V": "Visa Inc.",
        "JNJ": "Johnson & Johnson"
    }
    
    all_stocks = {**turkish_stocks, **us_stocks}
    query_lower = query.lower()
    
    results = []
    for symbol, name in all_stocks.items():
        if query_lower in symbol.lower() or query_lower in name.lower():
            results.append({"symbol": symbol, "name": name})
            if len(results) >= limit:
                break
    
    return {"results": results, "query": query}


# ===== Stock News Models =====
class StockNewsItem(BaseModel):
    title: str
    summary: str
    source: str
    url: str
    publishedAt: str
    sentiment: str  # BULLISH, BEARISH, NEUTRAL
    sentimentScore: float  # -1.0 to 1.0

class StockNewsResponse(BaseModel):
    symbol: str
    stockName: str
    news: List[StockNewsItem]


# Simulated news templates for different stocks
NEWS_TEMPLATES = {
    "positive": [
        {"title": "{company} Reports Strong Quarterly Earnings", "summary": "{company} exceeded analyst expectations with a significant increase in revenue and profits."},
        {"title": "{company} Announces Strategic Partnership", "summary": "New collaboration expected to accelerate growth and expand market reach for {company}."},
        {"title": "Analysts Upgrade {company} Stock Rating", "summary": "Major investment banks raise price targets citing strong fundamentals and growth prospects."},
        {"title": "{company} Expands Into New Markets", "summary": "The company announces expansion plans that could significantly increase its addressable market."},
        {"title": "{company} Launches Innovative New Product", "summary": "Early reviews praise the new offering, with analysts expecting strong sales."},
    ],
    "negative": [
        {"title": "{company} Faces Regulatory Scrutiny", "summary": "Regulators investigate potential compliance issues, creating uncertainty for investors."},
        {"title": "{company} Reports Disappointing Revenue", "summary": "Quarterly results fall short of expectations, leading to revised guidance."},
        {"title": "Supply Chain Issues Impact {company}", "summary": "Ongoing logistics challenges may affect near-term profitability."},
        {"title": "Competition Intensifies for {company}", "summary": "New market entrants are pressuring margins and market share."},
    ],
    "neutral": [
        {"title": "{company} Hosts Annual Investor Day", "summary": "Management outlines strategic priorities and long-term vision for shareholders."},
        {"title": "{company} Names New Executive", "summary": "Leadership change signals potential shift in company strategy."},
        {"title": "Industry Analysis: {company}'s Market Position", "summary": "Comprehensive review of competitive landscape and growth opportunities."},
        {"title": "{company} Stock Sees High Trading Volume", "summary": "Unusual activity as investors assess market conditions."},
    ]
}

NEWS_SOURCES = ["Bloomberg", "Reuters", "CNBC", "Financial Times", "Wall Street Journal", "MarketWatch", "Yahoo Finance", "Investing.com"]


def generate_news_for_stock(symbol: str, count: int = 5) -> List[StockNewsItem]:
    """Generate simulated news articles for a given stock"""
    stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
    news_items = []
    
    # Generate a mix of positive, negative, and neutral news
    sentiments = ["positive", "positive", "neutral", "neutral", "negative"]
    random.shuffle(sentiments)
    
    for i in range(min(count, len(sentiments))):
        sentiment_type = sentiments[i]
        templates = NEWS_TEMPLATES[sentiment_type]
        template = random.choice(templates)
        
        # Calculate published time (random within last 7 days)
        hours_ago = random.randint(1, 168)  # 1 hour to 7 days
        published_time = datetime.now() - timedelta(hours=hours_ago)
        
        # Generate sentiment score based on type
        if sentiment_type == "positive":
            sentiment_score = random.uniform(0.3, 0.9)
            sentiment = "BULLISH"
        elif sentiment_type == "negative":
            sentiment_score = random.uniform(-0.9, -0.3)
            sentiment = "BEARISH"
        else:
            sentiment_score = random.uniform(-0.2, 0.2)
            sentiment = "NEUTRAL"
        
        news_items.append(StockNewsItem(
            title=template["title"].format(company=stock_name),
            summary=template["summary"].format(company=stock_name),
            source=random.choice(NEWS_SOURCES),
            url=f"https://example.com/news/{symbol.lower()}-{i}",
            publishedAt=published_time.isoformat(),
            sentiment=sentiment,
            sentimentScore=round(sentiment_score, 2)
        ))
    
    # Sort by published date (most recent first)
    news_items.sort(key=lambda x: x.publishedAt, reverse=True)
    return news_items


@app.get("/news/{symbol}", response_model=StockNewsResponse)
async def get_stock_news(symbol: str, count: int = 5):
    """
    Get news articles for a specific stock.
    Uses GNews API for real news with TextBlob sentiment analysis.
    Falls back to simulated news if API is unavailable.
    """
    symbol_upper = symbol.upper()
    stock_name = STOCK_NAMES.get(symbol_upper, symbol)
    
    # Check cache first
    cache_key = f"news:{symbol_upper}:{count}"
    cached = cache_get(cache_key)
    if cached:
        print(f"📦 Cache hit for news {symbol}")
        return StockNewsResponse(**cached)
    
    # Limit count to reasonable range
    count = max(1, min(count, 10))
    
    # Try to get real news from GNews API
    news = await fetch_real_news(symbol_upper, stock_name, count)
    
    if not news:
        # Fallback to simulated news
        print(f"⚠️ Using simulated news for {symbol}")
        news = generate_news_for_stock(symbol_upper, count)
    
    result = StockNewsResponse(
        symbol=symbol_upper,
        stockName=stock_name,
        news=news
    )
    
    cache_set(cache_key, result.model_dump(), "news")

    # RAG: Ingest news articles into vector store (best-effort, non-blocking)
    if rag_ingestion and news:
        try:
            news_dicts = [n.model_dump() for n in news]
            rag_ingestion.ingest_news_articles(news_dicts, symbol_upper)
        except Exception as e:
            logger.warning(f"RAG news ingestion failed for {symbol_upper}: {e}")

    return result


async def fetch_real_news(symbol: str, stock_name: str, count: int = 5) -> List[StockNewsItem]:
    """Fetch real news from GNews API with sentiment analysis"""
    if not GNEWS_API_KEY:
        print("⚠️ GNEWS_API_KEY not set, using simulated news")
        return []
    
    try:
        # Use stock name for better search results
        search_query = stock_name.replace("Inc.", "").replace("Corporation", "").strip()
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            url = "https://gnews.io/api/v4/search"
            params = {
                "q": f"{search_query} stock",
                "lang": "en",
                "country": "us",
                "max": count,
                "apikey": GNEWS_API_KEY
            }
            
            response = await client.get(url, params=params)
            
            if response.status_code != 200:
                print(f"⚠️ GNews API error: {response.status_code}")
                return []
            
            data = response.json()
            articles = data.get("articles", [])
            
            news_items = []
            for article in articles:
                # Analyze sentiment of title and description
                title = article.get("title", "")
                description = article.get("description", "")
                content = f"{title} {description}"
                
                analysis = TextBlob(content)
                polarity = analysis.sentiment.polarity
                
                if polarity > 0.1:
                    sentiment = "BULLISH"
                elif polarity < -0.1:
                    sentiment = "BEARISH"
                else:
                    sentiment = "NEUTRAL"
                
                news_items.append(StockNewsItem(
                    title=title,
                    summary=description or "No summary available",
                    source=article.get("source", {}).get("name", "Unknown"),
                    url=article.get("url", ""),
                    publishedAt=article.get("publishedAt", datetime.now().isoformat()),
                    sentiment=sentiment,
                    sentimentScore=round(polarity, 2)
                ))
            
            print(f"✅ Fetched {len(news_items)} real news articles for {symbol}")
            return news_items
            
    except Exception as e:
        print(f"❌ Error fetching news from GNews: {e}")
        return []


# ===== Risk Analysis Models =====
class StockRiskMetrics(BaseModel):
    symbol: str
    stockName: str
    beta: float  # Relative volatility vs market
    volatility: float  # Annualized standard deviation
    sharpeRatio: float  # Risk-adjusted return
    maxDrawdown: float  # Maximum peak-to-trough decline
    valueAtRisk: float  # 95% VaR
    riskLevel: str  # LOW, MEDIUM, HIGH

class PortfolioRiskResponse(BaseModel):
    overallRisk: str  # LOW, MEDIUM, HIGH
    portfolioBeta: float
    portfolioVolatility: float
    portfolioSharpeRatio: float
    diversificationScore: float  # 0-100
    correlationRisk: str
    stockRisks: List[StockRiskMetrics]


def calculate_risk_metrics(symbol: str, period: str = "1y") -> Optional[StockRiskMetrics]:
    """Calculate risk metrics for a single stock"""
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period=period)
        
        if hist.empty or len(hist) < 20:
            return generate_mock_risk_metrics(symbol)
        
        # Calculate daily returns
        returns = hist['Close'].pct_change().dropna()
        
        # Get S&P 500 for beta calculation
        sp500 = yf.Ticker("^GSPC")
        sp500_hist = sp500.history(period=period)
        
        if not sp500_hist.empty:
            sp500_returns = sp500_hist['Close'].pct_change().dropna()
            # Align dates
            common_dates = returns.index.intersection(sp500_returns.index)
            if len(common_dates) > 20:
                stock_ret = returns.loc[common_dates]
                market_ret = sp500_returns.loc[common_dates]
                
                # Beta = Cov(stock, market) / Var(market)
                covariance = stock_ret.cov(market_ret)
                market_variance = market_ret.var()
                beta = covariance / market_variance if market_variance > 0 else 1.0
            else:
                beta = 1.0
        else:
            beta = 1.0
        
        # Annualized volatility (std * sqrt(252))
        volatility = returns.std() * (252 ** 0.5) * 100
        
        # Sharpe Ratio (assume risk-free rate of 4%)
        risk_free_rate = 0.04
        annualized_return = returns.mean() * 252
        sharpe_ratio = (annualized_return - risk_free_rate) / (returns.std() * (252 ** 0.5)) if returns.std() > 0 else 0
        
        # Maximum Drawdown
        cumulative = (1 + returns).cumprod()
        peak = cumulative.expanding(min_periods=1).max()
        drawdown = (cumulative - peak) / peak
        max_drawdown = abs(drawdown.min()) * 100
        
        # Value at Risk (95% confidence, 1-day)
        var_95 = abs(returns.quantile(0.05)) * 100
        
        # Determine risk level
        if volatility > 40 or abs(beta) > 1.5:
            risk_level = "HIGH"
        elif volatility > 25 or abs(beta) > 1.2:
            risk_level = "MEDIUM"
        else:
            risk_level = "LOW"
        
        stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
        
        return StockRiskMetrics(
            symbol=symbol.upper(),
            stockName=stock_name,
            beta=round(beta, 2),
            volatility=round(volatility, 2),
            sharpeRatio=round(sharpe_ratio, 2),
            maxDrawdown=round(max_drawdown, 2),
            valueAtRisk=round(var_95, 2),
            riskLevel=risk_level
        )
        
    except Exception as e:
        print(f"Error calculating risk for {symbol}: {e}")
        return generate_mock_risk_metrics(symbol)


def generate_mock_risk_metrics(symbol: str) -> StockRiskMetrics:
    """Generate mock risk metrics when real data is unavailable"""
    stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
    
    # Generate realistic mock values based on stock type
    if ".IS" in symbol.upper():
        # Turkish stocks typically higher volatility
        beta = round(random.uniform(0.8, 1.5), 2)
        volatility = round(random.uniform(30, 50), 2)
    elif symbol.upper() in ["AAPL", "MSFT", "GOOGL", "JNJ", "V"]:
        # Large cap tech, more stable
        beta = round(random.uniform(0.9, 1.3), 2)
        volatility = round(random.uniform(20, 35), 2)
    else:
        beta = round(random.uniform(1.0, 1.6), 2)
        volatility = round(random.uniform(25, 45), 2)
    
    sharpe_ratio = round(random.uniform(-0.5, 2.0), 2)
    max_drawdown = round(random.uniform(10, 40), 2)
    var_95 = round(random.uniform(2, 6), 2)
    
    if volatility > 40:
        risk_level = "HIGH"
    elif volatility > 25:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"
    
    return StockRiskMetrics(
        symbol=symbol.upper(),
        stockName=f"{stock_name} (Demo)",
        beta=beta,
        volatility=volatility,
        sharpeRatio=sharpe_ratio,
        maxDrawdown=max_drawdown,
        valueAtRisk=var_95,
        riskLevel=risk_level
    )


@app.get("/analytics/risk", response_model=PortfolioRiskResponse)
def get_portfolio_risk(symbols: str):
    """
    Get risk analysis for a portfolio of stocks.
    Pass symbols as comma-separated string, e.g., ?symbols=AAPL,MSFT,GOOGL
    """
    symbol_list = [s.strip().upper() for s in symbols.split(",") if s.strip()]
    
    if not symbol_list:
        raise HTTPException(status_code=400, detail="No symbols provided")
    
    stock_risks = []
    total_beta = 0
    total_volatility = 0
    high_risk_count = 0
    
    for symbol in symbol_list:
        risk = calculate_risk_metrics(symbol)
        if risk:
            stock_risks.append(risk)
            total_beta += risk.beta
            total_volatility += risk.volatility
            if risk.riskLevel == "HIGH":
                high_risk_count += 1
    
    if not stock_risks:
        raise HTTPException(status_code=404, detail="No risk data available")
    
    n = len(stock_risks)
    avg_beta = total_beta / n
    avg_volatility = total_volatility / n
    
    # Portfolio diversification reduces volatility
    diversification_benefit = 1 - (0.05 * (n - 1)) if n > 1 else 1
    portfolio_volatility = avg_volatility * max(0.5, diversification_benefit)
    
    # Simplified Sharpe calculation
    avg_sharpe = sum(r.sharpeRatio for r in stock_risks) / n
    
    # Diversification score (more stocks = better, up to a point)
    diversification_score = min(100, 30 + (n * 15))
    
    # Correlation risk
    if n == 1:
        correlation_risk = "HIGH"
    elif n < 3:
        correlation_risk = "MEDIUM"
    else:
        correlation_risk = "LOW"
    
    # Overall risk level
    if high_risk_count > n / 2 or portfolio_volatility > 35:
        overall_risk = "HIGH"
    elif high_risk_count > 0 or portfolio_volatility > 25:
        overall_risk = "MEDIUM"
    else:
        overall_risk = "LOW"
    
    return PortfolioRiskResponse(
        overallRisk=overall_risk,
        portfolioBeta=round(avg_beta, 2),
        portfolioVolatility=round(portfolio_volatility, 2),
        portfolioSharpeRatio=round(avg_sharpe, 2),
        diversificationScore=round(diversification_score, 1),
        correlationRisk=correlation_risk,
        stockRisks=stock_risks
    )


# ===== Dividend Tracker Models =====
class DividendPayment(BaseModel):
    exDate: str
    paymentDate: str
    amount: float
    currency: str

class StockDividend(BaseModel):
    symbol: str
    stockName: str
    hasDividends: bool
    annualYield: float  # Dividend yield percentage
    annualDividend: float  # Total annual dividend per share
    payoutFrequency: str  # QUARTERLY, MONTHLY, ANNUALLY, IRREGULAR
    lastDividend: Optional[DividendPayment] = None
    nextDividend: Optional[DividendPayment] = None
    history: List[DividendPayment]


def get_dividend_data(symbol: str) -> StockDividend:
    """Get dividend information for a stock"""
    stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
    
    try:
        ticker = yf.Ticker(symbol)
        dividends = ticker.dividends
        info = ticker.info
        
        if dividends.empty:
            return StockDividend(
                symbol=symbol.upper(),
                stockName=stock_name,
                hasDividends=False,
                annualYield=0,
                annualDividend=0,
                payoutFrequency="NONE",
                lastDividend=None,
                nextDividend=None,
                history=[]
            )
        
        # Get recent dividend history (last 2 years)
        recent_dividends = dividends.tail(8)
        history = []
        
        for date, amount in recent_dividends.items():
            history.append(DividendPayment(
                exDate=date.strftime("%Y-%m-%d"),
                paymentDate=date.strftime("%Y-%m-%d"),  # yfinance doesn't always have payment date
                amount=round(float(amount), 4),
                currency="USD"
            ))
        
        history.reverse()  # Most recent first
        
        # Calculate annual dividend and yield
        annual_dividend = info.get("dividendRate", 0) or 0
        dividend_yield = info.get("dividendYield", 0) or 0
        
        # Determine payout frequency
        if len(recent_dividends) >= 4:
            # Calculate average gap between payments
            dates = list(recent_dividends.index)
            if len(dates) >= 2:
                gaps = []
                for i in range(1, len(dates)):
                    gap = (dates[i] - dates[i-1]).days
                    gaps.append(gap)
                avg_gap = sum(gaps) / len(gaps)
                
                if avg_gap < 45:
                    payout_frequency = "MONTHLY"
                elif avg_gap < 120:
                    payout_frequency = "QUARTERLY"
                elif avg_gap < 200:
                    payout_frequency = "SEMI_ANNUALLY"
                else:
                    payout_frequency = "ANNUALLY"
            else:
                payout_frequency = "IRREGULAR"
        else:
            payout_frequency = "IRREGULAR"
        
        last_dividend = history[0] if history else None
        
        # Estimate next dividend (add typical gap to last)
        next_dividend = None
        if last_dividend and payout_frequency in ["QUARTERLY", "MONTHLY"]:
            from datetime import datetime
            last_date = datetime.strptime(last_dividend.exDate, "%Y-%m-%d")
            if payout_frequency == "QUARTERLY":
                next_date = last_date + timedelta(days=90)
            else:
                next_date = last_date + timedelta(days=30)
            
            if next_date > datetime.now():
                next_dividend = DividendPayment(
                    exDate=next_date.strftime("%Y-%m-%d"),
                    paymentDate=(next_date + timedelta(days=7)).strftime("%Y-%m-%d"),
                    amount=last_dividend.amount,
                    currency="USD"
                )
        
        return StockDividend(
            symbol=symbol.upper(),
            stockName=stock_name,
            hasDividends=True,
            annualYield=round(dividend_yield * 100, 2),
            annualDividend=round(annual_dividend, 4),
            payoutFrequency=payout_frequency,
            lastDividend=last_dividend,
            nextDividend=next_dividend,
            history=history
        )
        
    except Exception as e:
        print(f"Error fetching dividends for {symbol}: {e}")
        return generate_mock_dividend(symbol)


def generate_mock_dividend(symbol: str) -> StockDividend:
    """Generate mock dividend data when real data is unavailable"""
    stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
    
    # Known dividend payers
    dividend_stocks = ["AAPL", "MSFT", "JNJ", "V", "JPM", "KO", "PG", "XOM"]
    
    if symbol.upper() in dividend_stocks:
        base_date = datetime.now() - timedelta(days=30)
        history = []
        for i in range(4):
            div_date = base_date - timedelta(days=i * 90)
            amount = round(random.uniform(0.2, 1.0), 4)
            history.append(DividendPayment(
                exDate=div_date.strftime("%Y-%m-%d"),
                paymentDate=(div_date + timedelta(days=7)).strftime("%Y-%m-%d"),
                amount=amount,
                currency="USD"
            ))
        
        return StockDividend(
            symbol=symbol.upper(),
            stockName=f"{stock_name} (Demo)",
            hasDividends=True,
            annualYield=round(random.uniform(0.5, 4.0), 2),
            annualDividend=round(history[0].amount * 4, 2),
            payoutFrequency="QUARTERLY",
            lastDividend=history[0],
            nextDividend=DividendPayment(
                exDate=(datetime.now() + timedelta(days=60)).strftime("%Y-%m-%d"),
                paymentDate=(datetime.now() + timedelta(days=67)).strftime("%Y-%m-%d"),
                amount=history[0].amount,
                currency="USD"
            ),
            history=history
        )
    else:
        return StockDividend(
            symbol=symbol.upper(),
            stockName=f"{stock_name} (Demo)",
            hasDividends=False,
            annualYield=0,
            annualDividend=0,
            payoutFrequency="NONE",
            lastDividend=None,
            nextDividend=None,
            history=[]
        )


@app.get("/dividends/{symbol}", response_model=StockDividend)
def get_stock_dividends(symbol: str):
    """Get dividend information for a stock"""
    return get_dividend_data(symbol.upper())


# ===== Earnings Calendar Models =====
class EarningsReport(BaseModel):
    date: str
    epsActual: Optional[float] = None
    epsEstimate: Optional[float] = None
    revenueActual: Optional[float] = None
    revenueEstimate: Optional[float] = None
    surprise: Optional[float] = None  # EPS surprise percentage
    isBeat: Optional[bool] = None

class StockEarnings(BaseModel):
    symbol: str
    stockName: str
    hasUpcoming: bool
    nextEarningsDate: Optional[str] = None
    daysUntilEarnings: Optional[int] = None
    nextEpsEstimate: Optional[float] = None
    nextRevenueEstimate: Optional[float] = None
    fiscalQuarter: Optional[str] = None
    history: List[EarningsReport]


def get_earnings_data(symbol: str) -> StockEarnings:
    """Get earnings information for a stock"""
    stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
    
    try:
        ticker = yf.Ticker(symbol)
        calendar = ticker.calendar
        earnings = ticker.earnings_dates
        
        history = []
        next_earnings_date = None
        days_until = None
        eps_estimate = None
        revenue_estimate = None
        fiscal_quarter = None
        
        # Process earnings history
        if earnings is not None and not earnings.empty:
            now = datetime.now()
            
            for date_idx in earnings.index:
                try:
                    date = date_idx.to_pydatetime() if hasattr(date_idx, 'to_pydatetime') else date_idx
                    date_str = date.strftime("%Y-%m-%d") if hasattr(date, 'strftime') else str(date_idx)[:10]
                    
                    row = earnings.loc[date_idx]
                    
                    eps_actual = row.get('Reported EPS') if 'Reported EPS' in row else None
                    eps_est = row.get('EPS Estimate') if 'EPS Estimate' in row else None
                    
                    # Check if future earnings
                    if hasattr(date, 'year') and date > now:
                        if next_earnings_date is None:
                            next_earnings_date = date_str
                            days_until = (date - now).days
                            eps_estimate = float(eps_est) if eps_est is not None and not pd.isna(eps_est) else None
                    else:
                        # Past earnings
                        surprise = None
                        is_beat = None
                        if eps_actual is not None and eps_est is not None:
                            if not pd.isna(eps_actual) and not pd.isna(eps_est) and eps_est != 0:
                                surprise = round(((eps_actual - eps_est) / abs(eps_est)) * 100, 2)
                                is_beat = eps_actual > eps_est
                        
                        history.append(EarningsReport(
                            date=date_str,
                            epsActual=float(eps_actual) if eps_actual is not None and not pd.isna(eps_actual) else None,
                            epsEstimate=float(eps_est) if eps_est is not None and not pd.isna(eps_est) else None,
                            revenueActual=None,
                            revenueEstimate=None,
                            surprise=surprise,
                            isBeat=is_beat
                        ))
                except Exception as e:
                    print(f"Error processing earnings date: {e}")
                    continue
            
            # Limit history to last 8 quarters
            history = history[:8]
        
        # Get calendar info for next earnings
        if calendar is not None and not calendar.empty:
            try:
                if 'Earnings Date' in calendar.index:
                    next_date = calendar.loc['Earnings Date']
                    if isinstance(next_date, pd.Series) and len(next_date) > 0:
                        next_date = next_date.iloc[0]
                    if next_date is not None:
                        next_earnings_date = str(next_date)[:10] if next_earnings_date is None else next_earnings_date
            except:
                pass
        
        # Determine fiscal quarter
        if next_earnings_date:
            try:
                date = datetime.strptime(next_earnings_date, "%Y-%m-%d")
                quarter = (date.month - 1) // 3 + 1
                fiscal_quarter = f"Q{quarter} {date.year}"
            except:
                pass
        
        return StockEarnings(
            symbol=symbol.upper(),
            stockName=stock_name,
            hasUpcoming=next_earnings_date is not None,
            nextEarningsDate=next_earnings_date,
            daysUntilEarnings=days_until,
            nextEpsEstimate=eps_estimate,
            nextRevenueEstimate=revenue_estimate,
            fiscalQuarter=fiscal_quarter,
            history=history
        )
        
    except Exception as e:
        print(f"Error fetching earnings for {symbol}: {e}")
        return generate_mock_earnings(symbol)


def generate_mock_earnings(symbol: str) -> StockEarnings:
    """Generate mock earnings data when real data is unavailable"""
    stock_name = STOCK_NAMES.get(symbol.upper(), symbol)
    
    # Generate realistic mock history
    history = []
    base_eps = random.uniform(0.5, 3.0)
    
    for i in range(4):
        quarter_date = datetime.now() - timedelta(days=90 * (i + 1))
        eps_estimate = round(base_eps + random.uniform(-0.2, 0.2), 2)
        eps_actual = round(eps_estimate + random.uniform(-0.1, 0.15), 2)
        surprise = round(((eps_actual - eps_estimate) / abs(eps_estimate)) * 100, 2) if eps_estimate != 0 else 0
        
        history.append(EarningsReport(
            date=quarter_date.strftime("%Y-%m-%d"),
            epsActual=eps_actual,
            epsEstimate=eps_estimate,
            revenueActual=None,
            revenueEstimate=None,
            surprise=surprise,
            isBeat=eps_actual > eps_estimate
        ))
    
    next_date = datetime.now() + timedelta(days=random.randint(15, 60))
    
    return StockEarnings(
        symbol=symbol.upper(),
        stockName=f"{stock_name} (Demo)",
        hasUpcoming=True,
        nextEarningsDate=next_date.strftime("%Y-%m-%d"),
        daysUntilEarnings=(next_date - datetime.now()).days,
        nextEpsEstimate=round(base_eps + random.uniform(-0.1, 0.1), 2),
        nextRevenueEstimate=None,
        fiscalQuarter=f"Q{(next_date.month - 1) // 3 + 1} {next_date.year}",
        history=history
    )


@app.get("/earnings/{symbol}", response_model=StockEarnings)
def get_stock_earnings(symbol: str):
    """Get earnings information for a stock"""
    # Check cache first
    cache_key = f"earnings:{symbol.upper()}"
    cached = cache_get(cache_key)
    if cached:
        print(f"📦 Cache hit for earnings {symbol}")
        return StockEarnings(**cached)
    
    result = get_earnings_data(symbol.upper())
    cache_set(cache_key, result.model_dump(), "earnings")
    return result


# ===== Economic Calendar Models =====
class EconomicEvent(BaseModel):
    date: str
    time: str
    country: str
    event: str
    impact: str  # LOW, MEDIUM, HIGH
    forecast: Optional[str] = None
    previous: Optional[str] = None
    actual: Optional[str] = None

class EconomicCalendarResponse(BaseModel):
    events: List[EconomicEvent]
    fromDate: str
    toDate: str


@app.get("/calendar/economic", response_model=EconomicCalendarResponse)
async def get_economic_calendar(days: int = 7):
    """
    Get economic calendar events for the next N days.
    Uses Finnhub API for real economic events.
    """
    # Check cache first
    cache_key = f"economic_calendar:{days}"
    cached = cache_get(cache_key)
    if cached:
        print("📦 Cache hit for economic calendar")
        return EconomicCalendarResponse(**cached)
    
    from_date = datetime.now()
    to_date = from_date + timedelta(days=days)
    
    events = await fetch_economic_events(from_date, to_date)
    
    if not events:
        events = generate_mock_economic_events(days)
    
    result = EconomicCalendarResponse(
        events=events,
        fromDate=from_date.strftime("%Y-%m-%d"),
        toDate=to_date.strftime("%Y-%m-%d")
    )
    
    cache_set(cache_key, result.model_dump(), "economic_calendar")
    return result


async def fetch_economic_events(from_date: datetime, to_date: datetime) -> List[EconomicEvent]:
    """Fetch economic events from Finnhub API"""
    if not FINNHUB_API_KEY:
        print("⚠️ FINNHUB_API_KEY not set, using mock events")
        return []
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            url = "https://finnhub.io/api/v1/calendar/economic"
            params = {
                "from": from_date.strftime("%Y-%m-%d"),
                "to": to_date.strftime("%Y-%m-%d"),
                "token": FINNHUB_API_KEY
            }
            
            response = await client.get(url, params=params)
            
            if response.status_code != 200:
                print(f"⚠️ Finnhub API error: {response.status_code}")
                return []
            
            data = response.json()
            raw_events = data.get("economicCalendar", [])
            
            events = []
            for event in raw_events[:50]:  # Limit to 50 events
                # Map impact level
                impact_map = {1: "LOW", 2: "MEDIUM", 3: "HIGH"}
                impact = impact_map.get(event.get("impact", 1), "MEDIUM")
                
                events.append(EconomicEvent(
                    date=event.get("date", "")[:10],
                    time=event.get("time", "00:00"),
                    country=event.get("country", "US"),
                    event=event.get("event", "Unknown Event"),
                    impact=impact,
                    forecast=str(event.get("estimate", "")) if event.get("estimate") else None,
                    previous=str(event.get("prev", "")) if event.get("prev") else None,
                    actual=str(event.get("actual", "")) if event.get("actual") else None
                ))
            
            print(f"✅ Fetched {len(events)} economic events")
            return events
            
    except Exception as e:
        print(f"❌ Error fetching economic events: {e}")
        return []


def generate_mock_economic_events(days: int) -> List[EconomicEvent]:
    """Generate mock economic events when API is unavailable"""
    events = []
    event_templates = [
        {"event": "Federal Reserve Interest Rate Decision", "country": "US", "impact": "HIGH"},
        {"event": "Non-Farm Payrolls", "country": "US", "impact": "HIGH"},
        {"event": "Consumer Price Index (CPI)", "country": "US", "impact": "HIGH"},
        {"event": "GDP Growth Rate", "country": "US", "impact": "HIGH"},
        {"event": "Unemployment Rate", "country": "US", "impact": "MEDIUM"},
        {"event": "Retail Sales", "country": "US", "impact": "MEDIUM"},
        {"event": "ECB Interest Rate Decision", "country": "EU", "impact": "HIGH"},
        {"event": "UK GDP", "country": "UK", "impact": "HIGH"},
        {"event": "China Manufacturing PMI", "country": "CN", "impact": "MEDIUM"},
        {"event": "Turkey Inflation Rate", "country": "TR", "impact": "MEDIUM"},
    ]
    
    for i in range(min(days * 2, 15)):
        event_date = datetime.now() + timedelta(days=random.randint(0, days))
        template = random.choice(event_templates)
        
        events.append(EconomicEvent(
            date=event_date.strftime("%Y-%m-%d"),
            time=f"{random.randint(8, 16):02d}:{random.choice(['00', '30'])}",
            country=template["country"],
            event=f"{template['event']} (Demo)",
            impact=template["impact"],
            forecast=f"{random.uniform(-2, 5):.1f}%" if random.random() > 0.3 else None,
            previous=f"{random.uniform(-2, 5):.1f}%",
            actual=None
        ))
    
    events.sort(key=lambda x: (x.date, x.time))
    return events


# ===== AI Stock Analysis Models =====
class AIAnalysisResponse(BaseModel):
    symbol: str
    stockName: str
    analysis: str
    recommendation: str  # BUY, HOLD, SELL
    confidence: float  # 0-100
    keyPoints: List[str]
    generatedAt: str


@app.get("/ai/analyze/{symbol}", response_model=AIAnalysisResponse)
async def get_ai_analysis(symbol: str):
    """
    Get AI-powered stock analysis using Groq LLM.
    Enhanced with RAG: retrieves relevant news, research, and education context.
    """
    symbol_upper = symbol.upper()
    
    # Check cache first
    cache_key = f"ai_analysis:{symbol_upper}"
    cached = cache_get(cache_key)
    if cached:
        print(f"📦 Cache hit for AI analysis {symbol}")
        return AIAnalysisResponse(**cached)
    
    stock_name = STOCK_NAMES.get(symbol_upper, symbol_upper)
    
    # Get stock data for context
    stock_data = get_stock_data(symbol_upper)

    # Try to ingest fresh research data for RAG (non-blocking best-effort)
    if rag_ingestion:
        try:
            risk = calculate_risk_metrics(symbol_upper)
            risk_dict = risk.model_dump() if risk else None
            rag_ingestion.ingest_market_research(
                symbol=symbol_upper,
                risk_data=risk_dict,
            )
        except Exception as e:
            logger.warning(f"RAG research ingestion skipped: {e}")
    
    # Try to get AI analysis
    analysis = await generate_ai_analysis(symbol_upper, stock_name, stock_data)
    
    cache_set(cache_key, analysis.model_dump(), "ai_analysis")
    return analysis


async def generate_ai_analysis(symbol: str, stock_name: str, stock_data: Optional[StockQuote]) -> AIAnalysisResponse:
    """Generate AI analysis using Groq API, enriched with RAG context."""
    
    # Build context from available data
    price_info = ""
    if stock_data:
        price_info = f"Current Price: ${stock_data.price}, Change: {stock_data.changePercent}%"

    # RAG: Retrieve relevant context from vector store
    rag_context = ""
    if rag_retriever and rag_retriever.is_available:
        try:
            rag_context = rag_retriever.build_context_string(
                query=f"{stock_name} ({symbol}) stock analysis investment outlook",
                symbol=symbol,
                top_k=5,
                max_context_chars=2000,
            )
            if rag_context:
                logger.info(f"RAG: injected {len(rag_context)} chars of context for {symbol}")
        except Exception as e:
            logger.warning(f"RAG retrieval failed for {symbol}: {e}")
            rag_context = ""
    
    if GROQ_API_KEY:
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                # Build enhanced prompt with RAG context
                rag_section = ""
                if rag_context:
                    rag_section = f"""
### Relevant Context (from recent news, research, and financial knowledge):
{rag_context}

Use the above context to inform your analysis where relevant."""

                prompt = f"""Analyze {stock_name} ({symbol}) stock and provide a brief investment analysis.
{price_info}
{rag_section}

Provide:
1. A 2-3 sentence analysis of the stock
2. A recommendation (BUY, HOLD, or SELL)
3. Confidence level (0-100)
4. 3 key bullet points

Format your response as JSON with fields: analysis, recommendation, confidence, keyPoints (array of strings)"""

                response = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {GROQ_API_KEY}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": "llama-3.3-70b-versatile",
                        "messages": [
                            {"role": "system", "content": "You are a financial analyst. Provide brief, factual stock analysis. Always respond in valid JSON format. Use any provided context to enhance your analysis."},
                            {"role": "user", "content": prompt}
                        ],
                        "temperature": 0.3,
                        "max_tokens": 500
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    content = result["choices"][0]["message"]["content"]
                    
                    # Parse JSON from response
                    try:
                        # Try to extract JSON from the response
                        import re
                        json_match = re.search(r'\{[\s\S]*\}', content)
                        if json_match:
                            parsed = json.loads(json_match.group())
                            
                            return AIAnalysisResponse(
                                symbol=symbol,
                                stockName=stock_name,
                                analysis=parsed.get("analysis", "Analysis not available"),
                                recommendation=parsed.get("recommendation", "HOLD"),
                                confidence=float(parsed.get("confidence", 50)),
                                keyPoints=parsed.get("keyPoints", ["Data analysis in progress"]),
                                generatedAt=datetime.now().isoformat()
                            )
                    except json.JSONDecodeError:
                        print(f"⚠️ Could not parse AI response as JSON")
                
                print(f"⚠️ Groq API error: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Error calling Groq API: {e}")
    
    # Fallback to rule-based analysis
    return generate_mock_ai_analysis(symbol, stock_name, stock_data)


def generate_mock_ai_analysis(symbol: str, stock_name: str, stock_data: Optional[StockQuote]) -> AIAnalysisResponse:
    """Generate mock AI analysis when API is unavailable"""
    
    # Simple rule-based analysis
    if stock_data:
        if stock_data.changePercent > 2:
            recommendation = "HOLD"  # Already up, might be overbought
            analysis = f"{stock_name} has shown strong momentum with a {stock_data.changePercent}% gain. Consider taking profits or holding for continued growth."
            key_points = [
                f"Stock is up {stock_data.changePercent}% recently",
                "Strong momentum may continue",
                "Consider setting stop-loss to protect gains"
            ]
        elif stock_data.changePercent < -2:
            recommendation = "BUY"  # Potential dip buying opportunity
            analysis = f"{stock_name} is down {abs(stock_data.changePercent)}%, which may present a buying opportunity if fundamentals remain strong."
            key_points = [
                f"Stock has declined {abs(stock_data.changePercent)}%",
                "Potential value opportunity",
                "Review fundamentals before buying"
            ]
        else:
            recommendation = "HOLD"
            analysis = f"{stock_name} is trading relatively flat. Monitor for breakout signals or accumulate on dips."
            key_points = [
                "Stock showing neutral momentum",
                "Wait for clearer directional signals",
                "Good for long-term accumulation"
            ]
    else:
        recommendation = "HOLD"
        analysis = f"Limited data available for {stock_name}. Conduct additional research before making investment decisions."
        key_points = [
            "Insufficient data for strong recommendation",
            "Consider fundamental analysis",
            "Monitor market conditions"
        ]
    
    return AIAnalysisResponse(
        symbol=symbol,
        stockName=f"{stock_name} (Demo)",
        analysis=analysis,
        recommendation=recommendation,
        confidence=round(random.uniform(55, 75), 1),
        keyPoints=key_points,
        generatedAt=datetime.now().isoformat()
    )


# ===== RAG Chat Models & Endpoints =====

class ChatRequest(BaseModel):
    message: str
    symbol: Optional[str] = None
    session_id: str
    user_context: Optional[Dict[str, Any]] = None  # portfolio, watchlist

class ChatSource(BaseModel):
    title: str
    source_type: str
    symbol: Optional[str] = None
    score: float = 0.0

class ChatResponse(BaseModel):
    response: str
    sources: List[ChatSource]
    session_id: str

class RAGStatusResponse(BaseModel):
    enabled: bool
    embedding_available: bool
    vector_store_available: bool
    document_counts: Dict[str, int]

class IngestRequest(BaseModel):
    source_type: str  # NEWS, EDUCATION, RESEARCH
    symbols: Optional[List[str]] = None

class IngestResponse(BaseModel):
    ingested_count: int
    source_type: str


@app.post("/ai/chat", response_model=ChatResponse)
async def ai_chat(request: ChatRequest):
    """
    Conversational AI chat with RAG context.
    Retrieves relevant documents and portfolio context to answer financial questions.
    """
    if not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="AI service not configured")

    # Get RAG context
    rag_context = ""
    sources = []
    if rag_retriever and rag_retriever.is_available:
        try:
            rag_context, raw_sources = rag_retriever.build_context_with_sources(
                query=request.message,
                symbol=request.symbol.upper() if request.symbol else None,
                top_k=5,
                max_context_chars=2500,
            )
            sources = [
                ChatSource(
                    title=s["title"],
                    source_type=s["source_type"],
                    symbol=s.get("symbol"),
                    score=s.get("score", 0),
                )
                for s in raw_sources
            ]
        except Exception as e:
            logger.warning(f"RAG retrieval failed for chat: {e}")

    # Get user portfolio context
    user_context_str = ""
    if rag_retriever and request.user_context:
        try:
            user_context_str = rag_retriever.format_user_context(request.user_context)
        except Exception as e:
            logger.warning(f"Failed to format user context: {e}")

    # Get chat history
    history_messages = []
    if rag_vector_store and rag_vector_store.is_available:
        try:
            history = rag_vector_store.get_chat_history(request.session_id, limit=10)
            for msg in history:
                history_messages.append({
                    "role": msg["role"],
                    "content": msg["content"],
                })
        except Exception as e:
            logger.warning(f"Failed to load chat history: {e}")

    # Build system prompt
    system_parts = [
        "You are SentixAI, a knowledgeable financial assistant for the SentixInvest platform.",
        "Provide helpful, accurate, and concise answers about stocks, investing, portfolio management, and financial concepts.",
        "Always include a disclaimer that your responses are for informational purposes only and not financial advice.",
    ]
    if rag_context:
        system_parts.append(f"\n### Relevant Knowledge Base Context:\n{rag_context}")
    if user_context_str:
        system_parts.append(f"\n### User's Investment Context:\n{user_context_str}")

    system_prompt = "\n".join(system_parts)

    # Build messages for Groq
    symbol_context = f" about {request.symbol.upper()}" if request.symbol else ""
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history_messages[-8:])  # Last 8 messages for context window
    messages.append({"role": "user", "content": request.message})

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "llama-3.3-70b-versatile",
                    "messages": messages,
                    "temperature": 0.4,
                    "max_tokens": 800,
                },
            )

            if response.status_code == 200:
                result = response.json()
                ai_response = result["choices"][0]["message"]["content"]

                # Store chat messages in history
                if rag_vector_store and rag_vector_store.is_available:
                    try:
                        user_id = request.user_context.get("userId", "anonymous") if request.user_context else "anonymous"
                        rag_vector_store.store_chat_message(
                            user_id=user_id,
                            session_id=request.session_id,
                            role="user",
                            content=request.message,
                        )
                        rag_vector_store.store_chat_message(
                            user_id=user_id,
                            session_id=request.session_id,
                            role="assistant",
                            content=ai_response,
                            sources=[s.model_dump() for s in sources],
                        )
                    except Exception as e:
                        logger.warning(f"Failed to store chat history: {e}")

                return ChatResponse(
                    response=ai_response,
                    sources=sources,
                    session_id=request.session_id,
                )

            raise HTTPException(status_code=response.status_code, detail="AI service error")

    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="AI service timeout")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail="Internal AI service error")


@app.get("/ai/rag/status", response_model=RAGStatusResponse)
async def get_rag_status():
    """Get the current status of the RAG system."""
    doc_counts = {}
    if rag_vector_store and rag_vector_store.is_available:
        for source_type in ["NEWS", "EDUCATION", "RESEARCH"]:
            doc_counts[source_type] = rag_vector_store.get_document_count(source_type=source_type)
        doc_counts["TOTAL"] = sum(doc_counts.values())

    return RAGStatusResponse(
        enabled=RAG_ENABLED,
        embedding_available=rag_embedding_service.is_available if rag_embedding_service else False,
        vector_store_available=rag_vector_store.is_available if rag_vector_store else False,
        document_counts=doc_counts,
    )


@app.post("/ai/rag/ingest", response_model=IngestResponse)
async def trigger_ingestion(request: IngestRequest):
    """Manually trigger document ingestion into the RAG vector store."""
    if not rag_ingestion:
        raise HTTPException(status_code=503, detail="RAG system not available")

    count = 0
    source_type = request.source_type.upper()

    if source_type == "EDUCATION":
        count = rag_ingestion.ingest_financial_education()
    elif source_type == "RESEARCH" and request.symbols:
        for symbol in request.symbols:
            try:
                risk = calculate_risk_metrics(symbol.upper())
                risk_dict = risk.model_dump() if risk else None
                count += rag_ingestion.ingest_market_research(
                    symbol=symbol.upper(),
                    risk_data=risk_dict,
                )
            except Exception as e:
                logger.warning(f"Research ingestion failed for {symbol}: {e}")
    elif source_type == "CLEANUP":
        count = rag_ingestion.cleanup_expired()
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported source_type: {source_type}")

    return IngestResponse(ingested_count=count, source_type=source_type)


# ===== Cryptocurrency Models =====
class CryptoQuote(BaseModel):
    id: str
    symbol: str
    name: str
    price: float
    change24h: float
    changePercent24h: float
    marketCap: float
    volume24h: float
    rank: int
    image: Optional[str] = None


class CryptoMarketsResponse(BaseModel):
    cryptocurrencies: List[CryptoQuote]
    timestamp: str


@app.get("/crypto/quote/{symbol}")
async def get_crypto_quote(symbol: str):
    """Get cryptocurrency quote by symbol (e.g., bitcoin, ethereum)"""
    symbol_lower = symbol.lower()
    
    # Check cache first
    cache_key = f"crypto_quote:{symbol_lower}"
    cached = cache_get(cache_key)
    if cached:
        print(f"📦 Cache hit for crypto {symbol}")
        return cached
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{COINGECKO_API_URL}/coins/{symbol_lower}",
                params={
                    "localization": "false",
                    "tickers": "false",
                    "community_data": "false",
                    "developer_data": "false"
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                market_data = data.get("market_data", {})
                
                result = CryptoQuote(
                    id=data.get("id", symbol_lower),
                    symbol=data.get("symbol", symbol).upper(),
                    name=data.get("name", symbol),
                    price=market_data.get("current_price", {}).get("usd", 0),
                    change24h=market_data.get("price_change_24h", 0),
                    changePercent24h=market_data.get("price_change_percentage_24h", 0),
                    marketCap=market_data.get("market_cap", {}).get("usd", 0),
                    volume24h=market_data.get("total_volume", {}).get("usd", 0),
                    rank=data.get("market_cap_rank", 0),
                    image=data.get("image", {}).get("small")
                )
                
                cache_set(cache_key, result.model_dump(), "crypto")
                print(f"✅ Fetched crypto quote for {symbol}")
                return result
            
            raise HTTPException(status_code=404, detail=f"Cryptocurrency {symbol} not found")
            
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Request timeout")
    except Exception as e:
        print(f"❌ Error fetching crypto: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/crypto/markets", response_model=CryptoMarketsResponse)
async def get_crypto_markets(limit: int = 20):
    """Get top cryptocurrencies by market cap"""
    # Check cache first
    cache_key = f"crypto_markets:{limit}"
    cached = cache_get(cache_key)
    if cached:
        print("📦 Cache hit for crypto markets")
        return CryptoMarketsResponse(**cached)
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{COINGECKO_API_URL}/coins/markets",
                params={
                    "vs_currency": "usd",
                    "order": "market_cap_desc",
                    "per_page": min(limit, 100),
                    "page": 1,
                    "sparkline": "false"
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                cryptos = []
                
                for coin in data:
                    cryptos.append(CryptoQuote(
                        id=coin.get("id", ""),
                        symbol=coin.get("symbol", "").upper(),
                        name=coin.get("name", ""),
                        price=coin.get("current_price", 0) or 0,
                        change24h=coin.get("price_change_24h", 0) or 0,
                        changePercent24h=coin.get("price_change_percentage_24h", 0) or 0,
                        marketCap=coin.get("market_cap", 0) or 0,
                        volume24h=coin.get("total_volume", 0) or 0,
                        rank=coin.get("market_cap_rank", 0) or 0,
                        image=coin.get("image")
                    ))
                
                result = CryptoMarketsResponse(
                    cryptocurrencies=cryptos,
                    timestamp=datetime.now().isoformat()
                )
                
                cache_set(cache_key, result.model_dump(), "crypto")
                print(f"✅ Fetched {len(cryptos)} cryptocurrencies")
                return result
            
            raise HTTPException(status_code=response.status_code, detail="Failed to fetch crypto markets")
            
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Request timeout")
    except Exception as e:
        print(f"❌ Error fetching crypto markets: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ===== Forex Currency Models =====
class ForexRate(BaseModel):
    currency: str
    rate: float
    name: str


class ForexRatesResponse(BaseModel):
    baseCurrency: str
    rates: List[ForexRate]
    timestamp: str


class ForexConvertResponse(BaseModel):
    fromCurrency: str
    toCurrency: str
    amount: float
    result: float
    rate: float
    timestamp: str


CURRENCY_NAMES = {
    "USD": "US Dollar",
    "EUR": "Euro",
    "GBP": "British Pound",
    "TRY": "Turkish Lira",
    "JPY": "Japanese Yen",
    "CHF": "Swiss Franc",
    "CAD": "Canadian Dollar",
    "AUD": "Australian Dollar",
    "CNY": "Chinese Yuan",
    "INR": "Indian Rupee",
    "BRL": "Brazilian Real",
    "RUB": "Russian Ruble",
    "KRW": "South Korean Won",
    "MXN": "Mexican Peso",
    "SGD": "Singapore Dollar"
}


@app.get("/forex/rates", response_model=ForexRatesResponse)
async def get_forex_rates(base: str = "USD"):
    """Get forex rates for major currencies"""
    base_upper = base.upper()
    
    # Check cache first
    cache_key = f"forex_rates:{base_upper}"
    cached = cache_get(cache_key)
    if cached:
        print(f"📦 Cache hit for forex rates {base}")
        return ForexRatesResponse(**cached)
    
    rates = await fetch_forex_rates(base_upper)
    
    result = ForexRatesResponse(
        baseCurrency=base_upper,
        rates=rates,
        timestamp=datetime.now().isoformat()
    )
    
    cache_set(cache_key, result.model_dump(), "forex")
    return result


async def fetch_forex_rates(base: str) -> List[ForexRate]:
    """Fetch forex rates from ExchangeRate API or fallback"""
    
    # Try ExchangeRate-API (free tier)
    if EXCHANGERATE_API_KEY:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(
                    f"https://v6.exchangerate-api.com/v6/{EXCHANGERATE_API_KEY}/latest/{base}"
                )
                
                if response.status_code == 200:
                    data = response.json()
                    if data.get("result") == "success":
                        raw_rates = data.get("conversion_rates", {})
                        rates = []
                        
                        for currency in CURRENCY_NAMES.keys():
                            if currency in raw_rates and currency != base:
                                rates.append(ForexRate(
                                    currency=currency,
                                    rate=raw_rates[currency],
                                    name=CURRENCY_NAMES[currency]
                                ))
                        
                        print(f"✅ Fetched {len(rates)} forex rates for {base}")
                        return rates
        except Exception as e:
            print(f"⚠️ Error fetching forex rates: {e}")
    
    # Fallback to free open API
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            # Use open.er-api.com (no key required)
            response = await client.get(f"https://open.er-api.com/v6/latest/{base}")
            
            if response.status_code == 200:
                data = response.json()
                raw_rates = data.get("rates", {})
                rates = []
                
                for currency in CURRENCY_NAMES.keys():
                    if currency in raw_rates and currency != base:
                        rates.append(ForexRate(
                            currency=currency,
                            rate=round(raw_rates[currency], 4),
                            name=CURRENCY_NAMES[currency]
                        ))
                
                print(f"✅ Fetched {len(rates)} forex rates from open API")
                return rates
                
    except Exception as e:
        print(f"❌ Error fetching forex rates: {e}")
    
    # Mock fallback
    return generate_mock_forex_rates(base)


def generate_mock_forex_rates(base: str) -> List[ForexRate]:
    """Generate mock forex rates"""
    mock_rates_usd = {
        "EUR": 0.92,
        "GBP": 0.79,
        "TRY": 34.25,
        "JPY": 149.50,
        "CHF": 0.88,
        "CAD": 1.36,
        "AUD": 1.53,
        "CNY": 7.24,
        "INR": 83.12,
        "BRL": 4.97,
        "RUB": 89.50,
        "KRW": 1328.45,
        "MXN": 17.15,
        "SGD": 1.34
    }
    
    rates = []
    for currency, rate in mock_rates_usd.items():
        if currency != base:
            # Adjust rate if base is not USD
            adjusted_rate = rate
            if base != "USD" and base in mock_rates_usd:
                adjusted_rate = rate / mock_rates_usd[base]
            
            rates.append(ForexRate(
                currency=currency,
                rate=round(adjusted_rate * (1 + random.uniform(-0.01, 0.01)), 4),
                name=f"{CURRENCY_NAMES.get(currency, currency)} (Demo)"
            ))
    
    return rates


@app.get("/forex/convert", response_model=ForexConvertResponse)
async def convert_currency(from_currency: str, to_currency: str, amount: float):
    """Convert currency amount"""
    from_upper = from_currency.upper()
    to_upper = to_currency.upper()
    
    # Get rates for the from currency
    rates_response = await get_forex_rates(from_upper)
    
    # Find the target rate
    rate = None
    for forex_rate in rates_response.rates:
        if forex_rate.currency == to_upper:
            rate = forex_rate.rate
            break
    
    if rate is None:
        if from_upper == to_upper:
            rate = 1.0
        else:
            raise HTTPException(status_code=400, detail=f"Cannot convert {from_upper} to {to_upper}")
    
    result = round(amount * rate, 2)
    
    return ForexConvertResponse(
        fromCurrency=from_upper,
        toCurrency=to_upper,
        amount=amount,
        result=result,
        rate=rate,
        timestamp=datetime.now().isoformat()
    )


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)




