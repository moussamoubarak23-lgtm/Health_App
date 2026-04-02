Set-Location $PSScriptRoot

$adminLogin = Read-Host "Login admin Odoo"
$securePassword = Read-Host "Mot de passe admin Odoo" -AsSecureString
$dbName = Read-Host "Nom de la base Odoo (laisser vide pour Dossier_medical)"
$baseUrl = Read-Host "URL Odoo (laisser vide pour http://192.168.11.101:8069)"

if ([string]::IsNullOrWhiteSpace($adminLogin)) {
  $adminLogin = "admin"
}

if ([string]::IsNullOrWhiteSpace($dbName)) {
  $dbName = "Dossier_medical"
}

if ([string]::IsNullOrWhiteSpace($baseUrl)) {
  $baseUrl = "http://192.168.11.101:8069"
}

$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
  $adminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
}

flutter run -d windows `
  --dart-define=ENABLE_DOCTOR_REGISTRATION=true `
  --dart-define=ODOO_ADMIN_LOGIN=$adminLogin `
  --dart-define=ODOO_ADMIN_PASSWORD="$adminPassword" `
  --dart-define=ODOO_BASE_URL="$baseUrl" `
  --dart-define=ODOO_DB_NAME="$dbName"
