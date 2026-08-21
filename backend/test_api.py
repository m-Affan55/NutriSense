import requests
import json

url = "http://127.0.0.1:8000/api/v1/coach/chat"
headers = {"Content-Type": "application/json"}
data = {
    "user_id": "23f83316-5975-49ff-8bc6-bb8b37821892",
    "message": "i have eaten 5 chocolates and i am not feeling well",
    "history": []
}

try:
    response = requests.post(url, headers=headers, json=data)
    print("Status Code:", response.status_code)
    print("Response JSON:", response.json())
except Exception as e:
    print("Error:", e)
