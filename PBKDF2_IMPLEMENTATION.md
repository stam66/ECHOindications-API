# PBKDF2 Password Hashing - Shared Implementation Guide

This document explains how to implement compatible password hashing between the LiveCode API and Xojo web app using PBKDF2.

## Overview

Both systems can now use **PBKDF2** (Password-Based Key Derivation Function 2) with HMAC-SHA256 for secure password storage. This allows users to authenticate with both the API and web app using the same credentials.

## Algorithm Parameters

Both systems MUST use these exact parameters:

- **Algorithm**: PBKDF2 with HMAC-SHA256
- **Iterations**: 10,000
- **Salt Length**: 32 characters (alphanumeric)
- **Output Length**: 32 bytes (256 bits)
- **Storage Format**: Hash stored as 64-character hex string

## Database Schema

```sql
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,  -- Stores 64-char hex or "salt:hash"
  password_salt VARCHAR(32),            -- Stores 32-char salt (NULL for legacy)
  email VARCHAR(100),
  name VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE
);
```

## Implementation: Xojo Web App

### Creating a New User Password (Xojo)

```vb
' Generate random salt (32 alphanumeric characters)
Dim salt As String = GenerateRandomSalt(32)

' Get password from user input
Dim password As String = txtPassword.Text

' Convert password to MemoryBlock
Dim passwordData As New MemoryBlock(password.LenB)
passwordData.StringValue(0, password.LenB) = password

' Hash password using PBKDF2
Dim hash As MemoryBlock
hash = Crypto.PBKDF2(salt, passwordData, 10000, 32, Crypto.HashAlgorithms.SHA2_256)

' Convert hash to hex string for storage
Dim hashHex As String = EncodeHex(hash)

' Store in database
Dim sql As String = "INSERT INTO users (username, password_hash, password_salt) " + _
                    "VALUES (?, ?, ?)"
db.SQLExecute(sql, username, hashHex, salt)
```

### Verifying Password on Login (Xojo)

```vb
' Fetch user from database
Dim rs As RowSet = db.SelectSQL("SELECT password_hash, password_salt FROM users WHERE username = ?", username)

If rs <> Nil And Not rs.AfterLastRow Then
  Dim storedHash As String = rs.Column("password_hash").StringValue
  Dim storedSalt As String = rs.Column("password_salt").StringValue

  ' Check if user has PBKDF2 hash (has salt) or legacy SHA-256 (no salt)
  If storedSalt <> "" Then
    ' PBKDF2 verification
    Dim passwordData As New MemoryBlock(password.LenB)
    passwordData.StringValue(0, password.LenB) = password

    Dim computedHash As MemoryBlock
    computedHash = Crypto.PBKDF2(storedSalt, passwordData, 10000, 32, Crypto.HashAlgorithms.SHA2_256)

    Dim computedHashHex As String = EncodeHex(computedHash)

    If computedHashHex = storedHash Then
      ' Login successful
      Return True
    End If
  Else
    ' Legacy SHA-256 verification (for backward compatibility)
    Dim sql As String = "SELECT SHA2(?, 256) AS computed_hash"
    Dim hashRS As RowSet = db.SelectSQL(sql, password)

    If hashRS <> Nil And Not hashRS.AfterLastRow Then
      Dim computedHash As String = hashRS.Column("computed_hash").StringValue
      If computedHash = storedHash Then
        ' Login successful with legacy hash
        Return True
      End If
    End If
  End If
End If

' Login failed
Return False
```

### Helper Function: Generate Random Salt (Xojo)

```vb
Function GenerateRandomSalt(length As Integer) As String
  Dim chars As String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  Dim salt As String = ""

  For i As Integer = 1 To length
    Dim randomIndex As Integer = System.Random.InRange(0, chars.Len - 1)
    salt = salt + chars.Mid(randomIndex, 1)
  Next

  Return salt
End Function
```

## Implementation: LiveCode API

The API automatically uses PBKDF2 for password hashing. Here's how it works:

### Creating a New User Password (API)

```livecode
-- Generate random salt
put generateSalt() into tSalt  -- Returns 32 alphanumeric chars

-- Hash password with PBKDF2
put hashPassword(tPassword, tSalt) into tFullHash
-- Returns "salt:hash" format, e.g., "abc123...:def456..."

-- Extract parts for storage
set the itemDelimiter to ":"
put item 1 of tFullHash into tSalt
put item 2 of tFullHash into tHash

-- Store in database
put "INSERT INTO users (username, password_hash, password_salt) VALUES (?, ?, ?)" into tSQL
-- Execute with: username, tHash, tSalt
```

### Verifying Password on Login (API)

The `verifyPassword()` function automatically handles both formats:

