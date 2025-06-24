#!/usr/bin/env python3
"""
Backup Validator Lambda Function
Validates backup integrity and sends notifications
"""

import json
import boto3
import os
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for backup validation
    """
    try:
        # Initialize AWS clients
        backup_client = boto3.client('backup')
        sns_client = boto3.client('sns')
        
        # Get environment variables
        backup_vault_name = os.environ.get('BACKUP_VAULT_NAME')
        project_name = os.environ.get('PROJECT_NAME')
        environment = os.environ.get('ENVIRONMENT')
        
        if not backup_vault_name:
            raise ValueError("Missing BACKUP_VAULT_NAME environment variable")
        
        # Get recent recovery points (last 24 hours)
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(days=1)
        
        response = backup_client.list_recovery_points(
            BackupVaultName=backup_vault_name,
            ByCreatedAfter=start_time,
            ByCreatedBefore=end_time
        )
        
        recovery_points = response.get('RecoveryPoints', [])
        
        # Validate recovery points
        validation_results = []
        failed_backups = []
        
        for rp in recovery_points:
            recovery_point_arn = rp['RecoveryPointArn']
            status = rp['Status']
            creation_date = rp['CreationDate']
            resource_arn = rp['ResourceArn']
            
            # Check recovery point details
            try:
                rp_details = backup_client.describe_recovery_point(
                    BackupVaultName=backup_vault_name,
                    RecoveryPointArn=recovery_point_arn
                )
                
                validation_result = {
                    'recovery_point_arn': recovery_point_arn,
                    'resource_arn': resource_arn,
                    'status': status,
                    'creation_date': creation_date.isoformat(),
                    'backup_size_bytes': rp_details.get('BackupSizeInBytes', 0),
                    'is_encrypted': rp_details.get('IsEncrypted', False),
                    'validation_status': 'SUCCESS' if status == 'COMPLETED' else 'FAILED'
                }
                
                if status != 'COMPLETED':
                    failed_backups.append(validation_result)
                
                validation_results.append(validation_result)
                
            except Exception as e:
                print(f"Error validating recovery point {recovery_point_arn}: {str(e)}")
                failed_backups.append({
                    'recovery_point_arn': recovery_point_arn,
                    'resource_arn': resource_arn,
                    'error': str(e),
                    'validation_status': 'ERROR'
                })
        
        # Check for missing backups (should have at least one backup per day)
        if len(recovery_points) == 0:
            failed_backups.append({
                'error': 'No backups found in the last 24 hours',
                'validation_status': 'MISSING'
            })
        
        # Prepare summary
        summary = {
            'project_name': project_name,
            'environment': environment,
            'backup_vault_name': backup_vault_name,
            'validation_timestamp': end_time.isoformat(),
            'total_recovery_points': len(recovery_points),
            'successful_backups': len([rp for rp in validation_results if rp.get('validation_status') == 'SUCCESS']),
            'failed_backups': len(failed_backups),
            'validation_results': validation_results,
            'failed_backup_details': failed_backups
        }
        
        # Send notification if there are failures
        if failed_backups:
            notification_message = f"""
Backup Validation Alert - {project_name} ({environment})

Backup Vault: {backup_vault_name}
Validation Time: {end_time.strftime('%Y-%m-%d %H:%M:%S UTC')}

Summary:
- Total Recovery Points: {len(recovery_points)}
- Successful Backups: {len([rp for rp in validation_results if rp.get('validation_status') == 'SUCCESS'])}
- Failed Backups: {len(failed_backups)}

Failed Backup Details:
{json.dumps(failed_backups, indent=2, default=str)}

Please investigate and resolve backup issues immediately.
            """.strip()
            
            # Send SNS notification (if topic ARN is available)
            sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
            if sns_topic_arn:
                sns_client.publish(
                    TopicArn=sns_topic_arn,
                    Subject=f"Backup Validation Alert - {project_name} ({environment})",
                    Message=notification_message
                )
        
        # Log the results
        print(f"Backup validation completed for {backup_vault_name}")
        print(f"Total recovery points: {len(recovery_points)}")
        print(f"Failed backups: {len(failed_backups)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(summary, default=str)
        }
        
    except Exception as e:
        error_message = f"Error during backup validation: {str(e)}"
        print(error_message)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_message,
                'backup_vault_name': backup_vault_name,
                'project_name': project_name,
                'environment': environment
            })
        }