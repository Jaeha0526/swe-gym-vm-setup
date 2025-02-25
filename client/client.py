#!/usr/bin/env python3
"""
Client library for communicating with the SWE-Gym OpenHands server.
This can be used by your model to execute tools on the VM.
"""

import os
import json
import time
import logging
import argparse
import requests
from typing import Dict, Any, Optional, List, Union

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("swe-gym-client")

class SWEGymClient:
    """Client for interacting with the SWE-Gym OpenHands server."""
    
    def __init__(
        self, 
        server_url: str, 
        api_key: str,
        timeout: int = 60,
        max_retries: int = 3,
        retry_delay: int = 2
    ):
        """Initialize the SWE-Gym client.
        
        Args:
            server_url: URL of the OpenHands server
            api_key: API key for authentication
            timeout: Request timeout in seconds
            max_retries: Maximum number of retries for failed requests
            retry_delay: Delay between retries in seconds
        """
        self.server_url = server_url.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        # Test connection
        self.check_connection()
    
    def check_connection(self) -> bool:
        """Check if the server is accessible.
        
        Returns:
            bool: True if the server is accessible, False otherwise
        """
        try:
            response = requests.get(
                f"{self.server_url}/api/health",
                headers=self.headers,
                timeout=self.timeout
            )
            if response.status_code == 200:
                logger.info("Successfully connected to OpenHands server")
                return True
            else:
                logger.warning(f"Server returned status code {response.status_code}")
                return False
        except requests.RequestException as e:
            logger.error(f"Failed to connect to server: {str(e)}")
            return False
    
    def execute_tool(
        self,
        tool: str,
        parameters: Dict[str, Any],
        instance_id: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Execute a tool on the OpenHands server.
        
        Args:
            tool: Tool name (e.g., "execute_bash", "execute_ipython_cell")
            parameters: Tool parameters
            instance_id: Optional instance ID (e.g., "django.14520")
            conversation_id: Optional conversation ID for tracking
            
        Returns:
            dict: Response from the server
        
        Raises:
            Exception: If the request fails after retries
        """
        if conversation_id is None:
            conversation_id = f"conv-{int(time.time())}"
            
        payload = {
            "tool": tool,
            "parameters": parameters,
            "conversation_id": conversation_id
        }
        
        if instance_id:
            payload["instance_id"] = instance_id
        
        for attempt in range(self.max_retries):
            try:
                response = requests.post(
                    f"{self.server_url}/api/v1/execute",
                    headers=self.headers,
                    json=payload,
                    timeout=self.timeout
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.warning(f"Attempt {attempt+1}/{self.max_retries} failed with status {response.status_code}: {response.text}")
                    
                    if attempt < self.max_retries - 1:
                        time.sleep(self.retry_delay)
                    else:
                        raise Exception(f"Failed to execute tool after {self.max_retries} attempts: {response.text}")
                        
            except requests.RequestException as e:
                logger.error(f"Request error on attempt {attempt+1}/{self.max_retries}: {str(e)}")
                
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)
                else:
                    raise Exception(f"Failed to execute tool after {self.max_retries} attempts: {str(e)}")
    
    # Convenience methods for common tools
    
    def execute_bash(
        self, 
        command: str, 
        instance_id: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Execute a bash command.
        
        Args:
            command: Bash command to execute
            instance_id: Optional instance ID
            conversation_id: Optional conversation ID
            
        Returns:
            dict: Response with command output and exit code
        """
        return self.execute_tool(
            tool="execute_bash",
            parameters={"command": command},
            instance_id=instance_id,
            conversation_id=conversation_id
        )
    
    def execute_python(
        self, 
        code: str, 
        instance_id: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Execute Python code.
        
        Args:
            code: Python code to execute
            instance_id: Optional instance ID
            conversation_id: Optional conversation ID
            
        Returns:
            dict: Response with code execution result
        """
        return self.execute_tool(
            tool="execute_ipython_cell",
            parameters={"code": code},
            instance_id=instance_id,
            conversation_id=conversation_id
        )
    
    def edit_file(
        self,
        path: str,
        new_content_draft: str,
        start: int = 1,
        end: int = -1,
        instance_id: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Edit a file.
        
        Args:
            path: File path
            new_content_draft: New content draft
            start: Start line (1-indexed, inclusive)
            end: End line (1-indexed, inclusive, -1 for end of file)
            instance_id: Optional instance ID
            conversation_id: Optional conversation ID
            
        Returns:
            dict: Response with file edit result
        """
        return self.execute_tool(
            tool="edit_file",
            parameters={
                "path": path,
                "new_content_draft": new_content_draft,
                "start": start,
                "end": end
            },
            instance_id=instance_id,
            conversation_id=conversation_id
        )

def main():
    """Command-line interface for testing the client."""
    parser = argparse.ArgumentParser(description="SWE-Gym OpenHands Client")
    parser.add_argument("--server", required=True, help="OpenHands server URL")
    parser.add_argument("--key", required=True, help="API key")
    parser.add_argument("--tool", required=True, help="Tool to execute")
    parser.add_argument("--params", required=True, help="Tool parameters as JSON")
    parser.add_argument("--instance", help="Instance ID (optional)")
    
    args = parser.parse_args()
    
    client = SWEGymClient(args.server, args.key)
    
    try:
        params = json.loads(args.params)
    except json.JSONDecodeError:
        logger.error("Invalid JSON in params argument")
        return
    
    result = client.execute_tool(
        tool=args.tool,
        parameters=params,
        instance_id=args.instance
    )
    
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()