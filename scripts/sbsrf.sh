@echo off
setlocal
set oldpath=%cd%
cd %AppData%\Rime
cd build
cd %oldpath%
mkdir sbsrf
cd sbsrf
mkdir build
mkdir lua
copy %AppData%\Rime\*.* .
copy %AppData%\Rime\build\*.* .\build
xcopy %AppData%\Rime\lua\*.* .\lua /s
del bihua* zhlf* *.extended.dict.yaml *2.schema.yaml user.yaml sbpy.base.dict.yaml sbpy.ext.dict.yaml sbpy.tencent.dict.yaml
del *.ico weasel* installation.yaml user.yaml
cd build
del bopomofo* cangjie5* luna* stroke* terra* weasel*
cd ..
zip -r sbsrf *.*
move /Y sbsrf.zip ..
cd ..
