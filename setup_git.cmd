@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

title Первичная настройка Git и привязка к GitHub

echo ========================================================
echo       ПЕРВИЧНАЯ НАСТРОЙКА GIT И ПРИВЯЗКА К АККАУНТУ
echo ========================================================
echo.

:: ==========================================================
:: 1. ПРОВЕРКА НАЛИЧИЯ И УСТАНОВКА GIT
:: ==========================================================
echo [1/4] Проверка наличия Git...

where git >nul 2>&1
if %ERRORLEVEL% equ 0 goto git_found

if exist "%ProgramFiles%\Git\cmd\git.exe" goto add_path_pf
if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" goto add_path_pfx86
if exist "%LocalAppData%\Programs\Git\cmd\git.exe" goto add_path_local

echo [!] Git не обнаружен в системе. Начинаем автоматическую установку...

where winget >nul 2>&1
if %ERRORLEVEL% neq 0 goto download_git_curl

echo [Установка] Установка Git через Windows Package Manager (winget)...
winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
if %ERRORLEVEL% equ 0 goto refresh_path

echo [Предупреждение] Установка через winget не удалась. Скачиваем официальный установщик...

:download_git_curl
echo [Установка] Скачивание официального установщика Git for Windows...
set "GIT_INSTALLER=%TEMP%\Git-64-bit-installer.exe"
curl.exe -L -f -o "!GIT_INSTALLER!" "https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe"
if %ERRORLEVEL% neq 0 goto download_failed

echo [Установка] Запуск тихой установки Git в фоновом режиме...
"!GIT_INSTALLER!" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
set "INSTALL_STATUS=%ERRORLEVEL%"
if exist "!GIT_INSTALLER!" del /f /q "!GIT_INSTALLER!"

if %INSTALL_STATUS% neq 0 goto install_failed
goto refresh_path

:download_failed
echo [ОШИБКА] Не удалось скачать Git. Проверьте интернет-соединение.
pause
exit /b 1

:install_failed
echo [ОШИБКА] Установка завершилась с ошибкой: %INSTALL_STATUS%
pause
exit /b 1

:add_path_pf
set "PATH=%ProgramFiles%\Git\cmd;!PATH!"
goto git_found

:add_path_pfx86
set "PATH=%ProgramFiles(x86)%\Git\cmd;!PATH!"
goto git_found

:add_path_local
set "PATH=%LocalAppData%\Programs\Git\cmd;!PATH!"
goto git_found

:refresh_path
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;!PATH!"
if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" set "PATH=%ProgramFiles(x86)%\Git\cmd;!PATH!"
if exist "%LocalAppData%\Programs\Git\cmd\git.exe" set "PATH=%LocalAppData%\Programs\Git\cmd;!PATH!"

where git >nul 2>&1
if %ERRORLEVEL% equ 0 goto git_found

echo [Внимание] Git установлен. Пожалуйста, перезапустите этот скрипт.
pause
exit /b 0

:git_found
for /f "tokens=*" %%v in ('git --version 2^>nul') do set "GIT_VERSION=%%v"
echo [OK] !GIT_VERSION! готов к работе.
echo.

:: ==========================================================
:: 2. НАСТРОЙКА ИМЕНИ И EMAIL ПОЛЬЗОВАТЕЛЯ
:: ==========================================================
echo [2/4] Настройка имени и email (для подписи коммитов)...
echo.

set "CURR_NAME="
set "CURR_EMAIL="
for /f "tokens=*" %%a in ('git config --global user.name 2^>nul') do set "CURR_NAME=%%a"
for /f "tokens=*" %%a in ('git config --global user.email 2^>nul') do set "CURR_EMAIL=%%a"

:ask_name
if defined CURR_NAME goto has_name

set "USER_NAME="
set /p "USER_NAME=Введите ваше имя и фамилию (например, Ivan Ivanov): "
if not defined USER_NAME goto ask_name_retry
goto ask_email

:ask_name_retry
echo [!] Имя не может быть пустым.
goto ask_name

:has_name
echo Текущее имя: !CURR_NAME!
set "USER_NAME="
set /p "USER_NAME=Введите новое имя (или нажмите Enter, чтобы оставить [!CURR_NAME!]): "
if not defined USER_NAME set "USER_NAME=!CURR_NAME!"

:ask_email
if defined CURR_EMAIL goto has_email

set "USER_EMAIL="
set /p "USER_EMAIL=Введите ваш email (например, user@example.com): "
if not defined USER_EMAIL goto ask_email_retry
goto save_identity

:ask_email_retry
echo [!] Email не может быть пустым.
goto ask_email

:has_email
echo Текущий email: !CURR_EMAIL!
set "USER_EMAIL="
set /p "USER_EMAIL=Введите новый email (или нажмите Enter, чтобы оставить [!CURR_EMAIL!]): "
if not defined USER_EMAIL set "USER_EMAIL=!CURR_EMAIL!"

:save_identity
echo.
echo Сохранение настроек пользователя...
git config --global user.name "!USER_NAME!"
git config --global user.email "!USER_EMAIL!"

:: ==========================================================
:: 3. БАЗОВЫЕ НАСТРОЙКИ GIT
:: ==========================================================
echo.
echo [3/4] Применение базовых настроек Git...

git config --global init.defaultBranch main
git config --global core.autocrlf true
git config --global core.quotepath false
git config --global credential.helper manager
git config --global pull.rebase false

