# perfilar_final.ps1 - Script CORREGIDO para Windows 11
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   CAPTURA DE PERFIL CPU PARA GO PPROF   " -ForegroundColor Cyan
Write-Host "        (Windows 11 - PowerShell)        " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Configuración
$perfilNombre = "cpu_perfil_final.pprof"
$duracionPerfil = 15  # segundos
$rutaProyecto = Get-Location

Write-Host "Ruta del proyecto: $rutaProyecto" -ForegroundColor Yellow

# 1. MATAR procesos previos en puerto 8081
Write-Host "`n1. Limpiando puerto 8081..." -ForegroundColor Yellow
try {
    $procesos = Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue
    if ($procesos) {
        foreach ($proc in $procesos) {
            $processId = $proc.OwningProcess
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
            Write-Host "   Proceso $processId terminado" -ForegroundColor Red
        }
        Start-Sleep -Seconds 2
    }
}
catch {
    Write-Host "   (No se pudieron limpiar procesos, continuando...)" -ForegroundColor Gray
}

# 2. INICIAR servidor en proceso SEPARADO
Write-Host "`n2. Iniciando servidor Go..." -ForegroundColor Yellow
$serverProcess = Start-Process -FilePath "go" -ArgumentList "run ./cmd/api" -PassThru -WindowStyle Hidden
$serverId = $serverProcess.Id
Write-Host "   Servidor PID: $serverId" -ForegroundColor Green

# Esperar a que inicie
Write-Host "   Esperando 5 segundos para inicio..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# 3. VERIFICAR que el servidor responde
Write-Host "`n3. Verificando servidor..." -ForegroundColor Yellow
try {
    $testResponse = Invoke-WebRequest -Uri "http://localhost:8081/debug/pprof/" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "   Servidor respondiendo (Status: $($testResponse.StatusCode))" -ForegroundColor Green
}
catch {
    Write-Host "   Servidor NO responde: $($_.Exception.Message)" -ForegroundColor Red
    Stop-Process -Id $serverId -Force -ErrorAction SilentlyContinue
    exit 1
}

# 4. INICIAR captura de perfil
Write-Host "`n4. Iniciando captura de perfil ($duracionPerfil segundos)..." -ForegroundColor Yellow
Write-Host "   Ejecutando: curl -o $perfilNombre `"http://localhost:8081/debug/pprof/profile?seconds=$duracionPerfil`"" -ForegroundColor Gray

# Ejecutar curl en background
$perfilJob = Start-Job -ScriptBlock {
    param($nombre, $duracion, $ruta)
    Set-Location $ruta
    $urlPerfil = "http://localhost:8081/debug/pprof/profile?seconds=$duracion"
    curl -o $nombre $urlPerfil
    if (Test-Path $nombre) {
        return (Get-Item $nombre).Length
    }
    else {
        return 0
    }
} -ArgumentList $perfilNombre, $duracionPerfil, $rutaProyecto.Path

# 5. ESPERAR 2 segundos y generar CARGA
Write-Host "   Esperando 2 segundos antes de generar carga..." -ForegroundColor Gray
Start-Sleep -Seconds 2

Write-Host "`n5. Generando CARGA en el servidor..." -ForegroundColor Yellow

# Generar carga en PRIMER PLANO (más confiable)
$contadorCarga = 0
$startTime = Get-Date

while (((Get-Date) - $startTime).TotalSeconds -lt ($duracionPerfil + 2)) {
    $contadorCarga++
    Write-Host "   Request #$contadorCarga" -ForegroundColor DarkGray
    
    try {
        $response = curl http://localhost:8081/work
        Write-Host "     OK: $($response[0])" -ForegroundColor DarkGreen
    }
    catch {
        Write-Host "     Error" -ForegroundColor DarkRed
    }
    
    # Pequeña pausa
    Start-Sleep -Milliseconds 300
}

