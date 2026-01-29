from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import pandas as pd
import io
from textblob import TextBlob

app = FastAPI(title="SentixInvest MCP Server", version="1.0.0")

class SentinelRequest(BaseModel):
    text: str

class SentinelResponse(BaseModel):
    polarity: float
    subjectivity: float
    sentiment: str

@app.get("/")
def read_root():
    return {"status": "healthy", "service": "sentix-mcp-server"}

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
            
        # Basic Portfolio Analysis Mockup
        # Assuming columns like 'Symbol', 'Quantity', 'PurchasePrice' exist
        summary = {
            "total_rows": len(df),
            "columns": list(df.columns),
            "preview": df.head(5).to_dict(orient='records')
        }
        
        return {"status": "success", "analysis": summary}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error analyzing portfolio: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