echo [OK] Базовые параметры применены:
echo   - Главная ветка: main
echo   - Переводы строк Windows: core.autocrlf = true
echo   - Поддержка кириллицы в путях: core.quotepath = false
echo   - Диспетчер паролей Windows: credential.helper = manager
echo   - Безопасное слияние: pull.rebase = false
echo.

:: ==========================================================
:: 4. АВТОРИЗАЦИЯ В GITHUB (ТОКЕН ДОСТУПА ЧЕРЕЗ БРАУЗЕР)
:: ==========================================================
echo [4/4] Настройка авторизации GitHub...
echo.

:: Проверка наличия GitHub CLI
where gh >nul 2>&1
if %ERRORLEVEL% equ 0 goto check_gh_status

where winget >nul 2>&1
if %ERRORLEVEL% neq 0 goto token_browser_setup

echo [Установка] Установка утилиты GitHub CLI через winget...
winget install --id GitHub.cli -e --source winget --accept-source-agreements --accept-package-agreements
if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "PATH=%ProgramFiles%\GitHub CLI;!PATH!"
if exist "%LocalAppData%\Programs\GitHub CLI\gh.exe" set "PATH=%LocalAppData%\Programs\GitHub CLI;!PATH!"

:check_gh_status
where gh >nul 2>&1
if %ERRORLEVEL% neq 0 goto token_browser_setup

gh auth status >nul 2>&1
if %ERRORLEVEL% neq 0 goto token_browser_setup

set "GH_USER="
for /f "tokens=*" %%u in ('gh api user --jq .login 2^>nul') do set "GH_USER=%%u"
if not defined GH_USER set "GH_USER=подключен"

echo [OK] Вы уже авторизованы в GitHub: !GH_USER!
set "REAUTH=N"
set /p "REAUTH=Хотите привязать новый токен доступа или сменить аккаунт? [Y/N, по умолчанию N]: "
if /i "!REAUTH!"=="Y" goto token_browser_setup
if /i "!REAUTH!"=="YES" goto token_browser_setup
if /i "!REAUTH!"=="Д" goto token_browser_setup
if /i "!REAUTH!"=="ДА" goto token_browser_setup
gh auth setup-git
goto finish_step

:token_browser_setup
echo.
echo ========================================================
echo       СОЗДАНИЕ КЛАССИЧЕСКОГО ТОКЕНА GITHUB (PAT)
echo ========================================================
echo Сейчас в браузере откроется страница генерации токена.
echo.
echo В открывшемся окне браузера:
echo 1. В поле "Note" укажите название (например: MyPC).
echo 2. В разделе "Select scopes" убедитесь, что стоит галочка "repo".
echo 3. Прокрутите страницу вниз и нажмите зеленую кнопку "Generate token".
echo 4. Скопируйте появившийся токен (начинается с ghp_...).
echo ========================================================
echo.
echo Нажмите любую клавишу, чтобы открыть браузер...
pause >nul

start https://github.com/settings/tokens/new?description=WindowsGit^&scopes=repo,workflow

echo.
:prompt_token_input
set "GIT_TOKEN="
set /p "GIT_TOKEN=Вставьте скопированный токен (ghp_...): "
if not defined GIT_TOKEN (
    echo [!] Токен не может быть пустым. Попробуйте снова.
    goto prompt_token_input
)

:: Сохранение токена в Git Credential Manager Windows
(
echo protocol=https
echo host=github.com
echo username=!USER_NAME!
echo password=!GIT_TOKEN!
) | git credential approve

:: Привязка к GitHub CLI (если установлен)
where gh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo !GIT_TOKEN! | gh auth login --with-token >nul 2>&1
    gh auth setup-git >nul 2>&1
)

echo.
echo [OK] Токен успешно сохранен в диспетчере учетных данных Windows!
echo Теперь отправка кода (git push) будет работать без запроса пароля.

:: ==========================================================
:: ФИНАЛ: ИНСТРУКЦИЯ ПО ПРИВЯЗКЕ РЕПОЗИТОРИЕВ
:: ==========================================================
:finish_step
echo.
echo ========================================================
echo               ИТОГОВАЯ КОНФИГУРАЦИЯ GIT
echo ========================================================
git config --global --list
echo.
echo ========================================================
echo     КАК ИНИЦИАЛИЗИРОВАТЬ И ПРИВЯЗАТЬ РЕПОЗИТОРИЙ:
echo ========================================================
echo.
echo ВАРИАНТ 1 (Через сайт GitHub):
echo   1. Откройте в браузере https://github.com/new
echo   2. Введите имя репозитория и нажмите "Create repository".
echo   3. В папке вашего проекта в терминале выполните:
echo        git init
echo        git add .
echo        git commit -m "Первый коммит"
echo        git branch -M main
echo        git remote add origin https://github.com/ВАШ_ЛОГИН/ИМЯ_РЕПОЗИТОРИЯ.git
echo        git push -u origin main
echo.
echo ВАРИАНТ 2 (В 1 команду через GitHub CLI):
echo   В папке проекта выполните:
echo        git init
echo        git add .
echo        git commit -m "Первый коммит"
echo        gh repo create имя-проекта --public --source=. --remote=origin --push
echo.
echo ========================================================
echo [ГОТОВО] Первичная настройка компьютера завершена!
echo ========================================================
echo.
pause
