from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import httpx
import datetime
import io
import csv
import json
from fastapi.responses import StreamingResponse
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, JSON
from sqlalchemy.orm import declarative_base, sessionmaker, Session

# ---  MySQL Database Setup ---
SQLALCHEMY_DATABASE_URL = "mysql+pymysql://root:JustBeLoud#09@localhost:3306/weather_db"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- SQLAlchemy Database Model  ---
class DBWeatherRecord(Base):
    __tablename__ = "weather_records"

    id = Column(Integer, primary_key=True, index=True)
    city_name = Column(String(100), index=True)
    latitude = Column(Float)
    longitude = Column(Float)
    start_date = Column(String(10)) 
    end_date = Column(String(10))
    dates = Column(JSON)             
    weather_codes = Column(JSON)     
    temperatures_max = Column(JSON)  
    temperatures_min = Column(JSON)  
    precipitation_sum = Column(JSON) 
    google_maps_url = Column(String(255)) 
    youtube_url = Column(String(255))     
    user_notes = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

Base.metadata.create_all(bind=engine)

# ---  Pydantic Schemas ---
class CurrentWeather(BaseModel):
    temperature: float
    weather_code: int
    precipitation: float
    wind_direction: float
    wind_gusts: float
    aqi: Optional[float]

class DailyForecast(BaseModel):
    dates: List[str]
    max_temp: List[float]
    min_temp: List[float]
    precipitation_prob: List[int]
    weather_code: List[int]

class HourlyForecast(BaseModel):
    times: List[str]
    temperatures: List[float]
    precipitation_prob: List[int]
    weather_code: List[int]

class LiveWeatherResponse(BaseModel):
    city_name: str
    latitude: float
    longitude: float
    map_url: str
    current: CurrentWeather
    forecast_5_day: DailyForecast
    hourly_forecast: HourlyForecast

class WeatherSearchRequest(BaseModel):
    city: str
    start_date: datetime.date
    end_date: datetime.date
    notes: Optional[str] = None

class WeatherRecordUpdate(BaseModel):
    city: str
    start_date: datetime.date
    end_date: datetime.date
    notes: Optional[str] = None

class WeatherRecordResponse(BaseModel):
    id: int
    city_name: str
    start_date: datetime.date
    end_date: datetime.date
    dates: List[str]
    weather_codes: List[int]
    temperatures_max: List[float]
    temperatures_min: List[float]
    precipitation_sum: List[float]
    google_maps_url: str             
    youtube_url: str                 
    user_notes: Optional[str] = None
    created_at: datetime.datetime

    class Config:
        from_attributes = True 

# --- FastAPI App & Dependency ---
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],    
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- INFO ENDPOINT  ---

@app.get("/")
def read_root():
    return {
        "developer": "Mohd Shaff HAd Khan", 
        "app_status": "Weather API is running perfectly!",
        "company": "Product Manager Accelerator",
        "description": "The Product Manager Accelerator is a premier program designed to help professionals transition into and excel in product management roles. We provide community, mentorship, and resources to build real-world AI products."
    }

# --- LIVE DASHBOARD ENDPOINT ---

