# SWE-Gym Client

This directory contains a Python client library for interacting with the SWE-Gym OpenHands server. This client is designed to be used from your external model server to execute tools on the VM.

## Installation

Copy this directory to your model server and install the required dependencies:

```bash
pip install requests
```

## Usage

### Basic Usage

```python
from client import SWEGymClient

# Initialize the client
client = SWEGymClient(
    server_url="http://your-vm-ip:8080",
    api_key="your-api-key"  # From config/api_key.txt in the VM
)

# Execute a bash command
result = client.execute_bash(
    command="ls -la",
    instance_id="django.14520"  # Optional, specify which repository to use
)

print(result)
```

### Available Methods

The client provides convenience methods for common tools:

1. **Execute Bash Command**:
   ```python
   result = client.execute_bash(
       command="git status",
       instance_id="django.14520"
   )
   ```

2. **Execute Python Code**:
   ```python
   result = client.execute_python(
       code="import os\nprint(os.listdir('.'))",
       instance_id="django.14520"
   )
   ```

3. **Edit File**:
   ```python
   result = client.edit_file(
       path="/path/to/file.py",
       new_content_draft="def new_function():\n    return 42",
       start=1,
       end=-1,
       instance_id="django.14520"
   )
   ```

4. **Generic Tool Execution**:
   ```python
   result = client.execute_tool(
       tool="str_replace_editor",
       parameters={
           "command": "str_replace",
           "path": "/path/to/file.py",
           "old_str": "def old_function():",
           "new_str": "def new_function():"
       },
       instance_id="django.14520"
   )
   ```

### Command Line Interface

The client also provides a command-line interface for testing:

```bash
python client.py --server http://your-vm-ip:8080 \
                 --key your-api-key \
                 --tool execute_bash \
                 --params '{"command": "ls -la"}' \
                 --instance django.14520
```

## API Reference

### SWEGymClient Class

#### Constructor

```python
client = SWEGymClient(
    server_url: str,            # OpenHands server URL
    api_key: str,               # API key for authentication
    timeout: int = 60,          # Request timeout in seconds
    max_retries: int = 3,       # Maximum number of retries
    retry_delay: int = 2        # Delay between retries in seconds
)
```

#### Methods

- `check_connection() -> bool`: Check if the server is accessible
- `execute_tool(tool: str, parameters: Dict[str, Any], instance_id: Optional[str] = None, conversation_id: Optional[str] = None) -> Dict[str, Any]`: Execute a tool
- `execute_bash(command: str, instance_id: Optional[str] = None, conversation_id: Optional[str] = None) -> Dict[str, Any]`: Execute a bash command
- `execute_python(code: str, instance_id: Optional[str] = None, conversation_id: Optional[str] = None) -> Dict[str, Any]`: Execute Python code
- `edit_file(path: str, new_content_draft: str, start: int = 1, end: int = -1, instance_id: Optional[str] = None, conversation_id: Optional[str] = None) -> Dict[str, Any]`: Edit a file

## Integration with LLMs

Here's an example of how to integrate this client with your LLM:

```python
from client import SWEGymClient

client = SWEGymClient(
    server_url="http://your-vm-ip:8080",
    api_key="your-api-key"
)

def execute_tool_from_llm_output(model_output):
    """Parse the LLM output and execute the appropriate tool."""
    # Extract tool name and parameters from model output
    # This depends on your model's output format
    tool_name = extract_tool_name(model_output)
    parameters = extract_parameters(model_output)
    instance_id = extract_instance_id(model_output)
    
    # Execute the tool
    result = client.execute_tool(
        tool=tool_name,
        parameters=parameters,
        instance_id=instance_id
    )
    
    return result

def run_llm_agent():
    # Initial prompt
    prompt = "Fix the bug in the Django repository"
    conversation_history = [{"role": "user", "content": prompt}]
    
    # Agent loop
    while True:
        # Get model output
        model_output = call_your_llm_api(conversation_history)
        
        # If the model wants to use a tool
        if contains_tool_call(model_output):
            # Execute the tool
            tool_result = execute_tool_from_llm_output(model_output)
            
            # Add the tool result to the conversation
            conversation_history.append({"role": "system", "content": f"Tool result: {tool_result}"})
        else:
            # Model has finished
            break
```