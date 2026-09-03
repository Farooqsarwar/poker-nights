$APP_ID = "e9f508d1-19ef-44ed-aafc-c1578b955715"
# OneSignal REST API key (scoped to "Send messages only"). Never commit this.
# Provide it at deploy time via an environment variable so it is not in the repo.
$API_KEY = $env:ONESIGNAL_REST_API_KEY
if ([string]::IsNullOrEmpty($API_KEY)) {
    Write-Host "ERROR: Set the ONESIGNAL_REST_API_KEY environment variable before deploying." -ForegroundColor Red
    exit 1
}

Write-Host "Building Flutter Web with OneSignal keys..."
flutter build web --release --dart-define=ONESIGNAL_APP_ID=$APP_ID --dart-define=ONESIGNAL_REST_API_KEY=$API_KEY

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deploying to Firebase Hosting..."
    firebase deploy --only hosting
} else {
    Write-Host "Build failed. Deployment aborted." -ForegroundColor Red
}
