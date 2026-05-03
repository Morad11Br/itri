import jwt
import time

team_id = "YOUR_TEAM_ID"
client_id = "com.novaparfum.barfum.siwa"  # Your Services ID
key_id = "YOUR_KEY_ID"
private_key = open("AuthKey_XXXXXX.p8").read()

token = jwt.encode(
    {
        "iss": team_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 15777000,  # ~6 months
        "aud": "https://appleid.apple.com",
        "sub": client_id,
    },
    private_key,
    algorithm="ES256",
    headers={"kid": key_id},
)

print(token)