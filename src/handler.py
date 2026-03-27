import json


def lambda_handler(event, context):
    """Hello World Lambda handler for API Gateway."""
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps({"message": "Hello, World!"}),
    }
