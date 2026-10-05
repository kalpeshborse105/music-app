from setuptools import setup

setup(
    name="music-api",
    version="1.0.0",
    py_modules=["server"],
    entry_points={
        "console_scripts": [
            "uvicorn=server:uvicorn_fallback",
        ],
    },
)
