from fastapi import HTTPException
import uuid
from db.database import supabase

TABLE_NAME = "patient_info"

def get_patients_service(limit: int, offset: int):
    result = (
        supabase.table(TABLE_NAME)
        .select("*")
        .range(offset, offset + limit - 1)
        .execute()
    )
    return {"data": result.data, "count": len(result.data)}

def get_random_patient_service():
    rand_uuid = str(uuid.uuid4())
    result = supabase.table(TABLE_NAME).select("*").order("id").gte("id", rand_uuid).limit(1).execute()
    if not result.data:
        result = supabase.table(TABLE_NAME).select("*").order("id").limit(1).execute()
    return result

def get_patient_service(patient_id: str):
    result = supabase.table(TABLE_NAME).select("*").eq("id", patient_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Patient not found")
    return result.data

def create_patient_service(new_patient: dict):
    result = supabase.table(TABLE_NAME).insert(new_patient).execute()
    return result.data

def update_patient_service(patient_id: str, update_data: dict):
    result = (
        supabase.table(TABLE_NAME)
        .update(update_data)
        .eq("id", patient_id)
        .execute()
    )
    return result.data

def delete_patient_service(patient_id: str):
    result = supabase.table(TABLE_NAME).delete().eq("id", patient_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Patient not found")
    return "Success"
