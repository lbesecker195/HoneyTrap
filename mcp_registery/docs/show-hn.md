# Show HN draft

Post at https://news.ycombinator.com/submit once https://ai.mcpharbor.dev is
live and has been checked end to end. Hacker News expects a Show HN to be
something people can try right away, so post only after launch.

**Title** (80 characters max)

    Show HN: An open registry of MCP servers that agents can query

**URL**

    https://ai.mcpharbor.dev

**First comment** (post as a reply to your own submission)

    Hi HN. I built this because finding a Model Context Protocol server
    for a job usually means digging through GitHub lists and READMEs, and
    agents can't do that well.

    It's a small Phoenix/LiveView app. People can search by name, tag, or the
    names of the tools a server exposes, and every listing shows copy-paste
    config for Claude Code and any mcpServers-style client (Claude Desktop,
    Cursor, VS Code). Agents get a plain JSON API at /api/v0/servers and a
    /llms.txt that explains how to search, install, and publish. Listings use
    the same server.json manifest format as the official MCP registry, so
    there's nothing new to learn if you already publish there.

    Anyone can submit a server through a form; submissions are reviewed before
    they show up in search. It starts with about twenty well-known servers.

    For analytics I'm using Seriously Simple Analytics, which is free and can
    count API calls from agents as well as page views, which matters for a site
    whose main readers never run JavaScript.

    I'd love feedback on what metadata would help you pick a server: auth
    requirements, maintenance signals, security notes, something else?
