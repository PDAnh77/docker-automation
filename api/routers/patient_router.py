from fastapi import APIRouter, Query
from schemas.patient_schema import PatientGet, PatientCreate, PatientUpdate

from services.patient_service import (
    get_patients_service,
    get_patient_service,
    create_patient_service,
    update_patient_service,
    delete_patient_service,
    get_random_patient_service
)

router = APIRouter()

@router.get("/")
def get_patients(
    limit: int = Query(10, ge=1, le=100, description="Number of patient records per page"),
    offset: int = Query(0, ge=0, description="Starting index"),
):
    return get_patients_service(limit, offset)

@router.get("/rand")
def get_random_patient():
    return get_random_patient_service()

@router.get("/{patient_id}", response_model=PatientGet)
def get_patient(patient_id: str):
    return get_patient_service(patient_id)

@router.post("/")
def create_patient(new_patient: PatientCreate):
    return create_patient_service(new_patient.model_dump())

@router.put("/{patient_id}")
def update_patient(patient_id: str, patient: PatientUpdate):
    update_data = patient.model_dump(exclude_unset=True)
    return update_patient_service(patient_id, update_data)

@router.delete("/{patient_id}")
def delete_patient(patient_id: str):
    return delete_patient_service(patient_id)