@app.get("/weather/live", response_model=LiveWeatherResponse)
async def get_live_dashboard(city: str):
    async with httpx.AsyncClient() as client:
        geo_res = await client.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": city, "count": 1, "language": "en", "format": "json"}
        )
        geo_data = geo_res.json()
        if not geo_data.get("results"):
            raise HTTPException(status_code=404, detail="City not found")
        location = geo_data["results"][0]

        weather_res = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                "latitude": location["latitude"],
                "longitude": location["longitude"],
                "current": "temperature_2m,weather_code,precipitation,wind_direction_10m,wind_gusts_10m",
                "hourly": "temperature_2m,weather_code,precipitation_probability",
                "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max",
                "timezone": "auto",
                "forecast_days": 5,
                "forecast_hours": 24
            }
        )
        weather_data = weather_res.json()

        aqi_res = await client.get(
            "https://air-quality-api.open-meteo.com/v1/air-quality",
            params={
                "latitude": location["latitude"],
                "longitude": location["longitude"],
                "current": "us_aqi"
            }
        )
        aqi_data = aqi_res.json()
        current_aqi = aqi_data.get("current", {}).get("us_aqi")

    return LiveWeatherResponse(
        city_name=location["name"],
        latitude=location["latitude"],
        longitude=location["longitude"],
        map_url=f"https://www.google.com/maps?q={location['latitude']},{location['longitude']}",
        current=CurrentWeather(
            temperature=weather_data["current"]["temperature_2m"],
            weather_code=weather_data["current"]["weather_code"],
            precipitation=weather_data["current"]["precipitation"],
            wind_direction=weather_data["current"]["wind_direction_10m"],
            wind_gusts=weather_data["current"]["wind_gusts_10m"],
            aqi=current_aqi
        ),
        forecast_5_day=DailyForecast(
            dates=weather_data["daily"]["time"],
            max_temp=weather_data["daily"]["temperature_2m_max"],
            min_temp=weather_data["daily"]["temperature_2m_min"],
            precipitation_prob=weather_data["daily"]["precipitation_probability_max"],
            weather_code=weather_data["daily"]["weather_code"]
        ),
        hourly_forecast=HourlyForecast(
            times=weather_data["hourly"]["time"],
            temperatures=weather_data["hourly"]["temperature_2m"],
            precipitation_prob=weather_data["hourly"]["precipitation_probability"],
            weather_code=weather_data["hourly"]["weather_code"]
        )
    )


# --- MySQL CRUD ENDPOINTS ---


@app.post("/weather/", response_model=WeatherRecordResponse)
async def create_weather_record(request: WeatherSearchRequest, db: Session = Depends(get_db)):
    if request.start_date > request.end_date:
        raise HTTPException(status_code=400, detail="Start date cannot be after end date.")

    async with httpx.AsyncClient() as client:
        geo_res = await client.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": request.city, "count": 1, "language": "en", "format": "json"}
        )
        geo_data = geo_res.json()
        if not geo_data.get("results"):
            raise HTTPException(status_code=404, detail="City not found")
        location = geo_data["results"][0]

        weather_res = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                "latitude": location["latitude"],
                "longitude": location["longitude"],
                "start_date": request.start_date.isoformat(),
                "end_date": request.end_date.isoformat(),
                "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum",
                "timezone": "auto"
            }
        )
        weather_data = weather_res.json()
        
        if "daily" not in weather_data:
            raise HTTPException(status_code=400, detail="Could not retrieve weather for the specified date range.")

    gmaps_url = f"https://www.google.com/maps?q={location['latitude']},{location['longitude']}"
    yt_url = f"https://www.youtube.com/results?search_query={location['name'].replace(' ', '+')}+city+tour+weather"

    db_record = DBWeatherRecord(
        city_name=location["name"],
        latitude=location["latitude"],
        longitude=location["longitude"],
        start_date=request.start_date.isoformat(),
        end_date=request.end_date.isoformat(),
        dates=weather_data["daily"]["time"],
        weather_codes=weather_data["daily"]["weather_code"],
        temperatures_max=weather_data["daily"]["temperature_2m_max"],
        temperatures_min=weather_data["daily"]["temperature_2m_min"],
        precipitation_sum=weather_data["daily"]["precipitation_sum"],
        google_maps_url=gmaps_url,
        youtube_url=yt_url,
        user_notes=request.notes
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record) 
    return db_record

