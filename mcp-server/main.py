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

app = FastAPI(title="SentixInvest MCP Server", version="1.0.0")

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
    data = get_stock_data(symbol)
    if not data:
        raise HTTPException(status_code=404, detail=f"Stock {symbol} not found")
    return data

@app.get("/market-summary", response_model=MarketSummary)
def get_market_summary():
    """Get market summary for BIST100, NASDAQ, and S&P500"""
    return MarketSummary(
        bist100=get_index_data("XU100.IS", "BIST 100"),
        nasdaq=get_index_data("^IXIC", "NASDAQ Composite"),
        sp500=get_index_data("^GSPC", "S&P 500"),
        timestamp=datetime.now().isoformat()
    )

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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
