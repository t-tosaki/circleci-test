#!/bin/bash

# see:
# - https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app
# - https://docs.github.com/ja/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation

client_id=$1 # Client ID as first argument
installation_id=$2
pem=$( cat $3 ) # file path of the private key as second argument

now=$(date +%s)
iat=$((${now} - 60)) # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
  "typ":"JWT",
  "alg":"RS256"
}'
# Header encode
header=$( echo -n "${header_json}" | b64enc )

payload_json="{
  \"iat\":${iat},
  \"exp\":${exp},
  \"iss\":\"${client_id}\"
}"
# Payload encode
payload=$( echo -n "${payload_json}" | b64enc )

# Signature
header_payload="${header}"."${payload}"
signature=$(
  openssl dgst -sha256 -sign <(echo -n "${pem}") \
  <(echo -n "${header_payload}") | b64enc
)

# Create JWT
jwt="${header_payload}"."${signature}"

# Get installation token
response=$(curl --request POST \
  --url "https://api.github.com/app/installations/${installation_id}/access_tokens" \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${jwt}" \
  --header "X-GitHub-Api-Version: 2026-03-10"
)
installation_token=$(echo "$response" | jq -r .token)

if [ "$installation_token" == "null" ] || [ -z "$installation_token" ]; then
  echo "Failed to get token: $response"
  exit 1
fi

echo "$installation_token"
