"""
Vector store backed by pgvector (PostgreSQL extension).
Handles CRUD operations on the rag_documents table with vector similarity search.
"""

import os
import json
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from dataclasses import dataclass

import psycopg2
from psycopg2.extras import execute_values, RealDictCursor
from psycopg2 import pool

logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://sentix:sentix_password@localhost:5432/sentixdb")


@dataclass
class Document:
    """Represents a retrieved document from the vector store."""
    id: int
    source_type: str
    symbol: Optional[str]
    title: str
    content: str
    metadata: Dict[str, Any]
    score: float = 0.0
    created_at: Optional[str] = None


class VectorStore:
    """pgvector-backed vector store for RAG documents."""

    def __init__(self):
        self._pool: Optional[pool.SimpleConnectionPool] = None
        self._available = False

    def initialize(self):
        """Initialize the connection pool and verify pgvector is available."""
        try:
            self._pool = pool.SimpleConnectionPool(
                minconn=1,
                maxconn=5,
                dsn=DATABASE_URL,
            )
            # Verify pgvector extension and tables exist
            conn = self._pool.getconn()
            try:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'")
                    if cur.fetchone() is None:
                        cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
                        conn.commit()
                    # Ensure tables exist
                    self._ensure_tables(cur)
                    conn.commit()
                self._available = True
                logger.info("✅ VectorStore initialized (pgvector)")
            finally:
                self._pool.putconn(conn)
        except Exception as e:
            logger.error(f"❌ VectorStore initialization failed: {e}")
            self._available = False

    def _ensure_tables(self, cur):
        """Create tables if they don't exist (idempotent)."""
        cur.execute("""
            CREATE TABLE IF NOT EXISTS rag_documents (
                id BIGSERIAL PRIMARY KEY,
                source_type VARCHAR(50) NOT NULL,
                symbol VARCHAR(20),
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                metadata JSONB DEFAULT '{}',
                embedding vector(384),
                created_at TIMESTAMP DEFAULT NOW(),
                expires_at TIMESTAMP
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS rag_chat_history (
                id BIGSERIAL PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                session_id VARCHAR(255) NOT NULL,
                role VARCHAR(20) NOT NULL,
                content TEXT NOT NULL,
                sources JSONB DEFAULT '[]',
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS rag_ingestion_log (
                id BIGSERIAL PRIMARY KEY,
                source_type VARCHAR(50) NOT NULL,
                symbol VARCHAR(20),
                document_count INTEGER DEFAULT 0,
                last_ingested_at TIMESTAMP DEFAULT NOW()
            )
        """)

    @property
    def is_available(self) -> bool:
        return self._available

    def _get_conn(self):
        if not self._pool:
            raise RuntimeError("VectorStore not initialized")
        return self._pool.getconn()

    def _put_conn(self, conn):
        if self._pool:
            self._pool.putconn(conn)

    # ── Document CRUD ──────────────────────────────────────────────

    def store_documents(
        self,
        documents: List[Dict[str, Any]],
        embeddings: List[List[float]],
    ) -> int:
        """
        Store documents with their embeddings in the vector store.

        Args:
            documents: List of dicts with keys: source_type, symbol, title, content, metadata, expires_at
            embeddings: Corresponding embedding vectors.

        Returns:
            Number of documents stored.
        """
        if not documents or not embeddings:
            return 0

        conn = self._get_conn()
        try:
            with conn.cursor() as cur:
                values = []
                for doc, emb in zip(documents, embeddings):
                    values.append((
                        doc["source_type"],
                        doc.get("symbol"),
                        doc["title"],
                        doc["content"],
                        json.dumps(doc.get("metadata", {})),
                        str(emb),  # pgvector accepts string representation
                        doc.get("expires_at"),
                    ))

                execute_values(
                    cur,
                    """
                    INSERT INTO rag_documents
                        (source_type, symbol, title, content, metadata, embedding, expires_at)
                    VALUES %s
                    """,
                    values,
                    template="(%s, %s, %s, %s, %s, %s::vector, %s)",
                )
                conn.commit()
                logger.info(f"Stored {len(values)} documents in vector store")
                return len(values)
        except Exception as e:
            conn.rollback()
            logger.error(f"Error storing documents: {e}")
            return 0
        finally:
            self._put_conn(conn)

    def search_similar(
        self,
        query_embedding: List[float],
        symbol: Optional[str] = None,
        source_types: Optional[List[str]] = None,
        top_k: int = 5,
        score_threshold: float = 0.3,
    ) -> List[Document]:
        """
        Search for documents similar to the query embedding.

        Args:
            query_embedding: The query vector (384-dim).
            symbol: Optional stock symbol filter.
            source_types: Optional list of source types to filter by.
            top_k: Maximum number of results.
            score_threshold: Minimum cosine similarity (0-1).

        Returns:
            List of Document objects sorted by relevance.
        """
        conn = self._get_conn()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Build WHERE clause
                conditions = ["(expires_at IS NULL OR expires_at > NOW())"]
                params: list = []

                if symbol:
                    conditions.append("(symbol = %s OR symbol IS NULL)")
                    params.append(symbol.upper())

                if source_types:
                    conditions.append("source_type = ANY(%s)")
                    params.append(source_types)

                where_clause = " AND ".join(conditions)

                # Cosine distance: 1 - cosine_similarity
                # pgvector's <=> operator returns cosine distance
                query = f"""
                    SELECT id, source_type, symbol, title, content, metadata,
                           created_at::text as created_at,
                           1 - (embedding <=> %s::vector) as score
                    FROM rag_documents
                    WHERE {where_clause}
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                """
                params_final = [str(query_embedding)] + params + [str(query_embedding), top_k]
                cur.execute(query, params_final)
                rows = cur.fetchall()

                results = []
                for row in rows:
                    score = float(row["score"])
                    if score >= score_threshold:
                        results.append(Document(
                            id=row["id"],
                            source_type=row["source_type"],
                            symbol=row["symbol"],
                            title=row["title"],
                            content=row["content"],
                            metadata=row["metadata"] if isinstance(row["metadata"], dict) else json.loads(row["metadata"]),
                            score=round(score, 4),
                            created_at=row["created_at"],
                        ))

                return results
        except Exception as e:
            logger.error(f"Error in vector search: {e}")
            return []
        finally:
            self._put_conn(conn)

    def delete_expired(self) -> int:
        """Delete documents past their expiration date. Returns count deleted."""
        conn = self._get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM rag_documents WHERE expires_at IS NOT NULL AND expires_at < NOW()"
                )
                count = cur.rowcount
                conn.commit()
                if count > 0:
                    logger.info(f"🗑️ Deleted {count} expired RAG documents")
                return count
        except Exception as e:
            conn.rollback()
            logger.error(f"Error deleting expired docs: {e}")
            return 0
        finally:
            self._put_conn(conn)

    def get_document_count(self, source_type: Optional[str] = None, symbol: Optional[str] = None) -> int:
        """Get the count of documents, optionally filtered."""
        conn = self._get_conn()
        try:
            with conn.cursor() as cur:
                conditions = []
                params: list = []
                if source_type:
                    conditions.append("source_type = %s")
                    params.append(source_type)
                if symbol:
                    conditions.append("symbol = %s")
                    params.append(symbol.upper())

                where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
                cur.execute(f"SELECT COUNT(*) FROM rag_documents {where}", params)
                return cur.fetchone()[0]
        except Exception as e:
            logger.error(f"Error getting document count: {e}")
            return 0
        finally:
            self._put_conn(conn)

    # ── Chat History ───────────────────────────────────────────────

    def store_chat_message(
        self, user_id: str, session_id: str, role: str, content: str, sources: List[Dict] = None
    ):
        """Store a chat message in history."""
        conn = self._get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO rag_chat_history (user_id, session_id, role, content, sources)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (user_id, session_id, role, content, json.dumps(sources or [])),
                )
                conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Error storing chat message: {e}")
        finally:
            self._put_conn(conn)

    def get_chat_history(self, session_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Retrieve recent chat history for a session."""
        conn = self._get_conn()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT role, content, sources, created_at::text as created_at
                    FROM rag_chat_history
                    WHERE session_id = %s
                    ORDER BY created_at DESC
                    LIMIT %s
                    """,
                    (session_id, limit),
                )
                rows = cur.fetchall()
                rows.reverse()  # Return in chronological order
                return [dict(r) for r in rows]
        except Exception as e:
            logger.error(f"Error fetching chat history: {e}")
            return []
        finally:
            self._put_conn(conn)

    # ── Ingestion Log ──────────────────────────────────────────────

    def log_ingestion(self, source_type: str, symbol: Optional[str], document_count: int):
        """Log an ingestion event."""
        conn = self._get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO rag_ingestion_log (source_type, symbol, document_count)
                    VALUES (%s, %s, %s)
                    """,
                    (source_type, symbol, document_count),
                )
                conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Error logging ingestion: {e}")
        finally:
            self._put_conn(conn)

    def get_last_ingestion(self, source_type: str, symbol: Optional[str] = None) -> Optional[datetime]:
        """Get the last ingestion timestamp for a source type/symbol."""
        conn = self._get_conn()
        try:
            with conn.cursor() as cur:
                if symbol:
                    cur.execute(
                        """
                        SELECT last_ingested_at FROM rag_ingestion_log
                        WHERE source_type = %s AND symbol = %s
                        ORDER BY last_ingested_at DESC LIMIT 1
                        """,
                        (source_type, symbol),
                    )
                else:
                    cur.execute(
                        """
                        SELECT last_ingested_at FROM rag_ingestion_log
                        WHERE source_type = %s AND symbol IS NULL
                        ORDER BY last_ingested_at DESC LIMIT 1
                        """,
                        (source_type,),
                    )
                row = cur.fetchone()
                return row[0] if row else None
        except Exception as e:
            logger.error(f"Error getting last ingestion: {e}")
            return None
        finally:
            self._put_conn(conn)
