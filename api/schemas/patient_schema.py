from pydantic import BaseModel, Field

class PatientBase(BaseModel):
    age: int = Field(..., ge=1, le=120, description="Age of the patient")
    sex: str = Field(..., pattern="^(M|F)$", description="Sex of the patient")
    chest_pain_type: str = Field(..., pattern="^(TA|ATA|NAP|ASY)$", description="Chest pain type [TA: Typical Angina, ATA: Atypical Angina, NAP: Non-Anginal Pain, ASY: Asymptomatic]")
    resting_bp: int = Field(..., gt=0, description="Resting blood pressure [mm Hg]")
    cholesterol: int = Field(..., ge=0, description="Serum cholesterol [mm/dl]")
    fasting_bs: int = Field(..., ge=0, le=1, description="Fasting blood sugar [1: if FastingBS > 120 mg/dl, 0: otherwise]")
    resting_ecg: str = Field(..., pattern="^(Normal|ST|LVH)$", description="Resting electrocardiogram results [Normal: Normal, ST: having ST-T wave abnormality (T wave inversions and/or ST elevation or depression of > 0.05 mV), LVH: showing probable or definite left ventricular hypertrophy by Estes' criteria]")
    max_hr: int = Field(..., gt=0, description="Maximum heart rate")
    exercise_angina: str = Field(..., pattern="^(Y|N)$", description="Exercise-induced angina [Y: Yes, N: No]")
    oldpeak: float = Field(..., ge=0.0, description="= ST [Numeric value measured in depression]")
    st_slope: str = Field(..., pattern="^(Up|Flat|Down)$", description="The slope of the peak exercise ST segment [Up: upsloping, Flat: flat, Down: downsloping]")

class PatientGet(PatientBase):
    heart_disease: int = Field(default=0, ge=0, le=1)
    
class PatientCreate(PatientGet):
    pass

class PatientUpdate(BaseModel):
    age: int | None = Field(None, ge=1, le=120)
    sex: str | None = Field(None, pattern="^(M|F)$")
    chest_pain_type: str | None = Field(None, pattern="^(TA|ATA|NAP|ASY)$")
    resting_bp: int | None = Field(None, gt=0)
    cholesterol: int | None = Field(None, gt=0)
    fasting_bs: int | None = Field(None, ge=0, le=1)
    resting_ecg: str | None = Field(None, pattern="^(Normal|ST|LVH)$")
    max_hr: int | None = Field(None, gt=0)
    exercise_angina: str | None = Field(None, pattern="^(Y|N)$")
    oldpeak: float | None = Field(None, ge=0.0)
    st_slope: str | None = Field(None, pattern="^(Up|Flat|Down)$")
    heart_disease: int | None = Field(None, ge=0, le=1)