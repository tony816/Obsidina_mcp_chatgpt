import os

import uvicorn
from mcp.server.sse import SseServerTransport
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.routing import Mount, Route

from mcp_obsidian.server import app as mcp_app


sse = SseServerTransport("/messages/")


async def handle_sse(request: Request) -> None:
    async with sse.connect_sse(
        request.scope,
        request.receive,
        request._send,
    ) as streams:
        await mcp_app.run(
            streams[0],
            streams[1],
            mcp_app.create_initialization_options(),
        )


starlette_app = Starlette(
    debug=os.getenv("MCP_OBSIDIAN_DEBUG", "").lower() in {"1", "true", "yes"},
    routes=[
        Route("/mcp", endpoint=handle_sse),
        Route("/mcp/", endpoint=handle_sse),
        Route("/sse", endpoint=handle_sse),
        Route("/sse/", endpoint=handle_sse),
        Mount("/messages/", app=sse.handle_post_message),
    ],
)


def main() -> None:
    host = os.getenv("MCP_OBSIDIAN_HTTP_HOST", "127.0.0.1")
    port = int(os.getenv("MCP_OBSIDIAN_HTTP_PORT", "8000"))
    uvicorn.run(starlette_app, host=host, port=port)

