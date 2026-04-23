@echo off
REM Quick Start Script for Structura SuperAdmin Dashboard
REM This script helps you get started with the subscription management system

echo ============================================================
echo   Structura SuperAdmin Dashboard - Quick Start
echo ============================================================
echo.

cd /d "%~dp0"

REM Check if we're in the right directory
if not exist "manage.py" (
    echo Error: manage.py not found. Please run this script from the backend\structura_backend directory.
    pause
    exit /b 1
)

echo Step 1: Checking Python installation...
python --version
if errorlevel 1 (
    echo Error: Python not found. Please install Python first.
    pause
    exit /b 1
)
echo.

echo Step 2: Starting Django development server...
echo.
echo The server will start at: http://127.0.0.1:8000/
echo Admin panel available at: http://127.0.0.1:8000/admin/
echo.
echo Press Ctrl+C to stop the server
echo.

REM Force UTF-8 so any stray emoji in print() calls won't crash the
REM dev server on Windows (default cp1252 can't encode e.g. U+1F50D).
set PYTHONIOENCODING=utf-8
set PYTHONUTF8=1

python manage.py runserver

pause
