@echo off
where Rscript >nul 2>&1
if not errorlevel 1 goto run
echo Rscript was not found on PATH.
echo Open the R project in RStudio and run source("run_update.R").
pause
exit /b 1
:run
Rscript --vanilla run_update.R
pause
