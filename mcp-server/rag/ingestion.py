"""
Ingestion pipelines for populating the RAG vector store with financial knowledge.

Supports ingesting:
- Stock news articles (from GNews API)
- Financial education content (static seed data)
- Market research & analysis (from existing MCP endpoints)
"""

import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

from .embeddings import EmbeddingService
from .vector_store import VectorStore

logger = logging.getLogger(__name__)


# ── Static Financial Education Content ─────────────────────────────

FINANCIAL_EDUCATION_DOCS = [
    {
        "title": "What is Dollar-Cost Averaging (DCA)?",
        "content": (
            "Dollar-cost averaging is an investment strategy where you invest a fixed amount of money "
            "at regular intervals, regardless of the asset's price. This reduces the impact of volatility "
            "by buying more shares when prices are low and fewer when prices are high. DCA is popular "
            "among long-term investors as it removes emotional decision-making and is especially useful "
            "in volatile markets. However, in a consistently rising market, lump-sum investing may "
            "outperform DCA."
        ),
    },
    {
        "title": "Understanding Price-to-Earnings (P/E) Ratio",
        "content": (
            "The P/E ratio measures a company's stock price relative to its earnings per share (EPS). "
            "A high P/E may indicate that investors expect future growth, while a low P/E may suggest "
            "the stock is undervalued or that the company faces challenges. The forward P/E uses estimated "
            "future earnings. Comparing P/E ratios within the same sector is more meaningful than "
            "cross-sector comparisons. The S&P 500 historical average P/E is around 15-17."
        ),
    },
    {
        "title": "Market Capitalization Explained",
        "content": (
            "Market cap = stock price × total shares outstanding. Large-cap companies (>$10B) are "
            "typically more stable. Mid-cap ($2B-$10B) offer growth potential with moderate risk. "
            "Small-cap (<$2B) can have high growth but higher volatility. Mega-cap companies (>$200B) "
            "like Apple, Microsoft, and Google dominate major indices. Market cap helps investors "
            "understand relative company size and risk profile."
        ),
    },
    {
        "title": "What is Beta in Stock Analysis?",
        "content": (
            "Beta measures a stock's volatility relative to the overall market (usually S&P 500). "
            "A beta of 1.0 means the stock moves with the market. Beta > 1.0 = more volatile than "
            "the market (e.g., tech stocks often have beta 1.2-1.5). Beta < 1.0 = less volatile "
            "(e.g., utilities, consumer staples). Negative beta means the stock moves inversely to "
            "the market. Beta is useful for portfolio risk management but doesn't capture all risk factors."
        ),
    },
    {
        "title": "Dividend Investing Strategy",
        "content": (
            "Dividend investing focuses on stocks that regularly pay dividends, providing passive income. "
            "Key metrics: dividend yield (annual dividend / price), payout ratio (dividends / earnings), "
            "and dividend growth rate. Dividend aristocrats are S&P 500 companies that have increased "
            "dividends for 25+ consecutive years. A sustainable payout ratio below 60% is generally "
            "healthy. DRIP (Dividend Reinvestment Plan) compounds returns over time."
        ),
    },
    {
        "title": "Understanding Stock Market Sectors",
        "content": (
            "The market is divided into 11 GICS sectors: Technology, Healthcare, Financials, "
            "Consumer Discretionary, Communication Services, Industrials, Consumer Staples, Energy, "
            "Utilities, Real Estate, and Materials. Sector rotation occurs as economic cycles change. "
            "Defensive sectors (utilities, healthcare, staples) outperform in downturns. Cyclical sectors "
            "(tech, consumer discretionary, financials) outperform in expansions. Diversifying across "
            "sectors reduces portfolio risk."
        ),
    },
    {
        "title": "What is the Sharpe Ratio?",
        "content": (
            "The Sharpe Ratio measures risk-adjusted return: (Return - Risk-free rate) / Standard deviation. "
            "A higher Sharpe ratio indicates better risk-adjusted performance. Sharpe > 1.0 is considered "
            "good, > 2.0 is very good, > 3.0 is excellent. It helps compare investments with different "
            "risk levels. Limitations: assumes normal distribution of returns, doesn't distinguish between "
            "upside and downside volatility. The Sortino ratio addresses the latter limitation."
        ),
    },
    {
        "title": "Value at Risk (VaR) Explained",
        "content": (
            "VaR estimates the maximum expected loss over a given time period at a confidence level. "
            "For example, a 95% daily VaR of 2% means there's a 5% chance of losing more than 2% "
            "in a single day. Methods: Historical simulation, variance-covariance, Monte Carlo. "
            "Limitations: doesn't predict magnitude of extreme losses (tail risk), assumes past patterns "
            "continue. Complement with stress testing and Expected Shortfall (CVaR) for better risk assessment."
        ),
    },
    {
        "title": "Technical Analysis: Moving Averages",
        "content": (
            "Moving averages smooth price data to identify trends. Simple Moving Average (SMA) gives equal "
            "weight to all periods. Exponential Moving Average (EMA) gives more weight to recent prices. "
            "Common signals: Golden Cross (50-day MA crosses above 200-day MA = bullish), Death Cross "
            "(50-day crosses below 200-day = bearish). The 200-day MA is widely watched as a long-term "
            "trend indicator. Moving averages work best in trending markets, not sideways markets."
        ),
    },
    {
        "title": "Portfolio Diversification Principles",
        "content": (
            "Diversification reduces unsystematic risk by spreading investments across different assets. "
            "Modern Portfolio Theory (Markowitz) shows that combining uncorrelated assets reduces portfolio "
            "volatility without sacrificing returns. Diversify across: asset classes (stocks, bonds, real estate), "
            "sectors, geographies, company sizes, and investment styles (growth vs value). The correlation "
            "between assets matters more than the number of holdings. Over-diversification can dilute returns."
        ),
    },
    {
        "title": "Understanding Earnings Reports",
        "content": (
            "Quarterly earnings reports include: revenue (top line), net income (bottom line), earnings per "
            "share (EPS), and guidance (forward-looking estimates). An earnings 'beat' means actual results "
            "exceeded analyst estimates. Stocks often move 5-10% after earnings surprises. Key metrics to watch: "
            "revenue growth rate, profit margins, same-store sales, subscriber growth. Forward guidance often "
            "matters more than past results. Earnings whisper numbers (unofficial estimates) can differ from "
            "consensus estimates."
        ),
    },
    {
        "title": "Risk Management in Trading",
        "content": (
            "Key risk management principles: Never risk more than 1-2% of portfolio on a single trade. "
            "Use stop-loss orders to limit downside (typically 5-10% below entry). Position sizing: "
            "calculate trade size based on risk per trade and stop-loss distance. Risk/reward ratio: "
            "aim for at least 1:2 (risk $1 to make $2). Diversify positions across sectors. Keep a trading "
            "journal to track performance and improve decision-making. Avoid revenge trading after losses."
        ),
    },
    {
        "title": "Bull vs Bear Markets",
        "content": (
            "A bull market is characterized by rising prices (20%+ gain from recent low), optimism, and "
            "economic expansion. A bear market is a 20%+ decline from recent high, with pessimism and "
            "economic contraction. Bull markets historically last longer (average 4-5 years) than bear "
            "markets (average 1-1.5 years). Strategies differ: buy-and-hold and growth investing in bulls; "
            "defensive stocks, bonds, and hedging in bears. Market corrections (10-20% decline) are normal "
            "and occur on average every 1-2 years."
        ),
    },
    {
        "title": "What is Fundamental Analysis?",
        "content": (
            "Fundamental analysis evaluates a company's intrinsic value by examining financial statements, "
            "industry conditions, and economic factors. Key financial ratios: P/E, P/B (price-to-book), "
            "debt-to-equity, ROE (return on equity), current ratio, and free cash flow. Qualitative factors: "
            "management quality, competitive advantages (moats), market share, and industry trends. "
            "Discounted Cash Flow (DCF) models estimate fair value based on projected future cash flows. "
            "Compare with peers and historical averages."
        ),
    },
    {
        "title": "Understanding ETFs vs Mutual Funds vs Individual Stocks",
        "content": (
            "ETFs (Exchange-Traded Funds) trade like stocks on exchanges, often tracking an index. "
            "Lower expense ratios than mutual funds, tax-efficient, and highly liquid. Mutual funds are "
            "actively managed (usually), priced once daily, may have minimum investments. Individual stocks "
            "offer highest potential returns but highest risk. For beginners, broad market ETFs like SPY "
            "(S&P 500) or VTI (Total Stock Market) provide instant diversification. Consider your risk "
            "tolerance, time horizon, and investment knowledge when choosing."
        ),
    },
]


