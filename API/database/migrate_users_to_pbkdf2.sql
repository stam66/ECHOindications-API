-- ============================================================================
-- MIGRATION SCRIPT: Convert existing users from SHA-256 to PBKDF2
-- ============================================================================
--
-- This script migrates existing users who have SHA-256 password hashes
-- to the new PBKDF2 format.
--
-- IMPORTANT: This is a ONE-TIME migration. You'll need the plain-text passwords
-- to re-hash them with PBKDF2. There are two approaches:
--
-- APPROACH 1: Users reset their passwords (RECOMMENDED)
-- - Have users reset their passwords through the web app
-- - Use the new PBKDF2 hashing code when they set new passwords
-- - This is more secure as you never need to know their passwords
--
-- APPROACH 2: Manual migration (if you have plain-text passwords)
-- - If you have access to plain-text passwords, use this script as a template
-- - You'll need to compute PBKDF2 hashes manually and update the database
--
-- ============================================================================

-- Current state check: Show users with old SHA-256 format
-- (password_hash is 64 hex chars and doesn't contain ":")
SELECT
    id,
    username,
    email,
    LENGTH(password_hash) as hash_length,
    password_salt,
    CASE
        WHEN password_hash LIKE '%:%' THEN 'PBKDF2 (New Format)'
        WHEN LENGTH(password_hash) = 64 THEN 'SHA-256 (Old Format - Needs Migration)'
        ELSE 'Unknown Format'
    END as format_status
FROM users
ORDER BY id;

-- ============================================================================
-- MANUAL MIGRATION TEMPLATE
-- ============================================================================
-- If you have plain-text passwords, you can migrate users like this:
--
-- For each user:
-- 1. Compute PBKDF2 hash using the password and existing salt
-- 2. Store in "salt:hash" format
--
-- Example using a LiveCode script to generate the hash:
--
-- put "user_password_here" into tPassword
-- put "existing_salt_from_db" into tSalt
-- put hashPassword(tPassword, tSalt) into tFullHash
-- -- tFullHash will be in "salt:hash" format
--
-- Then update the database:
-- UPDATE users
-- SET password_hash = 'salt:hash_value_here'
-- WHERE username = 'username_here';
--
-- ============================================================================

-- ============================================================================
-- XOJO WEB APP CODE FOR NEW USER REGISTRATION
-- ============================================================================
-- Use this code in your Xojo web app when creating new users:
/*

' Generate random salt (32 alphanumeric characters)
Function GenerateRandomSalt(length As Integer) As String
  Dim chars As String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  Dim salt As String = ""

  For i As Integer = 1 To length
    Dim randomIndex As Integer = System.Random.InRange(0, chars.Len - 1)
    salt = salt + chars.Mid(randomIndex, 1)
  Next

  Return salt
End Function

' Hash password using PBKDF2
Function HashPasswordPBKDF2(password As String, salt As String) As String
  ' Convert password to MemoryBlock
  Dim passwordData As New MemoryBlock(password.LenB)
  passwordData.StringValue(0, password.LenB) = password

  ' Compute PBKDF2 hash
  Dim hash As MemoryBlock
  hash = Crypto.PBKDF2(salt, passwordData, 1000, 32, Crypto.HashAlgorithms.SHA2_256)

  ' Convert to hex string
  Dim hashHex As String = EncodeHex(hash)

  ' Return in "salt:hash" format for compatibility
  Return salt + ":" + hashHex
End Function

' Create new user
Sub CreateUser(username As String, password As String, email As String, name As String)
  ' Generate salt
  Dim salt As String = GenerateRandomSalt(32)

  ' Hash password with PBKDF2
  Dim fullHash As String = HashPasswordPBKDF2(password, salt)

  ' Extract hash part (after the colon)
  Dim colonPos As Integer = fullHash.IndexOf(":")
  Dim hashOnly As String = fullHash.Mid(colonPos + 1)

  ' Insert into database
  Dim sql As String = "INSERT INTO users (username, password_hash, password_salt, email, name) VALUES (?, ?, ?, ?, ?)"
  db.SQLExecute(sql, username, hashOnly, salt, email, name)
End Sub

*/

-- ============================================================================
-- XOJO WEB APP CODE FOR PASSWORD VERIFICATION
-- ============================================================================
-- Use this code in your Xojo web app for login:
/*

Function VerifyPassword(password As String, storedHash As String, storedSalt As String) As Boolean
  ' Convert password to MemoryBlock
  Dim passwordData As New MemoryBlock(password.LenB)
  passwordData.StringValue(0, password.LenB) = password

  ' Compute PBKDF2 hash with stored salt
  Dim computedHash As MemoryBlock
  computedHash = Crypto.PBKDF2(storedSalt, passwordData, 1000, 32, Crypto.HashAlgorithms.SHA2_256)

  ' Convert to hex string
  Dim computedHashHex As String = EncodeHex(computedHash)

  ' Compare with stored hash (case-insensitive)
  Return computedHashHex.Lowercase = storedHash.Lowercase
End Function

*/

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- After migration, verify all users are in PBKDF2 format
-- (password_hash should NOT be exactly 64 chars if using salt:hash format,
--  OR hash column is 64 chars and salt column is NOT NULL)
SELECT
    id,
    username,
    LENGTH(password_hash) as hash_length,
    LENGTH(password_salt) as salt_length,
    CASE
        WHEN password_salt IS NOT NULL AND LENGTH(password_salt) = 32 THEN 'PBKDF2 ✓'
        ELSE 'NEEDS MIGRATION ✗'
    END as status
FROM users
ORDER BY id;

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- 1. The database stores:
--    - password_hash: 64-character hex string (PBKDF2 output)
--    - password_salt: 32-character alphanumeric string
--
-- 2. Both API and Xojo use the same PBKDF2 parameters:
--    - Algorithm: HMAC-SHA256
--    - Iterations: 1000
--    - Output length: 32 bytes (256 bits)
--
-- 3. After migration, users can log in with same credentials on both:
--    - LiveCode Server API (uses pbkdf2() function)
--    - Xojo Web App (uses Crypto.PBKDF2)
--
-- 4. Password format in auth.lc is constructed as "salt:hash" for verification
--    but stored separately in the database columns
--
-- ============================================================================
