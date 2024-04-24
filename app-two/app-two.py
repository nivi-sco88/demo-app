from flask import Flask, jsonify
import requests
import os

app = Flask(__name__)

first_service_url = os.getenv('FIRST_APP_URL', 'http://localhost:5000')

@app.route('/')
def reverse_message():
    try:
        response = requests.get(first_service_url)
        original_data = response.json()

        # Reverse the message
        reversed_message = original_data['message'][::-1]

        # Construct the reversed JSON response
        reversed_json_data = {
            "id": original_data['id'],
            "message": reversed_message
        }

        return jsonify(reversed_json_data)
    except Exception as e:
        print('Error:', e)
        return jsonify({'error': 'Internal Server Error'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
