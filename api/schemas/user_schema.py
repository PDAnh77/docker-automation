from pydantic import BaseModel, Field

class UserBase(BaseModel):
    username: str
    email: str | None = Field(None)
    password: str