from fastapi import HTTPException, status
from supabase_auth.errors import AuthApiError
from supabase import Client

from app.models.auth import AuthResponse, MessageResponse


def register(client: Client, email: str, password: str) -> AuthResponse | MessageResponse:
    try:
        result = client.auth.sign_up({"email": email, "password": password})
    except AuthApiError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    session = result.session
    if session is None:
        # Supabase requires email confirmation — no session issued yet
        return MessageResponse(message="Check your email to confirm your account.")

    return AuthResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
    )


def login(client: Client, email: str, password: str) -> AuthResponse:
    try:
        result = client.auth.sign_in_with_password({"email": email, "password": password})
    except AuthApiError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    session = result.session
    return AuthResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
    )


def refresh(client: Client, refresh_token: str) -> AuthResponse:
    try:
        result = client.auth.refresh_session(refresh_token)
    except AuthApiError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    session = result.session
    return AuthResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
    )


def logout(admin_client: Client, user_id: str) -> None:
    try:
        admin_client.auth.admin.sign_out(user_id)
    except AuthApiError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
