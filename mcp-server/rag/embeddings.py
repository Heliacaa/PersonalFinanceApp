"""
Embedding service using sentence-transformers (all-MiniLM-L6-v2).
Produces 384-dimensional vectors for semantic similarity search.
"""

import os
import logging
from typing import List, Optional

logger = logging.getLogger(__name__)

# Lazy-loaded model to avoid import-time overhead
_model = None
_model_name = "all-MiniLM-L6-v2"


def _get_model():
    """Lazy-load the sentence-transformers model."""
    global _model
    if _model is None:
        try:
            from sentence_transformers import SentenceTransformer
            logger.info(f"Loading embedding model: {_model_name}...")
            _model = SentenceTransformer(_model_name)
            logger.info(f"✅ Embedding model loaded ({_model_name}, dim=384)")
        except Exception as e:
            logger.error(f"❌ Failed to load embedding model: {e}")
            raise
    return _model


class EmbeddingService:
    """Service for generating text embeddings using sentence-transformers."""

    def __init__(self):
        self._available: Optional[bool] = None

    @property
    def is_available(self) -> bool:
        """Check if the embedding model can be loaded."""
        if self._available is None:
            try:
                _get_model()
                self._available = True
            except Exception:
                self._available = False
        return self._available

    def embed_text(self, text: str) -> List[float]:
        """
        Generate an embedding vector for a single text string.

        Args:
            text: The input text to embed.

        Returns:
            A list of 384 floats representing the embedding vector.
        """
        model = _get_model()
        # Truncate very long texts to avoid OOM (model max is ~256 tokens)
        truncated = text[:2000]
        embedding = model.encode(truncated, show_progress_bar=False)
        return embedding.tolist()

    def embed_batch(self, texts: List[str], batch_size: int = 32) -> List[List[float]]:
        """
        Generate embedding vectors for a batch of texts.

        Args:
            texts: List of input texts to embed.
            batch_size: Number of texts to process at once.

        Returns:
            A list of embedding vectors (each 384 floats).
        """
        model = _get_model()
        # Truncate each text
        truncated = [t[:2000] for t in texts]
        embeddings = model.encode(truncated, batch_size=batch_size, show_progress_bar=False)
        return [e.tolist() for e in embeddings]

    @staticmethod
    def get_dimension() -> int:
        """Return the embedding dimension for this model."""
        return 384
