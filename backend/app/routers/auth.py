from fastapi import APIRouter, Depends, status
from supabase import Client

from app.db.supabase import get_supabase, get_supabase_admin
from app.dependencies import get_current_user
from app.models.auth import AuthResponse, LoginRequest, RefreshRequest, RegisterRequest
from app.services import auth as auth_service

router = APIRouter()


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, supabase: Client = Depends(get_supabase)):
    return auth_service.register(supabase, body.email, body.password)


@router.post("/login", response_model=AuthResponse)
def login(body: LoginRequest, supabase: Client = Depends(get_supabase)):
    return auth_service.login(supabase, body.email, body.password)


@router.post("/refresh", response_model=AuthResponse)
def refresh(body: RefreshRequest, supabase: Client = Depends(get_supabase)):
    return auth_service.refresh(supabase, body.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    current_user=Depends(get_current_user),
    admin: Client = Depends(get_supabase_admin),
):
    auth_service.logout(admin, current_user.id)
