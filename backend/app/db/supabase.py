from functools import lru_cache

from supabase import Client, create_client

from app.config import settings


@lru_cache(maxsize=1)
def get_supabase() -> Client:
    """Anon-key client — for auth operations (sign in, sign up, JWT verification)."""
    return create_client(settings.supabase_url, settings.supabase_anon_key)


@lru_cache(maxsize=1)
def get_supabase_admin() -> Client:
    """Service-role client — for DB access and admin auth actions (e.g. sign out)."""
    return create_client(settings.supabase_url, settings.supabase_service_role_key)
