import random, string
from fastapi import APIRouter, HTTPException, Depends, Response, Request
from starlette.responses import RedirectResponse
from db.database import supabase
from core.config import settings
from schemas.user_schema import UserBase
from services.auth_service import generate_token, verify_password, get_password_hash, validate_token, oauth

router = APIRouter()
TABLE_NAME = "user"

@router.post("/auth/login")
def login(response: Response, data: UserBase):
    existing_user = supabase.table(TABLE_NAME).select("*").eq("username", data.username).execute().data
    if not existing_user:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    current_user = existing_user[0]
    if not verify_password(data.password, current_user["password"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    access_token = generate_token(current_user["username"])
    
    response.set_cookie(
        key="access_token",
        value=access_token,
        secure=True,
        httponly=True,
        samesite="lax",
        max_age=60*60,
        path="/"
    )
    return {"username": current_user["username"]}

@router.get("/auth/google")
async def google_login(request: Request):
    return await oauth.auth_google.authorize_redirect(request, settings.REDIRECT_URI, prompt="select_account")

@router.get("/auth/google/callback")
async def google_callback(request: Request):
    token = await oauth.auth_google.authorize_access_token(request)
    userinfo = token.get("userinfo")
    email = userinfo.get("email")

    existing_user = supabase.table("user").select("*").eq("email", email).execute().data
    if not existing_user:
        prefix = email.split('@')[0].rstrip('0123456789')
        random_digits = ''.join(random.choices(string.digits, k=5))
        username = f"{prefix}{random_digits}"
        supabase.table("user").insert({"username": username, "email": email}).execute()
        existing_user = username
    else:
        existing_user = existing_user[0]["username"]
    
    access_token = generate_token(existing_user)

    response = RedirectResponse(url=f"{settings.NEXT_APP_URL}/predict")
    response.set_cookie(
        key="access_token",
        value=access_token,
        secure=True,
        httponly=False,
        samesite="lax",
        max_age=60*60,
        path="/"
    )
    return response

@router.get("/user/me")
def get_me(username: str = Depends(validate_token)):
    return {"username": username}
    
@router.post("/user/signup",  dependencies=[Depends(validate_token)])
def signup(new_user: UserBase):
    existing_user = supabase.table(TABLE_NAME).select("*").eq("username", new_user.username).execute().data
    if existing_user:
        raise HTTPException(status_code=409, detail="User already existed")
    new_user.password = get_password_hash(new_user.password)
    result = supabase.table(TABLE_NAME).insert(new_user.model_dump()).execute()
    return result.data

@router.post("/auth/logout")
def logout(response: Response):
    response.delete_cookie(key="access_token", path="/")
    return {"detail": "Logged out"}