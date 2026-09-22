@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ------------------------------------------------------------
REM Convert all DOCX files located in:
REM   ..\deliverables\D*
REM
REM Expected structure:
REM
REM   project\
REM     scripts\
REM       convert-all-D-folders.bat
REM       docx-to-markdown.bat
REM       clean-docx.lua
REM     deliverables\
REM       D1.1\
REM         file.docx
REM       D1.2\
REM         file.docx
REM       ...
REM
REM This BAT can be executed from any current directory.
REM ------------------------------------------------------------

set "SCRIPT_DIR=%~dp0"
set "CONVERTER=%SCRIPT_DIR%docx-to-md.bat"
set "DELIVERABLES_DIR=%SCRIPT_DIR%..\deliverables"

if not exist "%CONVERTER%" (
    echo ERROR: Converter not found:
    echo   %CONVERTER%
    exit /b 1
)

if not exist "%DELIVERABLES_DIR%\" (
    echo ERROR: Deliverables directory not found:
    echo   %DELIVERABLES_DIR%
    exit /b 1
)

set /a TOTAL=0
set /a OK=0
set /a SKIPPED=0
set /a FAILED=0

pushd "%DELIVERABLES_DIR%"

for /d %%D in (D*) do (
    set /a TOTAL+=1
    set "DOCX="
    set /a COUNT=0

    for %%F in ("%%D\*.docx") do (
        if exist "%%~fF" (
            set /a COUNT+=1
            set "DOCX=%%~fF"
        )
    )

    if !COUNT! EQU 0 (
        echo [SKIP] %%D - no DOCX file found
        set /a SKIPPED+=1
    ) else if !COUNT! GTR 1 (
        echo [SKIP] %%D - more than one DOCX file found
        set /a SKIPPED+=1
    ) else (
        echo.
        echo ============================================================
        echo Converting %%D
        echo   !DOCX!
        echo ============================================================

        call "%CONVERTER%" "!DOCX!"

        if errorlevel 1 (
            echo [ERROR] %%D - conversion failed
            set /a FAILED+=1
        ) else (
            echo [OK] %%D
            set /a OK+=1
        )
    )
)

popd

echo.
echo ============================================================
echo Finished
echo   Folders found : %TOTAL%
echo   Converted     : %OK%
echo   Skipped       : %SKIPPED%
echo   Failed        : %FAILED%
echo ============================================================

if %FAILED% GTR 0 exit /b 1
exit /b 0
