import os
import urllib3
import json
import jsonlines
import boto3
import datetime 

def lambda_handler(event, handler): 
    
    region = os.environ.get('AWS_REGION')
    
    meraki_api_key = os.environ['meraki_api_key']
    network_id = os.environ['network_id']
    
    # Meraki API v1, Get Network Appliance Security Events
    # timespan parameter must be in seconds, retrieving events for the past 7 days 
    # default perPage value is 100, set to maximum acceptable value of 1000 to retrieve all events in past 7 days 
    url = f"https://api.meraki.com/api/v1/networks/{network_id}/appliance/security/events?timespan=604800&perPage=1000"
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-Cisco-Meraki-API-Key": meraki_api_key
    }
    
    # make GET request using urllib3 
    http = urllib3.PoolManager()
    response = http.request('GET', url, headers=headers)

    # decode response from bytes to string 
    response = response.data.decode() 

    # write response to temporary file and convert JSON string to JSON object using json.load()  
    r = open("/tmp/merakisecurityreport.json", "w")
    r.write(response)
    
    with open('/tmp/merakisecurityreport.json', "r") as r: 
         response = json.load(r)
    
    # use jsonlines library to convert JSON object response to 'jsonlines' format
    # jsonlines format is necessary for AWS Glue and AWS Athena to read data properly 
    with jsonlines.open('/tmp/merakisecurityreport.jsonl', 'w') as writer:
        writer.write_all(response)
    
    # create session with boto3
    session = boto3.Session()
    
    # create S3 resource from boto3 session 
    s3 = boto3.client('s3')
    
    # create archivestartdate to use in unique name for archived data file 
    today = datetime.date.today()
    archivestartdate = today - datetime.timedelta(days=7)
    archivestartdate = f"{archivestartdate.month}-{archivestartdate.day}-{archivestartdate.year}"
    
    # raw data in .jsonl format will be uploaded to two buckets
    # file uploaded to 'merakievents' bucket will override existing file so that Athena views & Quicksight datasets update with most recent week's data
    # file uploaded to 'securityreportsarchive' will be added with unique name to archive previous data 
    s3.upload_file("/tmp/merakisecurityreport.jsonl", "meraki-security-report", "merakisecurityreport.jsonl")
    s3.upload_file("/tmp/merakisecurityreport.jsonl", "meraki-security-reports-archive", f"merakisecurityreport-{archivestartdate}.jsonl")