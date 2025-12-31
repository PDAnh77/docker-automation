import os
import joblib
from db.database import supabase

_pipeline_instance = None

BUCKET_NAME = "heart-prediction-models"
MODEL_FILENAME = "model_predict.pkl"
TEMP_DOWNLOAD_PATH = f"/tmp/{MODEL_FILENAME}"

# Đường dẫn model ở Local
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
LOCAL_MODEL_PATH = os.path.normpath(os.path.join(CURRENT_DIR, "../../models/model_predict.pkl"))

def load_model_startup():
    global _pipeline_instance
    
    # --- Load từ local path ---
    if os.path.exists(LOCAL_MODEL_PATH):
        print(f"Found local model at: {LOCAL_MODEL_PATH}")
        try:
            _pipeline_instance = joblib.load(LOCAL_MODEL_PATH)
            print("Model loaded successfully from Local.")
            return
        except Exception as e:
            print(f"Failed to load local model. Error: {e}")
            print("Switching to Supabase download...")
    else:
        print(f"Local model not found at {LOCAL_MODEL_PATH}. Downloading from Cloud...")

    # --- Fallback tải từ Supabase ---
    print(f"Connecting Storage to download {MODEL_FILENAME}...")
    try:
        data = supabase.storage.from_(BUCKET_NAME).download(MODEL_FILENAME)
        with open(TEMP_DOWNLOAD_PATH, "wb") as f:
            f.write(data)
            
        _pipeline_instance = joblib.load(TEMP_DOWNLOAD_PATH)
        print(f"Download and load complete from Supabase.")
    except Exception as e:
        print(f"Unable to download model from Supabase.")
        print(f"Error details: {str(e)}")
        raise e

def get_pipeline():
    if _pipeline_instance is None:
        # Fallback: Nếu chưa load thì load ngay lập tức
        load_model_startup()
    return _pipeline_instance