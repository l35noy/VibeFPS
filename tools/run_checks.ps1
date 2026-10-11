#Requires -Version 5.1
<#
.SYNOPSIS
    Единая точка входа для каждой headless-проверки в VibeFPS.

.DESCRIPTION
    Запускает каждую проверку из tests\ в отдельном процессе Godot:

        godot --headless --path . --script res://tests/<name>.gd

    Проверка — это автономный скрипт SceneTree, который завершается quit(0) при
    успехе и quit(1) при неудаче. Порядок $Tests имеет значение: "smoke" защищает
    целостность сцен и поэтому запускается перед каждой другой проверкой.

    Имя из $Tests, файл которого ещё не существует, сообщается как
    [SKIP], никогда как успех и никогда как ошибка. Именно это позволяет списку
    быть объявленным заранее и расширяться этап за этапом.

    Каждая проверка запускается с таймаутом wall-clock ($CheckTimeoutMs, 120 секунд
    по умолчанию). Проверка, превышающая его, убивается и сообщается как FAIL, чтобы
    зависшая проверка не блокировала запуск навсегда.

.PARAMETER Filter
    Необязательная подстрока имени теста, сопоставляемая без учёта регистра.
    Опустите её (или передайте пустую строку), чтобы запустить все перечисленные
    проверки.

.EXAMPLE
    .\tools\run_checks.ps1
    Запускает все проверки и выводит итоговую сводную строку.

.EXAMPLE
    .\tools\run_checks.ps1 smok
    Запускает только те проверки, имя которых содержит "smok".

.NOTES
    Код выхода 0 = все выполненные проверки пройдены. Код выхода 1 = хотя бы одна
    проверка провалена, превысила таймаут, или движок Godot не найден.
#>

$ErrorActionPreference = 'Stop'

# Godot 4.7.2 stable. Это единственный поддерживаемый движок для проекта; не
# добавляйте сюда второй путь, контракт тестов (коды выхода, маркеры [FAIL] на
# stdout, флаг --headless) привязан к этой сборке.
$GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"

# Упорядоченный список имён проверок без расширения .gd.
$Tests = @("smoke", "movement", "input_actions", "input_gate", "weapon_data", "integrity",
           "weapon", "auto_weapon", "projectile", "enemies", "waves", "save", "progression",
           "interact", "ui", "inventory")

# tests\capture.gd требует реального рендерера, а tests\diagnose.gd запускается
# вручную, поэтому ни один из них не принадлежит сюда.

$Filter = ''
if ($args.Count -gt 0 -and $null -ne $args[0]) {
    $Filter = [string]$args[0]
}

# --path . Godot разрешается относительно рабочего каталога процесса, а
# проверка существования теста разрешается относительно репозитория, поэтому
# закрепляем оба каталога за корнем репозитория, независимо от того, откуда
# был запущен скрипт.
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Бюджет времени (wall-clock) на каждую проверку. Реальный дымовой тест «smoke»
# из 31 проверки занимает ~17 секунд на этом оборудовании, поэтому 120 секунд
# оставляют ~7× запас для более тяжёлых проверок, добавляемых в последующих
# фазах (зависание не должно сообщаться как медленный успех). Проверка,
# превышающая этот срок, убивается и сообщается как FAIL, а не блокирует
# запуск навсегда.
$CheckTimeoutMs = 120000

# Уникален для каждого запуска И каждого процесса. $PID сам по себе всё равно
# столкнулся бы с коллизией, если два запуска были запущены из одного и того же
# родительского процесса, и коллизия позволила бы одному запуску прочитать
# вывод другого и сообщить PASS чужой проверке.
$runTag = '{0}-{1}' -f $PID, ([guid]::NewGuid().ToString('N').Substring(0, 8))
$stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) "vibefps_check_out_$runTag.txt"
$stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) "vibefps_check_err_$runTag.txt"

