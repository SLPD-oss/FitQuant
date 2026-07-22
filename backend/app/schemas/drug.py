from pydantic import BaseModel, Field
from typing import Optional

class DrugLookupRequest(BaseModel):
    drug_name: str = Field(..., examples=["左氧氟沙星"])

class DrugLookupResponse(BaseModel):
    drug_name: str
    category: str = Field(..., description="typeA / typeB / traditionalChMedicine / otc")
    category_display: str
    aliases: list[str] = []
    common_dosage: str = ""
    common_unit: str = ""
    is_prescription: bool
    risk_tags: list[str] = []
    from_database: str = "国家药品监督管理局 NMPA"

class ActiveDrug(BaseModel):
    drug_name: str
    dosage: str = ""
    unit: str = ""
    frequency: str = ""

class DrugRiskCheckRequest(BaseModel):
    active_drugs: list[ActiveDrug]
    training_type: str = Field(..., description="strength / cardio")
    target_muscle_groups: list[str] = []

class DrugRiskDetail(BaseModel):
    drug_name: str
    risk_level: str = Field(..., description="high / medium / low")
    risk_description: str
    affected_body_parts: list[str] = []
    suggestion: str
    literature_refs: list[dict] = []

class DrugRiskCheckResponse(BaseModel):
    has_risk: bool
    risks: list[DrugRiskDetail] = []
