"""
WSGI config for structura_backend project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/wsgi/
"""

import os
from pathlib import Path

try:
	from dotenv import load_dotenv

	base_dir = Path(__file__).resolve().parent.parent
	load_dotenv(base_dir / ".env", override=False)
except Exception:
	# Best-effort for local dev.
	pass

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'structura_backend.settings')

application = get_wsgi_application()