Push-Location -LiteralPath $RepoRoot
try {
    # Явно завершиться с ошибкой и ничего не запускать, если движок отсутствует,
    # а не сообщать о провале каждой проверки по причине, не имеющей отношения к
    # тестируемому коду.
    if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
        Write-Output "Движок Godot не найден: $GodotBin"
        Write-Output "РЕЗУЛЬТАТ: 0 пройдено, 0 провалено, 0 пропущено"
        exit 1
    }

    # Глобальные объявления class_name (scripts\input_gate.gd объявляет InputGate)
    # видны парсеру только через .godot\global_script_class_cache.cfg,
    # и этот файл игнорируется Git. В чистом клоне он не существует, поэтому каждый
    # скрипт, ссылающийся на class_name, не может быть разобран с ошибкой
    # "Identifier ... not declared in the current scope".
    #
    # Кеш также устаревает без исчезновения — именно это случается чаще
    # всего: добавление class_name оставляет существующий кеш, который просто не
    # содержит его, и скрипт, ссылающийся на него, погибает при разборе с ошибкой
    # "Could not find type ... in the current scope". Это читается как
    # собственный сбой этого скрипта, и скрипт не может объяснить причину — проверка,
    # погибшая до первого утверждения, не может сообщить о своей неудаче. Поэтому
    # кеш считается устаревшим, когда он отсутствует ИЛИ когда любой источник
    # новее его.
    #
    # Один проход импорта перестраивает кеш и стоит около двух секунд, поэтому он
    # запускается только тогда, когда выполнено одно из двух условий выше, а не при
    # каждом вызове. Расположен после проверки наличия движка выше, чтобы отсутствие
    # Godot всё равно завершалось быстрой ошибкой со своим собственным сообщением, а
    # не вызывалось здесь.
    $classCache = Join-Path $RepoRoot '.godot\global_script_class_cache.cfg'
    $cacheFile = Get-Item -LiteralPath $classCache -ErrorAction SilentlyContinue

    # Сканирование — единственные затраты этой проверки, поэтому оно состоит из
    # одного прохода, и .godot исключается из списка, а не спускается в него и
    # затем фильтруется: в нём хранятся импортированные движком бинарники, он
    # является большинством дерева по количеству файлов и никогда не может
    # содержать class_name. -Include не может выразить это — с -LiteralPath он
    # вообще не фильтрует (возвращает каждый файл в репозитории, включая
    # project.godot), что с одной стороны построило бы FileInfo для всего дерева, с
    # другой — посчитало бы правку любого файла основанием для повторного импорта.
    # Поэтому проверка расширения явна.
    $sourceRoots = @(Get-ChildItem -LiteralPath $RepoRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '.godot' } |
        Select-Object -ExpandProperty FullName)
    $newestSource = $null
    # Пустой массив -LiteralPath — это критическая ошибка привязки параметров, и
    # $ErrorActionPreference равен Stop: это привело бы к аварийному завершению
    # всего запуска со стековой трассой PowerShell и без итоговой строки. Недостижимо,
    # пока существует project.godot, но этот скрипт — единая точка входа для всех
    # проверок.
    if ($sourceRoots.Count -gt 0) {
        # LastWriteTimeUtc, а не LastWriteTime: кеш пишется движком, и обе
        # стороны сравнения пересекаются через границу перехода на летнее время, на
        # локальных временных метках стеновых часов это не выдерживается.
        $newestSource = Get-ChildItem -LiteralPath $sourceRoots -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.gd', '.tscn', '.tres' } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
    }
    $needsImport = $null -eq $cacheFile -or
        ($null -ne $newestSource -and $newestSource.LastWriteTimeUtc -gt $cacheFile.LastWriteTimeUtc)
    if ($needsImport) {
        Write-Output "импорт проекта (кеш классов отсутствует или устарел) ..."
        & $GodotBin --headless --path . --import | Out-Null
    }

    $pass = 0
    $fail = 0
    $skip = 0

    foreach ($name in $Tests) {
        if ($Filter -ne '' -and $name.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            continue
        }

        $scriptPath = Join-Path $RepoRoot ("tests\{0}.gd" -f $name)
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            Write-Output ("{0,-14} [SKIP]  (tests\{1}.gd отсутствует)" -f $name, $name)
            $skip++
            continue
        }

        foreach ($tmp in @($stdoutPath, $stderrPath)) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }

        # Флаг --headless выводит диагностику движка на stderr, тогда как вывод
        # самой проверки (print()), включая строки [FAIL], идёт на stdout. Оба
        # потока перехватываются в файлы и затем перечитываются: реализация 2>&1 в
        # PowerShell 5.1 ненадёжна для родных процессов, и проверка, чей вывод [FAIL]
        # не достиг консоли, не может быть отлажена.
        #
        # Запуск без -Wait и ограничение через WaitForExit вместо него: -Wait
        # бесконечно блокирует, а проверка, бросившая исключение до quit(), оставит
        # Godot работающим бесконечно. Это означало бы отсутствие итоговой строки,
        # кода выхода и зависшую сессию того, кто управляет этим скриптом.
        $proc = Start-Process -FilePath $GodotBin `
            -ArgumentList '--headless', '--path', '.', '--script', "res://tests/$name.gd" `
            -WorkingDirectory $RepoRoot `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        # Кэшировать дескриптор процесса ДО его завершения. Start-Process -PassThru
        # без -Wait возвращает объект Process, чей ExitCode читается как $null после
        # завершения процесса, потому что дескриптор не удерживался; обращение к .Handle
        # здесь закрепляет его. Без этого `$code -eq 0` оказывается $false для каждой
        # проверки, и ветка PASS недостижима — запуск сообщает о зелёной проверке как
        # FAIL. Присваивание $null = обязательно: .Handle возвращает IntPtr, который
        # иначе попал бы в вывод запуска.
        $null = $proc.Handle

        $timedOut = -not $proc.WaitForExit($CheckTimeoutMs)
        if ($timedOut) {
            # Убить только эту проверку, чтобы остальные всё равно запустились;
            # одна зависшая проверка не должна прерывать всю suite.
            try {
                $proc.Kill()
                # Дать ОС завершить процесс и сбросить перехваченные дескрипторы перед
                # чтением файлов ниже. Намеренно ограничено: Kill() возвращает void
                # под .NET Framework, поэтому kill, который не смог бы завершить
                # процесс, привёл бы к долгому бесконечному ожиданию — именно это
                # $CheckTimeoutMs существует для предотвращения. Результат
                # отбрасывается, потому что ограниченная перегрузка возвращает bool,
                # который иначе попал бы на stdout запуска.
                $null = $proc.WaitForExit(5000)
            } catch {
                # Уже завершился между таймаутом и убийством; нечего делать.
            }
        } else {
            # Ограниченный WaitForExit(ms) выше возвращается, как только процесс
            # завершается, но не дожидается EOF перехваченных потоков, поэтому файлы
            # ниже могли бы зависеть от того, что Start-Process уже сбросил их.
            # Эта перегрузка без параметров ждёт EOF, делая захваченный вывод
            # детерминированным, а не случайно завершённым.
            $proc.WaitForExit()
        }

        $output = ''
        if (Test-Path -LiteralPath $stdoutPath) {
            $output += [System.IO.File]::ReadAllText($stdoutPath)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $output += [System.IO.File]::ReadAllText($stderrPath)
        }

        # Код выхода — первичный контракт, но проверка, сообщившая о провале
        # утверждения и забывшая quit(1), не должна читаться как успех. Это может
        # только перевести PASS в FAIL, никогда — обратное. Флаг (?m) важен: без него
        # ^ привязывается к началу всего захваченного вывода, а не к началу каждой
        # строки, и проверка тихо проходила бы как успех, если бы баннер движка
        # предшествовал ошибке.
        $reportedFailure = $output -match '(?m)^\s*\[FAIL\]'
        $code = $proc.ExitCode

        # Проверка, превысившая таймаут, всегда FAIL, независимо от того, что говорят
        # её код выхода или вывод: она не достигла вердикта, поэтому нечего и проходить.
        if ($code -eq 0 -and -not $reportedFailure -and -not $timedOut) {
            Write-Output ("{0,-14} PASS" -f $name)
            $pass++
        } else {
            if ($timedOut) {
                $reason = "превышен таймаут ($($CheckTimeoutMs / 1000) с)"
            } elseif ($code -ne 0) {
                $reason = "код выхода $code"
            } else {
                $reason = '[FAIL] маркер в выводе, но код выхода 0'
            }
            Write-Output ("{0,-14} FAIL  ({1})" -f $name, $reason)
            foreach ($line in ($output -split "`r?`n")) {
                if ($line -ne '') { Write-Output "    $line" }
            }
            $fail++
        }
    }

    Write-Output ''
    Write-Output ("РЕЗУЛЬТАТ: {0} пройдено, {1} провалено, {2} пропущено" -f $pass, $fail, $skip)

    if ($fail -gt 0) { exit 1 } else { exit 0 }
}
finally {
    Pop-Location
    foreach ($tmp in @($stdoutPath, $stderrPath)) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}
