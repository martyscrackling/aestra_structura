"""
Build browser-loadable media URLs for production (e.g. Render) where the public
host differs from the WSGI server or USE_X_FORWARDED_HOST must be set.

Set PUBLIC_BASE_URL in the environment, e.g.:
  https://structura-backend-xxxx.onrender.com
(no path, no trailing slash)
"""
from __future__ import annotations

import os

from django.conf import settings


def absolute_media_url(request, path) -> str | None:
    if path in (None, ''):
        return path
    p = str(path).strip()
    if not p or p in {'null', 'None'}:
        return None
    if p.startswith('http://') or p.startswith('https://'):
        return p
    if not p.startswith('/'):
        p = f"{settings.MEDIA_URL.rstrip('/')}/{p.lstrip('/')}"
    public = (os.environ.get('PUBLIC_BASE_URL') or getattr(
        settings, 'PUBLIC_BASE_URL', ''
    )).strip()
    if public:
        return public.rstrip('/') + p
    if request is not None and hasattr(request, 'build_absolute_uri'):
        return request.build_absolute_uri(p)
    return p
