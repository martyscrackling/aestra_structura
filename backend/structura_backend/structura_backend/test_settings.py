"""
Settings overlay used by the test suite.

The real migration history in `app/migrations/` is broken when applied
from scratch (migration 0031 re-creates the `app_user` table that was
already produced by an earlier migration). We don't want to rewrite
history in production, so for tests we:

    * Point the database at an in-memory SQLite.
    * Disable migrations entirely — Django's test runner will `syncdb`
      the current model state, which matches what the app expects at
      runtime.

Invoke with:

    python manage.py test rest_api --settings=structura_backend.test_settings
"""

from .settings import *  # noqa: F401,F403


DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": ":memory:",
    }
}


class _DisableMigrations:
    """Makes Django treat every app as unmigrated so tables are built from
    the current model definitions via ``syncdb``.
    """

    def __contains__(self, item):
        return True

    def __getitem__(self, item):
        return None


MIGRATION_MODULES = _DisableMigrations()

# Speed up password hashing in tests (Supervisors model hashes passwords
# in save() and this otherwise dominates setUp cost).
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]
