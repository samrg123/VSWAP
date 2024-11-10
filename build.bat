@echo off
setlocal enableextensions enabledelayedexpansion
goto main

:PostBuildCmd
    call:PrintBanner "Post Build Command"
goto:eof

:InitVars
    @REM supported arch is x86 and x64
    set debug=1
    set arch=x64
    set createZip=0
    set buildName=vramfs
    set buildExtension=exe
    set subsystem=console

    set workingDir=%cd%
    set sourceDir=%workingDir%\src
    set resourceDir=%sourceDir%\resources
    set libScanDir=%workingDir%\libraries
    set buildDir=%workingDir%\build
    set buildResourceDir=%buildDir%

    @REM Note: "libs" and "dlls" get populated with .lib and .dll files located in "%libScanDir%\lib\%arch%" 
    @REM        aFiles, cFiles, and cppFiles get auto popultated with .asm, .c, and .cpp files located in "%sourceDir%"
    @REM        resources get auto populated items in "%resourceDir%". You can also specify additional files here 
    set libs=advapi32.lib
    set dlls=
    set resources=
    set aFiles=
    set cFiles=
    set cppFiles=
    set objFiles="%buildDir%\*.obj"

    set buildSuffix=_%arch%
    set vcPath=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build
    
    set aFlags=
    set cFlags=/std:c17
    set cppFlags=/std:c++20 /EHs
    call:SetCommonVCFlags "/c /I%workingDir%\include"

    if %debug% NEQ 0 (
        set aFlags=%aFlags% /Fl
        call:SetCommonVCFlags "/Od /ZI /Zf /MTd /Fa /D DEBUG=1"
        set lFlags=%lFlags% /DEBUG /MAP
        set buildSuffix=%buildSuffix%_debug
    ) else (
        call:SetCommonVCFlags "/O2 /MT"
    )

    set buildFileNoExt=%buildName%%buildSuffix%
    set buildFile=%buildFileNoExt%.%buildExtension%
    set lFlags=%lFlags% /SUBSYSTEM:%subsystem% /out:"%buildFile%" /STACK:5242880

    if "%buildExtension%" == "dll" (
        set lFlags=%lFlags% /DLL /DEF:"%sourceDir%\%buildName%.def"
        @REM set lFlags=%lFlags% /DLL
    )


    @REM --------------

    @REM Grab library include directories and dlls
    for /d %%d in ("%libScanDir%\*") do (

        echo Detected library - generating compiler arguments for: '%%d'
        
        set incFolder=%%d\include
        set libFolder=%%d\lib\%arch%

        call:SetCommonVCFlags /I"!incFolder!"
        set lFlags=!lFlags! /LIBPATH:"!libFolder!"

        for /f "delims=|" %%f in ('dir /b "!libFolder!\*.lib" "!libFolder!\*.a"') do (
            echo "%%f"
            set libs=!libs! "%%f" 
        )

        for /f "delims=|" %%f in ('dir /b "!libFolder!\*.dll"') do (
            set dlls=!dlls! "!libFolder!\%%f" 
        )
    )

    @REM Grab source files
    for %%f in ("%sourceDir%\*.asm") do (        
        set aFiles=!aFiles! "%%f" 
    )

    for %%f in ("%sourceDir%\*.c") do (        
        set cFiles=!cFiles! "%%f" 
    )
        
    for %%f in ("%sourceDir%\*.cpp") do (        
        set cppFiles=!cppFiles! "%%f" 
    )

    @REM Grab resources
    for /f "delims=|" %%i in ('dir /b "%resourceDir%\*"') do (
        set resources=!resources! "%resourceDir%\%%i"
    )

    call:PrintBanner "Initializing Compiler"
    set path="%vcPath%";%path%
    call vcvarsall %arch%

    if "%arch%" == "x86" (
        set assembler=ml
    ) else (
        set assembler=ml64
    )    

goto:eof

:SetCommonCompileFlags
    set aFlags=%aFlags% %~1
    call:SetCommonVCFlags %~1
goto:eof

:SetCommonVCFlags
    set cFlags=%cFlags% %~1
    set cppFlags=%cppFlags% %~1
goto:eof

:Panic
    call:PrintBanner "PANIC INVOKED - MSG: '%~1'"
    exit 1
goto:eof

:PrintBanner
    echo:
    echo --- %~1 ---
    echo:
goto:eof

:PrintVar
    echo using %~1: '!%~1!'
goto:eof

