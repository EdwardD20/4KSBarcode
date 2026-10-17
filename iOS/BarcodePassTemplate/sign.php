<?php
header("Content-Type: application/vnd.apple.pkpass");

// Step 1: Get JSON payload from iOS app
$payload = json_decode(file_get_contents("php://input"), true);
if (!$payload || empty($payload['clientID'])) {
    http_response_code(400);
    echo "Missing clientID";
    exit;
}
$clientID = (string) $payload['clientID'];

// Step 2: Create a unique temporary folder for this request
$workDir = __DIR__ . "/tmp/" . uniqid();
if (!mkdir($workDir, 0700, true)) {
    http_response_code(500);
    echo "Failed to create temp folder";
    exit;
}

// Step 3: Load pass template and replace placeholders
$passTemplateFile = __DIR__ . "/pass.json";
if (!file_exists($passTemplateFile)) {
    http_response_code(500);
    echo "Pass template missing";
    exit;
}
$passTemplateString = file_get_contents($passTemplateFile);
$passTemplateString = str_replace("__SERIAL__", $clientID, $passTemplateString);
$passData = json_decode($passTemplateString, true);

// Step 4: Merge only non-conflicting fields from payload
$safePayload = array_diff_key($payload, $passData);
$passData = array_merge($passData, $safePayload);

// Step 5: Write finalized pass.json to temp folder
file_put_contents("$workDir/pass.json", json_encode($passData));

// Step 6: Copy static assets into temp folder
$assets = ["icon.png", "icon@2x.png", "icon@3x.png", "logo.png", "strip.png"];
foreach ($assets as $asset) {
    if (file_exists(__DIR__ . "/$asset")) {
        copy(__DIR__ . "/$asset", "$workDir/$asset");
    }
}

// Step 7: Build manifest.json
$files = glob("$workDir/*");
$manifest = [];
foreach ($files as $file) {
    $filename = basename($file);
    if ($filename === "manifest.json" || $filename === "signature") continue;
    $manifest[$filename] = sha1_file($file);
}
file_put_contents("$workDir/manifest.json", json_encode($manifest, JSON_PRETTY_PRINT));

// Step 8: Sign manifest with OpenSSL
$cmd = "openssl smime -binary -sign"
     . " -certfile " . escapeshellarg(__DIR__ . "/certs/AppleWWDRCA.pem")
     . " -signer " . escapeshellarg(__DIR__ . "/certs/pass.pem")
     . " -inkey " . escapeshellarg(__DIR__ . "/certs/key.pem")
     . " -in " . escapeshellarg("$workDir/manifest.json")
     . " -out " . escapeshellarg("$workDir/signature")
     . " -outform DER";

exec($cmd, $output, $ret);
if ($ret !== 0) {
    http_response_code(500);
    echo "Signing failed";
    exit;
}

// Step 9: Zip everything into pass.pkpass
chdir($workDir);
exec("zip -r pass.pkpass *");

// Step 10: Return the signed pass to the client
readfile("$workDir/pass.pkpass");

// Step 11: Clean up temporary folder
exec("rm -rf $workDir");