Write-Host "   Carga completada: $contadorCarga requests" -ForegroundColor Green

# 6. ESPERAR a que termine la captura
Write-Host "`n6. Esperando que termine la captura..." -ForegroundColor Yellow
Wait-Job $perfilJob -Timeout ($duracionPerfil + 5) | Out-Null

# 7. OBTENER resultados
$tamanoPerfil = Receive-Job $perfilJob
Remove-Job $perfilJob -Force

# 8. TERMINAR servidor
Write-Host "`n7. Terminando servidor..." -ForegroundColor Yellow
try {
    Stop-Process -Id $serverId -Force -ErrorAction Stop
    Write-Host "   Servidor terminado" -ForegroundColor Green
}
catch {
    Write-Host "   (Servidor ya terminado)" -ForegroundColor Gray
}

# 9. VERIFICAR archivo
Write-Host "`n8. Verificando archivo de perfil..." -ForegroundColor Green
if (Test-Path $perfilNombre) {
    $archivo = Get-Item $perfilNombre
    Write-Host "   ARCHIVO CREADO: $($archivo.Name)" -ForegroundColor Green
    Write-Host "   Tamaño: $($archivo.Length) bytes" -ForegroundColor White
    
    if ($archivo.Length -gt 10000) {
        Write-Host "    PERFIL EXCELENTE (>10KB)" -ForegroundColor Green
    }
    elseif ($archivo.Length -gt 1000) {
        Write-Host "     PERFIL ACEPTABLE (>1KB)" -ForegroundColor Yellow
    }
    elseif ($archivo.Length -gt 0) {
        Write-Host "    PERFIL DEMASIADO PEQUEÑO" -ForegroundColor Red
    }
    else {
        Write-Host "    PERFIL VACÍO" -ForegroundColor Red
    }
}
else {
    Write-Host "    ERROR: No se creó el archivo" -ForegroundColor Red
}

# 10. ANÁLISIS INMEDIATO
Write-Host "`n9. Análisis rápido del perfil..." -ForegroundColor Cyan
if (Test-Path $perfilNombre -and (Get-Item $perfilNombre).Length -gt 1000) {
    Write-Host "   Ejecutando análisis básico..." -ForegroundColor Gray
    
    # Análisis 1: Top functions
    Write-Host "`n   === TOP FUNCTIONS ===" -ForegroundColor White
    $topResult = go tool pprof -top $perfilNombre 2>&1
    $topLines = $topResult | Select-String -Pattern "flat|cum|Function|Total|fib|Fib" -CaseSensitive:$false | Select-Object -First 15
    
    if ($topLines) {
        foreach ($line in $topLines) {
            Write-Host "   $($line.Line)" -ForegroundColor Gray
        }
    }
    
    # Análisis 2: Texto completo
    Write-Host "`n   === ANÁLISIS COMPLETO (primeras líneas) ===" -ForegroundColor White
    $textResult = go tool pprof -text $perfilNombre 2>&1 | Select-Object -First 20
    foreach ($line in $textResult) {
        Write-Host "   $line" -ForegroundColor DarkGray
    }
}
else {
    Write-Host "   Perfil muy pequeño o inexistente para análisis" -ForegroundColor Red
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "             PROCESO COMPLETADO            " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "`nPRÓXIMOS PASOS:" -ForegroundColor Yellow
Write-Host "1. Ver perfil en navegador:" -ForegroundColor White
Write-Host "   go tool pprof -http=:9999 $perfilNombre" -ForegroundColor White
Write-Host "2. O usar consola interactiva:" -ForegroundColor White
Write-Host "   go tool pprof $perfilNombre" -ForegroundColor White
Write-Host "   Luego dentro de pprof:" -ForegroundColor White
Write-Host "   > top     # Ver funciones principales" -ForegroundColor White
Write-Host "   > list fib # Ver detalles de fib" -ForegroundColor White
Write-Host "   > quit    # Salir" -ForegroundColor White