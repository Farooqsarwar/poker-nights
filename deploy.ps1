$APP_ID = "e9f508d1-19ef-44ed-aafc-c1578b955715"

Write-Host "Building Flutter Web release..."
# DEMO_PREMIUM=true enables client QA and demo checkout to grant Premium locally.
# This flag is not a security boundary; it flips to false the day billing is connected.
# Notice: ONESIGNAL_REST_API_KEY is deliberately omitted from client bundle to
# prevent secret key extraction (P0 security). P2P outbox handles inbox delivery.
flutter build web --release --dart-define=ONESIGNAL_APP_ID=$APP_ID --dart-define=DEMO_PREMIUM=true

if ($LASTEXITCODE -eq 0) {
    # Rules FIRST, on their own. They take effect immediately for everyone,
    # so if the app ships expecting rules that are not live yet, writes start
    # failing mid-tournament. Verify the rules land before the client does.
    Write-Host "Deploying Firestore rules and indexes..."
    firebase deploy --only firestore:rules,firestore:indexes

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Rules deployed. Deploying hosting..."
        firebase deploy --only hosting
    } else {
        Write-Host "Rules deploy failed. Hosting NOT deployed." -ForegroundColor Red
    }
} else {
    Write-Host "Build failed. Deployment aborted." -ForegroundColor Red
}