```livecode
-- Fetch user from database
put "SELECT password_hash, password_salt FROM users WHERE username = ?" into tSQL

-- Construct full hash for verification
if tSalt is not empty then
  -- PBKDF2 format: construct "salt:hash"
  put tSalt & ":" & tHash into tFullHash
else
  -- Legacy SHA-256 format: use hash as-is
  put tHash into tFullHash
end if

-- Verify password
if verifyPassword(tPassword, tFullHash) then
  -- Login successful
else
  -- Login failed
end if
```

## Password Format Compatibility

### Format 1: PBKDF2 (New Users - Recommended)

**Storage:**
- `password_hash`: 64-character hex string (PBKDF2 output)
- `password_salt`: 32-character alphanumeric string

**Example:**
```
password_salt: "kJ8mN2pL9qR5sT1vX4yZ7bC3dF6gH0jK"
password_hash: "a1b2c3d4e5f6789...64chars"
```

**Compatible with:**
- ✅ API authentication
- ✅ Xojo web app (when using Crypto.PBKDF2)

### Format 2: SHA-256 (Legacy - Web App Only)

**Storage:**
- `password_hash`: 64-character hex string (SHA-256 output)
- `password_salt`: NULL or empty

**Example:**
```
password_salt: NULL
password_hash: "abc123def456...64chars"
```

**Compatible with:**
- ✅ API authentication (legacy fallback)
- ✅ Xojo web app (using MySQL SHA2 function)

**Note:** This format is maintained for backward compatibility with existing users. New users should use PBKDF2.

## Migration Strategy

### Current State
- **Existing users**: Using SHA-256 hashes (MySQL `SHA2(password, 256)`)
- **Auto-migration**: DISABLED to maintain web app compatibility

### For New Users

**Option 1: Create via API**
```bash
POST /API/users.lc?action=create
{
  "username": "newuser",
  "password": "securepassword",
  "email": "user@example.com",
  "name": "New User"
}
```
→ Automatically uses PBKDF2

**Option 2: Create via Web App**
Use the Xojo code above with `Crypto.PBKDF2` to match the API format.

### For Existing Users

Existing users will continue to use SHA-256 until their passwords are manually migrated. Both systems support SHA-256 for backward compatibility.

To migrate an existing user to PBKDF2, you can provide a "change password" feature that:
1. Verifies old password (SHA-256)
2. Generates new salt
3. Hashes new password with PBKDF2
4. Updates both `password_hash` and `password_salt` columns

## Security Notes

1. **PBKDF2 Iteration Count**: 10,000 iterations provides a good balance between security and performance. OWASP recommends 600,000+ for maximum security, but 10,000 is suitable for most web applications while maintaining reasonable performance.

2. **Salt Uniqueness**: Every password MUST have a unique salt. Never reuse salts.

3. **Constant-Time Comparison**: Always compare hashes using constant-time comparison to prevent timing attacks.

4. **HTTPS Only**: Always use HTTPS in production to protect passwords in transit.

5. **SHA-256 Legacy Format**: While supported for backward compatibility, SHA-256 without salt is less secure than PBKDF2. Encourage users to update passwords.

## Testing

### Test Vector 1: PBKDF2

**Input:**
- Password: `testpassword123`
- Salt: `abcdefghijklmnopqrstuvwxyz012345`
- Iterations: 1000
- Output length: 32 bytes

**Expected Output (hex):**
You can verify both implementations produce the same hash by running:

**Xojo:**
```vb
Dim pwd As New MemoryBlock(15)
pwd.StringValue(0, 15) = "testpassword123"
Dim hash As MemoryBlock = Crypto.PBKDF2("abcdefghijklmnopqrstuvwxyz012345", pwd, 10000, 32, Crypto.HashAlgorithms.SHA2_256)
MessageBox EncodeHex(hash)
```

**LiveCode API:**
```livecode
put pbkdf2("testpassword123", "abcdefghijklmnopqrstuvwxyz012345", 1000, 32) into tBinary
put binaryToHex(tBinary) into tHex
answer tHex
```

Both should produce the same output.

## Troubleshooting

### Hashes Don't Match Between Systems

1. **Check parameters**: Ensure both use SHA2_256, 10,000 iterations, 32-byte output
2. **Verify salt**: Salt must be identical in both systems
3. **Check encoding**: Hash should be lowercase hex (64 characters)
4. **MemoryBlock conversion**: In Xojo, ensure password is properly converted to MemoryBlock

### User Can't Log Into One System

1. **Check password_salt column**: If NULL, user has legacy SHA-256 hash
2. **Verify format handling**: System must support both PBKDF2 and SHA-256
3. **Database sync**: Ensure both systems use the same database

## References

- [RFC 2898: PKCS #5 - PBKDF2 Specification](https://tools.ietf.org/html/rfc2898)
- [Xojo Crypto.PBKDF2 Documentation](https://documentation.xojo.com/api/cryptography/crypto.html#crypto-pbkdf2)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
