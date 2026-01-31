import secrets
import hashlib

# Pon aquí tus perfiles y el PIN que quieres para cada uno
profiles = {
    "ches": "111111",
    "cabegos": "111111",
    "alejandro": "061101",
    "maiki": "111111",
    "dani": "111111",
    "enrique": "111111",
    "fede": "111111",
    "god": "111111",
    "javi": "111111",
    "juanma": "111111",
    "monty": "111111",
    "nino": "111111",
    "pablo": "111111",
    "pedro": "111111",
    "pepe": "111111",
    "quike": "111111",
    "sit": "111111",
}

def sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def gen_salt(length: int = 16) -> str:
    # 16 bytes => 32 chars hex (limpio para Firestore)
    return secrets.token_hex(length)

for profile_id, pin in profiles.items():
    salt = gen_salt(16)  # 32 chars hex
    pin_hash = sha256_hex(f"{salt}{pin}")
    print(f"\nPROFILE: {profile_id}")
    print(f"pinSalt: {salt}")
    print(f"pinHash: {pin_hash}")
