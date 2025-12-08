# Script para ejecutar la app fácilmente

Write-Host "🚀 SIGFLU - Sistema de Información Geográfica" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si Flutter está instalado
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: Flutter no está instalado o no está en PATH" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter detectado" -ForegroundColor Green

# Mostrar dispositivos disponibles
Write-Host ""
Write-Host "📱 Dispositivos disponibles:" -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "Selecciona una opción:" -ForegroundColor Yellow
Write-Host "1) Ejecutar en Chrome (Web)" -ForegroundColor White
Write-Host "2) Ejecutar en Android" -ForegroundColor White
Write-Host "3) Ejecutar en iOS" -ForegroundColor White
Write-Host "4) Ejecutar en Windows" -ForegroundColor White
Write-Host "5) Salir" -ForegroundColor White
Write-Host ""

$opcion = Read-Host "Ingresa el número de opción"

switch ($opcion) {
    "1" {
        Write-Host ""
        Write-Host "🌐 Ejecutando en Chrome..." -ForegroundColor Cyan
        flutter run -d chrome
    }
    "2" {
        Write-Host ""
        Write-Host "📱 Ejecutando en Android..." -ForegroundColor Cyan
        flutter run -d android
    }
    "3" {
        Write-Host ""
        Write-Host "🍎 Ejecutando en iOS..." -ForegroundColor Cyan
        flutter run -d ios
    }
    "4" {
        Write-Host ""
        Write-Host "🖥️  Ejecutando en Windows..." -ForegroundColor Cyan
        flutter run -d windows
    }
    "5" {
        Write-Host "👋 Hasta luego!" -ForegroundColor Green
        exit 0
    }
    default {
        Write-Host "❌ Opción no válida" -ForegroundColor Red
        exit 1
    }
}