@app.get("/weather/", response_model=List[WeatherRecordResponse])
def read_all_records(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(DBWeatherRecord).offset(skip).limit(limit).all()

@app.put("/weather/{record_id}", response_model=WeatherRecordResponse)
async def update_record(record_id: int, update_data: WeatherRecordUpdate, db: Session = Depends(get_db)):
    if update_data.start_date > update_data.end_date:
        raise HTTPException(status_code=400, detail="Start date cannot be after end date.")

    db_record = db.query(DBWeatherRecord).filter(DBWeatherRecord.id == record_id).first()
    if not db_record:
        raise HTTPException(status_code=404, detail="Record not found")
    
    async with httpx.AsyncClient() as client:
        geo_res = await client.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={"name": update_data.city, "count": 1, "language": "en", "format": "json"}
        )
        geo_data = geo_res.json()
        if not geo_data.get("results"):
            raise HTTPException(status_code=400, detail="New city not found or invalid location.")
        location = geo_data["results"][0]

        weather_res = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params={
                "latitude": location["latitude"],
                "longitude": location["longitude"],
                "start_date": update_data.start_date.isoformat(),
                "end_date": update_data.end_date.isoformat(),
                "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum",
                "timezone": "auto"
            }
        )
        weather_data = weather_res.json()
        
        if "daily" not in weather_data:
            raise HTTPException(status_code=400, detail="Could not retrieve weather for the specified date range.")

    gmaps_url = f"https://www.google.com/maps?q={location['latitude']},{location['longitude']}"
    yt_url = f"https://www.youtube.com/results?search_query={location['name'].replace(' ', '+')}+city+tour+weather"

    db_record.city_name = location["name"]
    db_record.latitude = location["latitude"]
    db_record.longitude = location["longitude"]
    db_record.start_date = update_data.start_date.isoformat()
    db_record.end_date = update_data.end_date.isoformat()
    db_record.dates = weather_data["daily"]["time"]
    db_record.weather_codes = weather_data["daily"]["weather_code"]
    db_record.temperatures_max = weather_data["daily"]["temperature_2m_max"]
    db_record.temperatures_min = weather_data["daily"]["temperature_2m_min"]
    db_record.precipitation_sum = weather_data["daily"]["precipitation_sum"]
    db_record.google_maps_url = gmaps_url
    db_record.youtube_url = yt_url
    if update_data.notes is not None:
        db_record.user_notes = update_data.notes
    
    db.commit()
    db.refresh(db_record)
    return db_record

@app.delete("/weather/{record_id}")
def delete_record(record_id: int, db: Session = Depends(get_db)):
    db_record = db.query(DBWeatherRecord).filter(DBWeatherRecord.id == record_id).first()
    if not db_record:
        raise HTTPException(status_code=404, detail="Record not found")
    
    db.delete(db_record)
    db.commit()
    return {"message": f"Record {record_id} successfully deleted"}

# --- DATA EXPORT ENDPOINT ---

@app.get("/weather/export/csv")
def export_data_to_csv(db: Session = Depends(get_db)):
    records = db.query(DBWeatherRecord).all()
    output = io.StringIO()
    writer = csv.writer(output)
    
    
    writer.writerow([
        "ID", "City", "Latitude", "Longitude", 
        "Date", "Max Temp (C)", "Min Temp (C)", "Precipitation (mm)", "Weather Code",
        "Google Maps URL", "YouTube URL", "User Notes"
    ])
    
    for r in records:
    
        dates = r.dates if isinstance(r.dates, list) else json.loads(r.dates)
        t_max = r.temperatures_max if isinstance(r.temperatures_max, list) else json.loads(r.temperatures_max)
        t_min = r.temperatures_min if isinstance(r.temperatures_min, list) else json.loads(r.temperatures_min)
        precip = r.precipitation_sum if isinstance(r.precipitation_sum, list) else json.loads(r.precipitation_sum)
        codes = r.weather_codes if isinstance(r.weather_codes, list) else json.loads(r.weather_codes)

        
        for i in range(len(dates)):
            
            raw_date = dates[i]
            try:
                dt_obj = datetime.datetime.strptime(raw_date, "%Y-%m-%d")
                formatted_date = dt_obj.strftime("%B %d, %Y")
            except:
                formatted_date = raw_date

            writer.writerow([
                r.id, r.city_name, r.latitude, r.longitude,
                formatted_date, t_max[i], t_min[i], precip[i], codes[i],
                r.google_maps_url, r.youtube_url, r.user_notes
            ])
        
    return StreamingResponse(
        iter([output.getvalue()]), 
        media_type="text/csv", 
        headers={"Content-Disposition": "attachment; filename=weather_history_export.csv"}
    )