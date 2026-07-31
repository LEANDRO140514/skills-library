# Python MCP Server Implementation Guide

## Overview

Python-specific best practices for implementing MCP servers using FastMCP and the MCP Python SDK.

---

## Quick Reference

### Key Imports
```python
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Optional, List, Dict, Any
from enum import Enum
import httpx
```

### Server Initialization
```python
mcp = FastMCP("service_mcp")
```

### Tool Registration Pattern
```python
@mcp.tool(name="tool_name", annotations={...})
async def tool_function(params: InputModel) -> str:
    # Implementation
    pass
```

---

## Server Naming Convention

- **Format**: `{service}_mcp` (lowercase with underscores)
- **Examples**: `github_mcp`, `jira_mcp`, `stripe_mcp`

## Tool Structure with FastMCP + Pydantic

```python
from pydantic import BaseModel, Field, field_validator, ConfigDict
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("example_mcp")

class UserSearchInput(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        validate_assignment=True,
        extra='forbid'
    )

    query: str = Field(..., description="Search string", min_length=2, max_length=200)
    limit: Optional[int] = Field(default=20, ge=1, le=100, description="Max results")
    offset: Optional[int] = Field(default=0, ge=0, description="Pagination offset")
    response_format: ResponseFormat = Field(
        default=ResponseFormat.MARKDOWN,
        description="'markdown' or 'json'"
    )

    @field_validator('query')
    @classmethod
    def validate_query(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Query cannot be empty")
        return v.strip()

@mcp.tool(
    name="example_search_users",
    annotations={
        "title": "Search Example Users",
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": True
    }
)
async def example_search_users(params: UserSearchInput) -> str:
    '''Search for users in the Example system by name, email, or team.

    Args:
        params (UserSearchInput): Validated input parameters.

    Returns:
        str: JSON or Markdown formatted results.
    '''
    try:
        data = await _make_api_request(
            "users/search",
            params={"q": params.query, "limit": params.limit, "offset": params.offset}
        )
        users = data.get("users", [])
        if not users:
            return f"No users found matching '{params.query}'"

        if params.response_format == ResponseFormat.MARKDOWN:
            lines = [f"# Results: '{params.query}'", ""]
            for user in users:
                lines.append(f"## {user['name']} ({user['id']})")
                lines.append(f"- **Email**: {user['email']}")
            return "\n".join(lines)
        else:
            import json
            return json.dumps({"total": data.get("total", 0), "users": users}, indent=2)
    except Exception as e:
        return _handle_api_error(e)
```

## Pydantic v2 Key Features

- Use `model_config` instead of nested `Config` class
- Use `field_validator` (not deprecated `validator`)
- Use `model_dump()` (not deprecated `dict()`)
- Validators require `@classmethod` decorator

## Shared Utilities

```python
async def _make_api_request(endpoint: str, method: str = "GET", **kwargs) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method, f"{API_BASE_URL}/{endpoint}", timeout=30.0, **kwargs
        )
        response.raise_for_status()
        return response.json()

def _handle_api_error(e: Exception) -> str:
    if isinstance(e, httpx.HTTPStatusError):
        if e.response.status_code == 404:
            return "Error: Resource not found. Please check the ID is correct."
        elif e.response.status_code == 403:
            return "Error: Permission denied."
        elif e.response.status_code == 429:
            return "Error: Rate limit exceeded. Please wait before making more requests."
        return f"Error: API request failed with status {e.response.status_code}"
    elif isinstance(e, httpx.TimeoutException):
        return "Error: Request timed out. Please try again."
    return f"Error: {type(e).__name__}: {e}"
```

## Advanced Features

### Context Injection
```python
from mcp.server.fastmcp import FastMCP, Context

@mcp.tool()
async def advanced_tool(query: str, ctx: Context) -> str:
    await ctx.report_progress(0.25, "Starting...")
    await ctx.log_info("Processing", {"query": query})
    results = await search_api(query)
    await ctx.report_progress(1.0, "Done")
    return format_results(results)
```

### Resources
```python
@mcp.resource("file://documents/{name}")
async def get_document(name: str) -> str:
    with open(f"./docs/{name}", "r") as f:
        return f.read()
```

### Transport
```python
# stdio (local) - default
if __name__ == "__main__":
    mcp.run()

# Streamable HTTP (remote)
if __name__ == "__main__":
    mcp.run(transport="streamable_http", port=8000)
```

## Quality Checklist

- [ ] Server name follows `{service}_mcp` format
- [ ] All tools use `@mcp.tool` with `name` and `annotations`
- [ ] Pydantic models use `ConfigDict` with `extra='forbid'`
- [ ] All `@field_validator` methods decorated with `@classmethod`
- [ ] Async/await used for all I/O
- [ ] Common functionality extracted into reusable helpers
- [ ] Pagination implemented where applicable
- [ ] Comprehensive docstrings with input/output schema documentation
