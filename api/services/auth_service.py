from authlib.integrations.starlette_client import OAuth
import jwt
from datetime import datetime, timedelta
from fastapi import HTTPException, Request
from pwdlib import PasswordHash
from core.config import settings

algorithm = "HS256"
secret = settings.SECRET_KEY
password_hash = PasswordHash.recommended()

oauth = OAuth()
oauth.register(
    name="auth_google",
    client_id=settings.GOOGLE_CLIENT_ID,
    client_secret=settings.GOOGLE_CLIENT_SECRET,
    authorize_url="https://accounts.google.com/o/oauth2/auth",
    authorize_params={"scope": "openid email profile"},
    access_token_url="https://accounts.google.com/o/oauth2/token",
    jwks_uri="https://www.googleapis.com/oauth2/v3/certs",
    client_kwargs={"scope": "openid profile email"},
)

def verify_password(plain_password: str, hashed_password: str):
    return password_hash.verify(plain_password, hashed_password)

def get_password_hash(password: str):
    return password_hash.hash(password)

def generate_token(username: str):
    expire = datetime.now() + timedelta(hours=1)
    to_encode = {
        "exp": expire, "username": username
    }
    encode_jwt = jwt.encode(to_encode, secret, algorithm=algorithm)
    return encode_jwt

def validate_token(request: Request):
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Not authenticated",
        )
    try:
        payload = jwt.decode(token, secret, algorithms=algorithm)
        username = payload.get("username")
        if not username:
            raise HTTPException(status_code=401, detail="Invalid token")
        return username
    
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.PyJWKError:
        raise HTTPException(status_code=401, detail="Invalid token")