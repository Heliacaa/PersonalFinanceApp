-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- RAG Documents table for storing embedded content
CREATE TABLE IF NOT EXISTS rag_documents (
    id BIGSERIAL PRIMARY KEY,
    source_type VARCHAR(50) NOT NULL,  -- NEWS, REPORT, EDUCATION, RESEARCH
    symbol VARCHAR(20),                 -- Stock symbol (nullable for general docs)
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    embedding vector(384),              -- all-MiniLM-L6-v2 produces 384-dim vectors
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP               -- NULL = never expires
);

-- Chat history table
CREATE TABLE IF NOT EXISTS rag_chat_history (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    session_id VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL,          -- user, assistant
    content TEXT NOT NULL,
    sources JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ingestion log
CREATE TABLE IF NOT EXISTS rag_ingestion_log (
    id BIGSERIAL PRIMARY KEY,
    source_type VARCHAR(50) NOT NULL,
    symbol VARCHAR(20),
    document_count INTEGER DEFAULT 0,
    last_ingested_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_rag_docs_symbol ON rag_documents(symbol);
CREATE INDEX IF NOT EXISTS idx_rag_docs_source ON rag_documents(source_type);
CREATE INDEX IF NOT EXISTS idx_rag_docs_expires ON rag_documents(expires_at);
CREATE INDEX IF NOT EXISTS idx_rag_chat_session ON rag_chat_history(session_id);
CREATE INDEX IF NOT EXISTS idx_rag_chat_user ON rag_chat_history(user_id);

-- IVFFlat index for vector similarity search (good for up to ~1M rows)
-- Using lists=100 which works well for moderate datasets
CREATE INDEX IF NOT EXISTS idx_rag_docs_embedding ON rag_documents
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
