@echo off

set arch=x86
if defined programfiles(x86) (set arch=x86_64)

cd "%0\..\%arch%"
cctk.exe --version

