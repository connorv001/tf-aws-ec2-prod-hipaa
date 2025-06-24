#!/usr/bin/env python3
"""
Certificate Monitor Lambda Function
Monitors SSL certificate expiry and sends notifications
"""

import json
import boto3
import os
from datetime import datetime, timezone
from typing import Dict, Any

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for certificate monitoring
    """
    try:
        # Initialize AWS clients
        acm_client = boto3.client('acm')
        sns_client = boto3.client('sns')
        
        # Get environment variables
        certificate_arn = os.environ.get('CERTIFICATE_ARN')
        domain_name = os.environ.get('DOMAIN_NAME')
        
        if not certificate_arn or not domain_name:
            raise ValueError("Missing required environment variables")
        
        # Get certificate details
        response = acm_client.describe_certificate(CertificateArn=certificate_arn)
        certificate = response['Certificate']
        
        # Calculate days until expiry
        not_after = certificate.get('NotAfter')
        if not not_after:
            raise ValueError("Certificate expiry date not found")
        
        now = datetime.now(timezone.utc)
        days_until_expiry = (not_after - now).days
        
        # Prepare notification message
        message = {
            'domain_name': domain_name,
            'certificate_arn': certificate_arn,
            'days_until_expiry': days_until_expiry,
            'expiry_date': not_after.isoformat(),
            'status': certificate.get('Status'),
            'timestamp': now.isoformat()
        }
        
        # Send notification if certificate is expiring soon
        if days_until_expiry <= 30:
            notification_message = f"""
SSL Certificate Expiry Warning

Domain: {domain_name}
Certificate ARN: {certificate_arn}
Days until expiry: {days_until_expiry}
Expiry date: {not_after.strftime('%Y-%m-%d %H:%M:%S UTC')}
Status: {certificate.get('Status')}

Please renew the certificate before it expires.
            """.strip()
            
            # Send SNS notification (if topic ARN is available)
            sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
            if sns_topic_arn:
                sns_client.publish(
                    TopicArn=sns_topic_arn,
                    Subject=f"SSL Certificate Expiry Warning - {domain_name}",
                    Message=notification_message
                )
        
        # Log the result
        print(f"Certificate monitoring completed for {domain_name}")
        print(f"Days until expiry: {days_until_expiry}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(message)
        }
        
    except Exception as e:
        error_message = f"Error monitoring certificate: {str(e)}"
        print(error_message)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_message,
                'domain_name': domain_name,
                'certificate_arn': certificate_arn
            })
        }