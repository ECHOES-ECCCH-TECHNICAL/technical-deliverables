@echo off
setlocal

REM ------------------------------------------------------------
REM DOCX -> Markdown for MkDocs using Pandoc
REM
REM Usage:
REM   1) Drag a .docx file onto this .bat
REM   or
REM   2) Run:
REM        docx-to-markdown.bat "C:\path\to\file.docx"
REM
REM Requirements:
REM   - pandoc.exe available in PATH
REM   - clean-images.lua in the same folder as this .bat
REM ------------------------------------------------------------

if "%~1"=="" (
    echo.
    echo Usage:
    echo   Drag a .docx file onto this BAT
    echo   or run:
    echo   %~nx0 "C:\path\to\file.docx"
    echo.
    pause
    exit /b 1
)

where pandoc >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: Pandoc was not found in PATH.
    echo Install Pandoc or add pandoc.exe to PATH.
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0clean-docx_v02.lua" (
    echo.
    echo ERROR: clean-docx_v02.lua was not found.
    echo Expected location:
    echo   %~dp0clean-docx_v02.lua
    echo.
    pause
    exit /b 1
)

if /I not "%~x1"==".docx" (
    echo.
    echo ERROR: The input file must be a .docx file.
    echo Input:
    echo   %~1
    echo.
    pause
    exit /b 1
)

if not exist "%~1" (
    echo.
    echo ERROR: Input file not found:
    echo   %~1
    echo.
    pause
    exit /b 1
)

REM Work in the DOCX folder so media/ is created next to the Markdown file.
pushd "%~dp1"

echo.
echo Converting:
echo   %~nx1
echo.
echo Output:
echo   output.md
echo.
echo Media:
echo   %~dp1media\
echo.

pandoc "%~nx1" ^
  -t gfm ^
  --extract-media=. ^
  --wrap=none ^
  --lua-filter="%~dp0clean-docx_v02.lua" ^
  -o "output.md"

set "PANDOC_EXIT=%ERRORLEVEL%"

popd

if not "%PANDOC_EXIT%"=="0" (
    echo.
    echo ERROR: Pandoc failed with exit code %PANDOC_EXIT%.
    echo.
    pause
    exit /b %PANDOC_EXIT%
)

echo.
echo Conversion completed successfully.
echo Markdown:
echo   output.md
echo.

endlocal
