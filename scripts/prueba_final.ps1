# prueba_final.ps1
Write-Host "=== PRUEBA FINAL DE RENDIMIENTO ===" -ForegroundColor Cyan

# 1. Iniciar servidor
Write-Host "1. Iniciando servidor..." -ForegroundColor Yellow
$server = Start-Process -FilePath "go" -ArgumentList "run", "./cmd/api" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3

# 2. Probar versión lenta (pocos requests)
Write-Host "2. Probando versión LENTA (3 requests)..." -ForegroundColor Yellow
$slowStart = Get-Date
for ($i = 1; $i -le 3; $i++) {
    Write-Host "   Request lento $i..." -ForegroundColor Gray
    $time = Measure-Command { curl http://localhost:8082/work-slow 2>$null }
    Write-Host "   Tiempo: $($time.TotalSeconds) segundos" -ForegroundColor DarkGray
}
$slowTime = (Get-Date) - $slowStart

# 3. Probar versión rápida (muchos requests)
Write-Host "`n3. Probando versión RÁPIDA (50 requests)..." -ForegroundColor Yellow
$fastStart = Get-Date
for ($i = 1; $i -le 50; $i++) {
    if ($i % 10 -eq 0) {
        Write-Host "   Request rápido $i..." -ForegroundColor Gray
    }
    curl http://localhost:8082/work-fast 2>$null
}
$fastTime = (Get-Date) - $fastStart

# 4. Resultados
Write-Host "`n=== RESULTADOS ===" -ForegroundColor Green
Write-Host "Versión LENTA:" -ForegroundColor White
Write-Host "   Requests: 3" -ForegroundColor Gray
Write-Host "   Tiempo total: $($slowTime.TotalSeconds) segundos" -ForegroundColor Gray
Write-Host "   Tiempo/request: $([math]::Round($slowTime.TotalSeconds/3, 2)) segundos" -ForegroundColor Gray

Write-Host "`nVersión RÁPIDA:" -ForegroundColor White
Write-Host "   Requests: 50" -ForegroundColor Gray
Write-Host "   Tiempo total: $($fastTime.TotalSeconds) segundos" -ForegroundColor Gray
Write-Host "   Tiempo/request: $([math]::Round($fastTime.TotalSeconds/50, 4)) segundos" -ForegroundColor Gray

$mejora = ($slowTime.TotalSeconds / 3) / ($fastTime.TotalSeconds / 50)
Write-Host " MEJORA: $([math]::Round($mejora, 0)) veces más rápida" -ForegroundColor Cyan

# 5. Limpiar
Stop-Process -Id $server.Id -Force
Write-Host "Prueba completada!" -ForegroundColor Green