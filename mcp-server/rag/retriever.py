"""
RAG Retriever — orchestrates embedding + vector search to build context for LLM prompts.
"""

import logging
from typing import List, Optional, Dict, Any

from .embeddings import EmbeddingService
from .vector_store import VectorStore, Document

logger = logging.getLogger(__name__)


class RAGRetriever:
    """Orchestrates embedding queries and retrieving relevant context from the vector store."""

    def __init__(self, embedding_service: EmbeddingService, vector_store: VectorStore):
        self.embedding_service = embedding_service
        self.vector_store = vector_store

    @property
    def is_available(self) -> bool:
        return self.embedding_service.is_available and self.vector_store.is_available

    def retrieve(
        self,
        query: str,
        symbol: Optional[str] = None,
        source_types: Optional[List[str]] = None,
        top_k: int = 5,
        score_threshold: float = 0.3,
    ) -> List[Document]:
        """
        Retrieve relevant documents for a query.

        Args:
            query: Natural language query.
            symbol: Optional stock symbol to filter results.
            source_types: Optional filter on document types (NEWS, REPORT, EDUCATION, RESEARCH).
            top_k: Max number of results.
            score_threshold: Minimum similarity score (0-1).

        Returns:
            List of relevant Document objects.
        """
        if not self.is_available:
            logger.warning("RAG not available, returning empty context")
            return []

        try:
            query_embedding = self.embedding_service.embed_text(query)
            documents = self.vector_store.search_similar(
                query_embedding=query_embedding,
                symbol=symbol,
                source_types=source_types,
                top_k=top_k,
                score_threshold=score_threshold,
            )
            logger.info(f"Retrieved {len(documents)} documents for query: '{query[:80]}...' (symbol={symbol})")
            return documents
        except Exception as e:
            logger.error(f"Error during RAG retrieval: {e}")
            return []

    def build_context_string(
        self,
        query: str,
        symbol: Optional[str] = None,
        source_types: Optional[List[str]] = None,
        top_k: int = 5,
        max_context_chars: int = 3000,
    ) -> str:
        """
        Build a formatted context string from retrieved documents for injection into LLM prompts.

        Args:
            query: The query to retrieve documents for.
            symbol: Optional stock symbol filter.
            source_types: Optional source type filter.
            top_k: Maximum documents to retrieve.
            max_context_chars: Maximum total characters for context.

        Returns:
            Formatted string with retrieved context, or empty string if nothing found.
        """
        documents = self.retrieve(
            query=query,
            symbol=symbol,
            source_types=source_types,
            top_k=top_k,
        )

        if not documents:
            return ""

        context_parts = []
        total_chars = 0

        for doc in documents:
            source_label = doc.source_type.replace("_", " ").title()
            entry = f"[{source_label}] {doc.title}\n{doc.content}"

            if total_chars + len(entry) > max_context_chars:
                # Truncate the last entry to fit
                remaining = max_context_chars - total_chars
                if remaining > 100:
                    context_parts.append(entry[:remaining] + "...")
                break

            context_parts.append(entry)
            total_chars += len(entry)

        return "\n\n".join(context_parts)

    def build_context_with_sources(
        self,
        query: str,
        symbol: Optional[str] = None,
        source_types: Optional[List[str]] = None,
        top_k: int = 5,
        max_context_chars: int = 3000,
    ) -> tuple:
        """
        Build context string and return source metadata for citation.

        Returns:
            Tuple of (context_string, sources_list)
            where sources_list is a list of dicts with title, source_type, symbol, score.
        """
        documents = self.retrieve(
            query=query,
            symbol=symbol,
            source_types=source_types,
            top_k=top_k,
        )

        if not documents:
            return "", []

        context_parts = []
        sources = []
        total_chars = 0

        for doc in documents:
            source_label = doc.source_type.replace("_", " ").title()
            entry = f"[{source_label}] {doc.title}\n{doc.content}"

            if total_chars + len(entry) > max_context_chars:
                remaining = max_context_chars - total_chars
                if remaining > 100:
                    context_parts.append(entry[:remaining] + "...")
                    sources.append({
                        "title": doc.title,
                        "source_type": doc.source_type,
                        "symbol": doc.symbol,
                        "score": doc.score,
                    })
                break

            context_parts.append(entry)
            sources.append({
                "title": doc.title,
                "source_type": doc.source_type,
                "symbol": doc.symbol,
                "score": doc.score,
            })
            total_chars += len(entry)

        return "\n\n".join(context_parts), sources

    def format_user_context(self, user_context: Optional[Dict[str, Any]]) -> str:
        """
        Format user portfolio/watchlist context for inclusion in LLM prompts.

        Args:
            user_context: Dict with optional 'portfolio' and 'watchlist' fields.

        Returns:
            Formatted string describing the user's investment context.
        """
        if not user_context:
            return ""

        parts = []

        portfolio = user_context.get("portfolio", [])
        if portfolio:
            holdings = []
            for h in portfolio[:10]:  # Limit to 10 holdings
                symbol = h.get("symbol", "?")
                qty = h.get("quantity", 0)
                avg = h.get("averagePurchasePrice", 0)
                holdings.append(f"  - {symbol}: {qty} shares @ ${avg:.2f} avg")
            parts.append("User's Portfolio:\n" + "\n".join(holdings))

        watchlist = user_context.get("watchlist", [])
        if watchlist:
            symbols = [w.get("symbol", "?") for w in watchlist[:10]]
            parts.append(f"User's Watchlist: {', '.join(symbols)}")

        return "\n\n".join(parts)
