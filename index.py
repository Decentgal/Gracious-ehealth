import json
import urllib.parse

def handler(event, context):
    # 1. Log the receipt of the event
    print("Received S3 Log Event: " + json.dumps(event, indent=2))

    try:
        # 2. Extract Bucket and Key from the S3 Event
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            # Decode the key in case it has special characters
            key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')
            
            print(f"ACTION REQUIRED: Processing new log file [{key}] from bucket [{bucket}]")
            
            # This is where you would normally add logic to scan the log for threats
            # e.g., if "403" in log_content: alert_admin()

        return {
            'statusCode': 200,
            'body': json.dumps('Log metadata processed successfully')
        }
    except Exception as e:
        print(e)
        print(f"Error getting object {key} from bucket {bucket}.")
        raise e
