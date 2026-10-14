import server


def test_no_hardcoded_jwt_secrets_in_server():
    with open("server.py", "r", encoding="utf-8") as source:
        code = source.read()
    assert "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" not in code


def test_supabase_configuration_is_optional_outside_production():
    # Unit tests and CI must work without copying production credentials into the workspace.
    assert isinstance(server.SUPABASE_URL, str)
    assert isinstance(server.SUPABASE_ANON_KEY, str)
    assert isinstance(server.SUPABASE_SERVICE_ROLE_KEY, str)


def test_default_languages_are_hindi_first():
    assert server.DEFAULT_LANGUAGES == ["hindi"]


def test_parse_languages_defaults_to_hindi():
    assert server.parse_languages(None) == ["hindi"]
    assert server.parse_languages("") == ["hindi"]


def test_parse_languages_single_languages():
    assert server.parse_languages("hindi") == ["hindi"]
    assert server.parse_languages("marathi") == ["marathi"]
    assert server.parse_languages("punjabi") == ["punjabi"]


def test_parse_languages_all_group():
    all_languages = server.parse_languages("all")
    assert "hindi" in all_languages
    assert "marathi" in all_languages
    assert "tamil" in all_languages
    assert all_languages[0] == "hindi"
