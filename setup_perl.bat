echo off
echo This batch file will install the necessary Perl modules for use with 
echo Personal ReplayGuide.    
echo .
echo This utility has absolutely no warranty of any kind and has only been
echo tested with ActivePerl on Windows.   Have fun :)
echo .
pause
echo You are brave!   If you see messages about the modules already being
echo installed, don't worry.
echo .
echo If you're still sure you want to run this batch file,
pause
echo Installing.
ppm install cgi
ppm install time-local
ppm install dbi
ppm install dbd-odbc
ppm install dbd-mysql
ppm install dbd-sqlite
ppm install soap-lite
echo Done!