:PrintConfiguration
    call:PrintBanner "Configuration"
    for %%s in (
        debug
        arch
        subsystem
        createZip
        sourceDir
        resourceDir
        resources
        buildDir
        buildFile
        buildResourceDir
        libScanDir
        libs
        dlls
        aFiles
        cFiles
        cppFiles
        objFiles
        aFlags
        cFlags
        cppFlags
        lFlags
        vcPath 
        assembler
    ) do ( call:PrintVar %%s )
goto:eof

:Cleanbuild
    call:PrintBanner "Cleaning Build"
    rmdir /s /q "%buildDir%"
    mkdir "%buildDir%"
goto:eof

:AssembleAsm
    if "%aFiles%" NEQ "" (
        call:PrintBanner "Assembling Files"
        for %%f in (%aFiles%) do (

            %assembler% %aFlags% "%%f"
            if %ERRORLEVEL% NEQ 0 (
                call:Panic "Failed to Compile - '%assembler%' returned '!ERRORLEVEL!'"
            )
        )
    ) else (
        call:PrintBanner "Skipping asm assembly - No asm files found"
    )
goto:eof

:CompileC
    if "%cFiles%" NEQ "" (
        call:PrintBanner "Compiling C Files"

        @REM echo cl %cFlags% %cFiles% 
        @REM exit 


        cl %cFlags% %cFiles% 
        if %ERRORLEVEL% NEQ 0 (
            call:Panic "Failed to Compile C files - 'cl' returned '%ERRORLEVEL%'"
        )
    ) else (
        call:PrintBanner "Skipping C compile - No c files found"
    )
goto:eof

:CompileCpp
    if "%cppFiles%" NEQ "" (
        call:PrintBanner "Compiling C++ Files"
        cl %cppFlags% %cppFiles% 

        if %ERRORLEVEL% NEQ 0 ( 
            call:Panic "Failed to Compile C++ - 'cl' returned '%ERRORLEVEL%'"
        )

    ) else (
        call:PrintBanner "Skipping C++ compile - No cpp files found"
    )
goto:eof

:LinkObjs
    call:PrintBanner "Linking Obj Files"

    link %lFlags% %objFiles% %libs%
    if %ERRORLEVEL% NEQ 0 ( 
        call:Panic "Failed to link - 'link' returned '%ERRORLEVEL%'"
    )
goto:eof

:Build
    pushd "%buildDir%"
    call:AssembleAsm
    call:CompileC
    call:CompileCpp
    call:LinkObjs
    popd
goto:eof

:MakeSoftLink
setlocal
    set src=%~1
    set dst=%~2

    if exist "%src%\*" (
        
        mkdir "%dst%"
        if %ERRORLEVEL% NEQ 0 (
            call:Panic "Failed to create dst dir '%dst%' - 'mkdir' returned '%ERRORLEVEL%'"
        )
        
        for /f "delims=|" %%i in ('dir /b "%src%\*"') do (
            call:MakeSoftLink "%src%\%%i" "%dst%\%%i"
        )

    ) else (
        
        @REM echo "DRY: mklink '%dst%' '%src%'"
        mklink "%dst%" "%src%"
        if %ERRORLEVEL% NEQ 0 (
            call:Panic "Failed to symbolic link file '%src%' to '%dst%' - 'mklink' returned '%ERRORLEVEL%'"
        )        
    )

endlocal
goto:eof

:MakeSoftLinks
setlocal
    set sources=!%~1!
    set dstDir=!%~2!

    for %%i in (%sources%) do ( 
        set dst=%dstDir%\%%~nxi
        call:MakeSoftLink "%%~i" "!dst!"
    )

endlocal
goto:eof

:MakeResourceLinks
    call:PrintBanner "Linking resource files to buildDir"
    call:MakeSoftLinks resources "%buildResourceDir%"

    call:PrintBanner "Linking dlls to buildDir"
    call:MakeSoftLinks dlls "%buildDir%"
    
goto:eof

:ZipBuild
    call:PrintBanner "Creating zip"
    tar -acvf "%buildDir%\%buildFileNoExt%.zip" -C "%buildDir%" "%buildFile%" %dlls% -C "%buildResourceDir%" %resources%
goto:eof

:main
    call:InitVars
    call:PrintConfiguration

    @REM TODO: allow for incremental linking!
    @REM call:Cleanbuild
    call:Build

    @REM TODO: make this faster / use links or project FS
    call:MakeResourceLinks

    if %createZip% NEQ 0 (
        call:ZipBuild
    )

    call:PostBuildCmd

    call:PrintBanner "Build Success! "
    exit 0