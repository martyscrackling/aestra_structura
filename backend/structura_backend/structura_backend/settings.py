"""Django settings for structura_backend project."""

from pathlib import Path
import os
from django.core.exceptions import ImproperlyConfigured
from urllib.parse import urlparse

import dj_database_url

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/

DEBUG = os.getenv("DEBUG", "1") == "1"

# In production, set SECRET_KEY as an env var.
SECRET_KEY = os.getenv("SECRET_KEY", "unsafe-dev-secret-key")

_allowed_hosts = os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1").strip()
ALLOWED_HOSTS = [h.strip() for h in _allowed_hosts.split(",") if h.strip()]

# Render sets the external hostname in an env var. This makes deployments work
# even if ALLOWED_HOSTS isn't manually set.
_render_external_hostname = os.getenv("RENDER_EXTERNAL_HOSTNAME", "").strip()
if _render_external_hostname and _render_external_hostname not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append(_render_external_hostname)


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'rest_framework',
    'rest_api',
    'app'
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

_cors_origins = os.getenv("CORS_ALLOWED_ORIGINS", "").strip()

_cors_allow_all = os.getenv("CORS_ALLOW_ALL_ORIGINS", "").strip().lower()
if _cors_allow_all:
    CORS_ALLOW_ALL_ORIGINS = _cors_allow_all in {"1", "true", "yes"}
else:
    # Keep dev experience simple; lock down in prod by setting CORS_ALLOWED_ORIGINS.
    CORS_ALLOW_ALL_ORIGINS = DEBUG

if _cors_origins:
    CORS_ALLOWED_ORIGINS = [o.strip() for o in _cors_origins.split(",") if o.strip()]

_cors_origin_regexes = os.getenv("CORS_ALLOWED_ORIGIN_REGEXES", "").strip()
if _cors_origin_regexes:
    CORS_ALLOWED_ORIGIN_REGEXES = [
        r.strip() for r in _cors_origin_regexes.split(",") if r.strip()
    ]

if os.getenv("CORS_ALLOW_LOCALHOST", "0").strip() == "1":
    CORS_ALLOWED_ORIGIN_REGEXES = list(
        globals().get("CORS_ALLOWED_ORIGIN_REGEXES", [])
    ) + [
        r"^http://localhost(:\d+)?$",
        r"^http://127\.0\.0\.1(:\d+)?$",
    ]

_csrf_trusted = os.getenv("CSRF_TRUSTED_ORIGINS", "").strip()
CSRF_TRUSTED_ORIGINS = [o.strip() for o in _csrf_trusted.split(",") if o.strip()]

ROOT_URLCONF = 'structura_backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'structura_backend.wsgi.application'


# Database
# https://docs.djangoproject.com/en/5.2/ref/settings/#databases

DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
if DATABASE_URL:
    _db_conn_max_age = int(os.getenv("DB_CONN_MAX_AGE", "600"))
    DATABASES = {
        "default": dj_database_url.parse(
            DATABASE_URL,
            conn_max_age=_db_conn_max_age,
            ssl_require=True,
        )
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }




# Password validation
# https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ]
}



# Internationalization
# https://docs.djangoproject.com/en/5.2/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# Email (optional)
# If SMTP env vars are not set, Django will print emails to the console.
APP_NAME = os.getenv("APP_NAME", "Structura")
FRONTEND_URL = os.getenv("FRONTEND_URL", "").strip()

# Optional: SendGrid API (recommended for production reliability on hosting providers that block SMTP)
SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY", "").strip()
SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL", "").strip()

EMAIL_HOST = os.getenv("EMAIL_HOST", "").strip()
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "").strip()
EMAIL_HOST_PASSWORD = (
    os.getenv("EMAIL_HOST_PASSWORD", "")
    .replace(" ", "")
    .replace("\n", "")
    .replace("\r", "")
    .strip()
)
EMAIL_TIMEOUT = int(os.getenv("EMAIL_TIMEOUT", "10"))
_email_use_tls_raw = os.getenv("EMAIL_USE_TLS", "").strip()
if not _email_use_tls_raw:
    # Some deployments accidentally use MAIL_USE_TLS.
    _email_use_tls_raw = os.getenv("MAIL_USE_TLS", "1").strip()
EMAIL_USE_TLS = _email_use_tls_raw.lower() in {"1", "true", "yes"}
DEFAULT_FROM_EMAIL = os.getenv("DEFAULT_FROM_EMAIL", EMAIL_HOST_USER or "no-reply@localhost")

if EMAIL_HOST:
    EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
else:
    EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"


# If FRONTEND_URL is provided, default CORS/CSRF settings to allow it.
# This prevents common "Failed to fetch" errors on Flutter Web when CORS/CSRF env vars
# were not configured for production.
if FRONTEND_URL:
    parsed_frontend = urlparse(FRONTEND_URL)
    if parsed_frontend.scheme and parsed_frontend.netloc:
        frontend_origin = f"{parsed_frontend.scheme}://{parsed_frontend.netloc}"
        if not globals().get("CORS_ALLOW_ALL_ORIGINS", False):
            existing_allowed = set(globals().get("CORS_ALLOWED_ORIGINS", []))
            if not existing_allowed:
                CORS_ALLOWED_ORIGINS = [frontend_origin]
            elif frontend_origin not in existing_allowed:
                CORS_ALLOWED_ORIGINS = list(existing_allowed) + [frontend_origin]

        existing_csrf = set(globals().get("CSRF_TRUSTED_ORIGINS", []))
        if frontend_origin not in existing_csrf:
            CSRF_TRUSTED_ORIGINS = list(existing_csrf) + [frontend_origin]


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = '/static/'

STATIC_ROOT = BASE_DIR / "staticfiles"

if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = os.getenv("SECURE_SSL_REDIRECT", "1") == "1"
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

# Default primary key field type
# https://docs.djangoproject.com/en/5.2/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
