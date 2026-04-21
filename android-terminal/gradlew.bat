@rem Gradle wrapper launcher (Windows)
@rem ──────────────────────────────────────────────────────────────────────────

@if "%DEBUG%"=="" @echo off
@rem Set local scope for variables
setlocal

set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.
set APP_HOME=%DIRNAME%

set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

if defined JAVA_HOME (
  set JAVACMD=%JAVA_HOME%\bin\java.exe
) else (
  set JAVACMD=java.exe
)

%JAVACMD% %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% ^
  "-Dorg.gradle.appname=%APP_BASE_NAME%" ^
  -classpath "%APP_HOME%\gradle\wrapper\gradle-wrapper.jar" ^
  org.gradle.wrapper.GradleWrapperMain %*

:end
endlocal
