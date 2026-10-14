import os
import server


def test_no_hardcoded_jwt_secrets_in_server():
    with open("server.py", "r", encoding="utf-8") as f:
        code = f.read()
    # Confirm raw Supabase JWT tokens are NOT hardcoded in code
    assert "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" not in code


def test_env_loader_loads_supabase_credentials():
    assert bool(server.SUPABASE_URL), "SUPABASE_URL should be loaded from .env"
    assert bool(server.SUPABASE_ANON_KEY), "SUPABASE_ANON_KEY should be loaded from .env"
    assert bool(server.SUPABASE_SERVICE_ROLE_KEY), "SUPABASE_SERVICE_ROLE_KEY should be loaded from .env"


def test_default_languages_is_strict_hindi():
    assert server.DEFAULT_LANGUAGES == ["hindi"]


def test_parse_languages_defaults_to_hindi():
    assert server.parse_languages(None) == ["hindi"]
    assert server.parse_languages("") == ["hindi"]


def test_parse_languages_single_languages():
    assert server.parse_languages("hindi") == ["hindi"]
    assert server.parse_languages("marathi") == ["marathi"]
    assert server.parse_languages("punjabi") == ["punjabi"]


def test_parse_languages_all_group():
    all_langs = server.parse_languages("all")
    assert "hindi" in all_langs
    assert "marathi" in all_langs
    assert "tamil" in all_langs
    assert all_langs[0] == "hindi"
