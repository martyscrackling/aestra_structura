"""
Image verification helpers used during profile photo uploads.

Current rule:
- ACCEPT when at least one human face is detected
- REJECT when no human face is detected
"""

from __future__ import annotations

import io
import logging
import os
import threading
from collections.abc import Sequence
from typing import Optional

from PIL import Image, ImageOps

logger = logging.getLogger(__name__)

_tls = threading.local()

# MediaPipe FaceDetection isn't "human-only"; it detects face-like patterns, and
# phone uploads often compress faces. A moderate confidence floor keeps cats out
# while letting typical selfies through.
_MIN_DETECTION_CONFIDENCE = 0.55


def _get_face_detector():
    # Lazily initialize per thread (MediaPipe graph objects are not guaranteed
    # to be thread-safe).
    import mediapipe as mp  # Local import so module import doesn't hard-fail

    if not hasattr(_tls, "face_detector"):
        _tls.face_detector = mp.solutions.face_detection.FaceDetection(
            model_selection=0,
            min_detection_confidence=_MIN_DETECTION_CONFIDENCE,
        )
    return _tls.face_detector


def _detect_with_mediapipe(image_np) -> bool:
    try:
        detector = _get_face_detector()
    except Exception:
        logger.exception("MediaPipe face detector initialization failed")
        return False

    results = detector.process(image_np)
    detections = getattr(results, "detections", None) or []
    if not detections:
        return False

    for det in detections:
        score_raw = getattr(det, "score", None)

        # MediaPipe returns a list of scores per detection; grab the highest.
        try:
            if isinstance(score_raw, Sequence) and not isinstance(score_raw, (str, bytes)):
                score_candidates = [float(s) for s in score_raw if s is not None]
                score_val = max(score_candidates) if score_candidates else 0.0
            else:
                score_val = float(score_raw) if score_raw is not None else 0.0
        except (TypeError, ValueError):
            score_val = 0.0
        if score_val >= _MIN_DETECTION_CONFIDENCE:
            return True

    return False


def _get_haar_classifier():
    try:
        import cv2
    except Exception:
        logger.exception("OpenCV import failed for fallback detection")
        return None, None

    if not hasattr(_tls, "haar_classifier"):
        cascade_root = getattr(cv2.data, "haarcascades", "")
        cascade_path = os.path.join(cascade_root, "haarcascade_frontalface_default.xml")
        classifier = cv2.CascadeClassifier(cascade_path)
        _tls.haar_classifier = classifier

    return getattr(_tls, "haar_classifier", None), cv2


def _detect_with_haar(image_np) -> bool:
    classifier, cv2 = _get_haar_classifier()
    if classifier is None or cv2 is None:
        return False

    if classifier.empty():
        logger.error("OpenCV Haar cascade classifier failed to load")
        return False

    try:
        gray = cv2.cvtColor(image_np, cv2.COLOR_RGB2GRAY)
        faces = classifier.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(80, 80),
        )
        return len(faces) > 0
    except Exception:
        logger.exception("OpenCV fallback face detection failed")
        return False


def verify_image_has_human_face(image_bytes: bytes) -> bool:
    """
    Returns True when MediaPipe detects at least one face.

    This intentionally returns only ACCEPT/REJECT per requirements.
    """
    if not image_bytes:
        return False

    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            img = ImageOps.exif_transpose(img)
            img = img.convert("RGB")

            # Reduce compute for very large images.
            img.thumbnail((640, 640))

            import numpy as np

            image_np = np.ascontiguousarray(np.array(img))
            image_np.flags.writeable = False  # MediaPipe expects immutable input
            if _detect_with_mediapipe(image_np):
                return True

            # Fall back to a classic Haar cascade if MediaPipe fails to find faces.
            if _detect_with_haar(image_np):
                return True

            return False
    except Exception:
        logger.exception("Image verification failed")
        return False

