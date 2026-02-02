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
def get_stock_news(symbol: str, count: int = 5):
    """
    Get news articles for a specific stock.
    Returns simulated news data with sentiment analysis.
    In production, this would integrate with a real news API like Finnhub or Alpha Vantage.
    """
    symbol_upper = symbol.upper()
    stock_name = STOCK_NAMES.get(symbol_upper, symbol)
    
    # Limit count to reasonable range
    count = max(1, min(count, 10))
    
    news = generate_news_for_stock(symbol_upper, count)
    
    return StockNewsResponse(
        symbol=symbol_upper,
        stockName=stock_name,
        news=news
    )


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


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)



