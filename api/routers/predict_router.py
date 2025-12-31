from typing import List
from fastapi import APIRouter
from schemas.patient_schema import PatientBase
from services.predict_service import predict_result

router = APIRouter()

@router.post("")
def predict(patient: PatientBase):
    result = predict_result(patient.model_dump())
    return result

@router.post("/batch")
def predict_batch(patients: List[PatientBase]):
    patient_data_list = [patient.model_dump() for patient in patients]
    return predict_result(patient_data_list)
