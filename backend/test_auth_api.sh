#!/bin/bash

# Authentication and User Management API Test Script
# Run this script after starting the server with: go run cmd/server/main.go

BASE_URL="http://localhost:8080/api/v1"
TOKEN=""

echo "========================================="
echo "Testing Bstock Authentication API"
echo "========================================="
echo ""

# Test 1: Health Check
echo "1. Testing Health Endpoint..."
curl -s http://localhost:8080/health | jq '.'
echo ""

# Test 2: Register new organization
echo "2. Testing Registration..."
REGISTER_RESPONSE=$(curl -s -X POST ${BASE_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "password123"
  }')

echo "$REGISTER_RESPONSE" | jq '.'
TOKEN=$(echo "$REGISTER_RESPONSE" | jq -r '.token')
echo "Token: $TOKEN"
echo ""

# Test 3: Login
echo "3. Testing Login..."
LOGIN_RESPONSE=$(curl -s -X POST ${BASE_URL}/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "password123"
  }')

echo "$LOGIN_RESPONSE" | jq '.'
TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')
echo "Updated Token: $TOKEN"
echo ""

# Test 4: List Users (Protected - Owner only)
echo "4. Testing List Users (Protected)..."
curl -s -X GET ${BASE_URL}/users \
  -H "Authorization: Bearer $TOKEN" | jq '.'
echo ""

# Test 5: Invite User (Protected - Owner only)
echo "5. Testing Invite User (Protected)..."
curl -s -X POST ${BASE_URL}/users/invite \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+251911234568",
    "password": "password123",
    "role": "cashier"
  }' | jq '.'
echo ""

# Test 6: List Users Again (should show 2 users now)
echo "6. Testing List Users Again..."
USERS_RESPONSE=$(curl -s -X GET ${BASE_URL}/users \
  -H "Authorization: Bearer $TOKEN")
echo "$USERS_RESPONSE" | jq '.'
USER_ID=$(echo "$USERS_RESPONSE" | jq -r '.[1].user_id')
echo "Second User ID: $USER_ID"
echo ""

# Test 7: Test unauthorized access (no token)
echo "7. Testing Unauthorized Access (should fail)..."
curl -s -X GET ${BASE_URL}/users | jq '.'
echo ""

# Test 8: Remove User (Protected - Owner only)
echo "8. Testing Remove User (Protected)..."
curl -s -X DELETE ${BASE_URL}/users/$USER_ID \
  -H "Authorization: Bearer $TOKEN" | jq '.'
echo ""

# Test 9: Test login with cashier credentials
echo "9. Testing Login with Cashier (to get cashier token)..."
CASHIER_LOGIN=$(curl -s -X POST ${BASE_URL}/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234568",
    "password": "password123"
  }')

echo "$CASHIER_LOGIN" | jq '.'
CASHIER_TOKEN=$(echo "$CASHIER_LOGIN" | jq -r '.token')
echo ""

# Test 10: Test cashier trying to access owner-only endpoint (should fail)
echo "10. Testing Cashier Access to Owner Endpoint (should fail)..."
curl -s -X GET ${BASE_URL}/users \
  -H "Authorization: Bearer $CASHIER_TOKEN" | jq '.'
echo ""

# Test 11: Attempt to register duplicate organization (should fail)
echo "11. Testing Duplicate Organization Registration (should fail)..."
curl -s -X POST ${BASE_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234569",
    "password": "password123"
  }' | jq '.'
echo ""

# Test 12: Attempt to register duplicate phone number (should fail)
echo "12. Testing Duplicate Phone Number Registration (should fail)..."
curl -s -X POST ${BASE_URL}/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Another Shop",
    "phone_number": "+251911234567",
    "password": "password123"
  }' | jq '.'
echo ""

# Test 13: Invalid credentials login (should fail)
echo "13. Testing Invalid Credentials Login (should fail)..."
curl -s -X POST ${BASE_URL}/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "organization_name": "Test Shop",
    "phone_number": "+251911234567",
    "password": "wrongpassword"
  }' | jq '.'
echo ""

echo "========================================="
echo "All Tests Complete!"
echo "========================================="