class IngestionPipeline:
    """Pipelines for ingesting different types of financial content into the vector store."""

    def __init__(self, embedding_service: EmbeddingService, vector_store: VectorStore):
        self.embedding_service = embedding_service
        self.vector_store = vector_store

    def ingest_financial_education(self) -> int:
        """
        Ingest static financial education documents.
        Only runs if education docs haven't been ingested yet.

        Returns:
            Number of documents ingested.
        """
        existing = self.vector_store.get_document_count(source_type="EDUCATION")
        if existing >= len(FINANCIAL_EDUCATION_DOCS):
            logger.info(f"Education docs already ingested ({existing} docs), skipping")
            return 0

        texts = [f"{doc['title']}\n{doc['content']}" for doc in FINANCIAL_EDUCATION_DOCS]
        embeddings = self.embedding_service.embed_batch(texts)

        documents = []
        for doc in FINANCIAL_EDUCATION_DOCS:
            documents.append({
                "source_type": "EDUCATION",
                "symbol": None,
                "title": doc["title"],
                "content": doc["content"],
                "metadata": {"category": "financial_education"},
                "expires_at": None,  # Never expires
            })

        count = self.vector_store.store_documents(documents, embeddings)
        self.vector_store.log_ingestion("EDUCATION", None, count)
        logger.info(f"✅ Ingested {count} financial education documents")
        return count

    def ingest_news_articles(self, news_items: List[Dict[str, Any]], symbol: str) -> int:
        """
        Ingest news articles for a specific stock into the vector store.

        Args:
            news_items: List of news article dicts with title, summary, source, sentiment, etc.
            symbol: Stock symbol the news is about.

        Returns:
            Number of documents ingested.
        """
        if not news_items:
            return 0

        texts = []
        documents = []
        for article in news_items:
            title = article.get("title", "")
            summary = article.get("summary", article.get("description", ""))
            content = f"{title}. {summary}"
            texts.append(content)

            documents.append({
                "source_type": "NEWS",
                "symbol": symbol.upper(),
                "title": title,
                "content": summary,
                "metadata": {
                    "source": article.get("source", "Unknown"),
                    "sentiment": article.get("sentiment", "NEUTRAL"),
                    "sentimentScore": article.get("sentimentScore", 0),
                    "publishedAt": article.get("publishedAt", ""),
                    "url": article.get("url", ""),
                },
                "expires_at": (datetime.now() + timedelta(days=30)).isoformat(),
            })

        embeddings = self.embedding_service.embed_batch(texts)
        count = self.vector_store.store_documents(documents, embeddings)
        self.vector_store.log_ingestion("NEWS", symbol.upper(), count)
        logger.info(f"✅ Ingested {count} news articles for {symbol}")
        return count

    def ingest_market_research(
        self,
        symbol: str,
        risk_data: Optional[Dict] = None,
        dividend_data: Optional[Dict] = None,
        earnings_data: Optional[Dict] = None,
    ) -> int:
        """
        Ingest market research data (risk metrics, dividends, earnings) for a stock.

        Args:
            symbol: Stock symbol.
            risk_data: Risk analysis data dict.
            dividend_data: Dividend data dict.
            earnings_data: Earnings data dict.

        Returns:
            Number of documents ingested.
        """
        documents = []
        texts = []

        if risk_data:
            content = (
                f"Risk Analysis for {symbol}: "
                f"Beta: {risk_data.get('beta', 'N/A')}, "
                f"Volatility: {risk_data.get('volatility', 'N/A')}%, "
                f"Sharpe Ratio: {risk_data.get('sharpeRatio', 'N/A')}, "
                f"Max Drawdown: {risk_data.get('maxDrawdown', 'N/A')}%, "
                f"Value at Risk (95%): {risk_data.get('valueAtRisk', 'N/A')}%, "
                f"Risk Level: {risk_data.get('riskLevel', 'N/A')}"
            )
            documents.append({
                "source_type": "RESEARCH",
                "symbol": symbol.upper(),
                "title": f"Risk Analysis: {symbol}",
                "content": content,
                "metadata": {"data_type": "risk_analysis", **risk_data},
                "expires_at": (datetime.now() + timedelta(days=7)).isoformat(),
            })
            texts.append(content)

        if dividend_data and dividend_data.get("hasDividends"):
            content = (
                f"Dividend Data for {symbol}: "
                f"Annual Yield: {dividend_data.get('annualYield', 0)}%, "
                f"Annual Dividend: ${dividend_data.get('annualDividend', 0)}, "
                f"Payout Frequency: {dividend_data.get('payoutFrequency', 'N/A')}. "
            )
            if dividend_data.get("nextDividend"):
                nd = dividend_data["nextDividend"]
                content += f"Next ex-date: {nd.get('exDate', 'N/A')}, Amount: ${nd.get('amount', 0)}"
            documents.append({
                "source_type": "RESEARCH",
                "symbol": symbol.upper(),
                "title": f"Dividend Data: {symbol}",
                "content": content,
                "metadata": {"data_type": "dividend"},
                "expires_at": (datetime.now() + timedelta(days=7)).isoformat(),
            })
            texts.append(content)

        if earnings_data:
            content = f"Earnings Data for {symbol}: "
            if earnings_data.get("hasUpcoming"):
                content += (
                    f"Next Earnings: {earnings_data.get('nextEarningsDate', 'N/A')} "
                    f"({earnings_data.get('daysUntilEarnings', '?')} days away), "
                    f"Fiscal Quarter: {earnings_data.get('fiscalQuarter', 'N/A')}, "
                    f"EPS Estimate: {earnings_data.get('nextEpsEstimate', 'N/A')}. "
                )
            history = earnings_data.get("history", [])
            if history:
                recent = history[0]
                content += (
                    f"Last Earnings: EPS Actual {recent.get('epsActual', 'N/A')} "
                    f"vs Estimate {recent.get('epsEstimate', 'N/A')}, "
                    f"Surprise: {recent.get('surprise', 'N/A')}%"
                )
            documents.append({
                "source_type": "RESEARCH",
                "symbol": symbol.upper(),
                "title": f"Earnings Data: {symbol}",
                "content": content,
                "metadata": {"data_type": "earnings"},
                "expires_at": (datetime.now() + timedelta(days=7)).isoformat(),
            })
            texts.append(content)

        if not documents:
            return 0

        embeddings = self.embedding_service.embed_batch(texts)
        count = self.vector_store.store_documents(documents, embeddings)
        self.vector_store.log_ingestion("RESEARCH", symbol.upper(), count)
        logger.info(f"✅ Ingested {count} research documents for {symbol}")
        return count

    def cleanup_expired(self) -> int:
        """Remove expired documents from the vector store."""
        return self.vector_store.delete_expired()
