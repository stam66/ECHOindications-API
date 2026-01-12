# ECHOindications-API

The API is built with LiveCode Server as middleware for the MySQL database supporting the ECHOindications.org web app
https://github.com/stam66/echo_indications

A generically deployable version of the API is available here:
https://github.com/stam66/LiveCodeServer-database-API

---

## Architecture

**RPC-style API** using LiveCode Server with MySQL backend. Each endpoint handles multiple actions via `?action=` parameter.

Example: `/API/indications.lc?action=list`

**HTTP Methods:**
- **GET** - Read operations (list, read, search)
- **POST** - Write operations (create, update, delete) and authentication

**Structure:**
```
API/
├── *.lc              # Endpoint files (one per resource)
├── lib/
│   ├── db-functions.lc       # Core security, JWT, rate limiting
│   ├── photon-library.lc     # JSON parser/serializer
│   └── settings.lc           # Database & JWT config (not in git)
└── database/
    └── *.sql         # Schema files
```

## Security Features

- **JWT Authentication** - HMAC-SHA256 tokens with 30-minute expiration
- **Rate Limiting** - IP-based protection (5 login attempts per 15 minutes)
- **Password Security** - PBKDF2-like hashing with salt, constant-time comparison
- **SQL Injection Prevention** - Input validation and escaping
- **Security Headers** - XSS, clickjacking, MIME-sniffing protection, CORS
- **Audit Logging** - Comprehensive change tracking

## API Endpoints

### **auth.lc** - Authentication (PUBLIC)
- `login` (POST) - Authenticate and get JWT token
- `refresh` (GET) - Refresh JWT token

### **indications.lc** - Medical Indications
- `list` (GET) - List all indications (PUBLIC)
- `list_by_context` (GET) - Filter by context (PUBLIC)
- `read` (GET) - Get single indication (PUBLIC)
- `create` (POST) - Create indication (PROTECTED)
- `update` (POST) - Update indication (PROTECTED)
- `delete` (POST) - Delete indication (PROTECTED)

### **contexts.lc** - Clinical Contexts (PUBLIC)
- `list` (GET) - List all contexts
- `read` (GET) - Get single context
- `with_counts` (GET) - Contexts with indication counts

### **search.lc** - Search (PUBLIC)
- `keyword` (GET) - Keyword search
- `advanced` (GET) - Advanced filtered search

### **changes.lc** - Change Requests (PUBLIC)
- `list` (GET) - List all change requests
- `by_status` (GET) - Filter by status
- `read` (GET) - Get single request
- `count_new` (GET) - Count new requests

### **users.lc** - User Management (PROTECTED)
- `list` (GET) - List all users
- `read` (GET) - Get user details
- `create` (POST) - Create user
- `update` (POST) - Update user
- `delete` (POST) - Deactivate user

### **dashboard.lc** - Analytics (PROTECTED)
- `stats` (GET) - Summary statistics
- `user_activity` (GET) - User activity log
- `recent_changes` (GET) - Recent system changes

### **audit.lc** - Audit Trail (PROTECTED)
- `recent` (GET) - Recent audit entries
- `by_table` (GET) - Filter by table
- `by_record` (GET) - History for specific record
- `by_user` (GET) - Activity by username

---

**Template Files:**
- `API/PLACEHOLDER.lc.example` - Generic endpoint template
- `API/TEMPLATE_README.md` - Template documentation
- `API/database/PLACEHOLDER_schema.sql.example` - Generic schema
