# Seed listings for well-known MCP servers. Package names, endpoints and tool
# lists reflect each project's public documentation at the time of writing;
# treat them as a starting catalogue and verify before relying on them.
#
#     mix run priv/repo/seeds.exs
#
# Seeding is idempotent: existing names are updated, not duplicated.

alias McpRegistry.Registry
alias McpRegistry.Registry.Server
alias McpRegistry.Repo

servers = [
  %{
    name: "io.github.modelcontextprotocol/server-filesystem",
    title: "Filesystem",
    description:
      "Reference server for local file operations, scoped to directories you pass as arguments. Read, write, edit, search and inspect files and directory trees.",
    version: "2025.8.21",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@modelcontextprotocol/server-filesystem",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference files local),
    tools:
      ~w(read_file read_multiple_files write_file edit_file create_directory list_directory directory_tree move_file search_files get_file_info list_allowed_directories)
  },
  %{
    name: "io.github.modelcontextprotocol/server-memory",
    title: "Memory",
    description:
      "Reference knowledge-graph memory server. Persists entities, relations and observations so an agent can remember facts across conversations.",
    version: "2025.8.4",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@modelcontextprotocol/server-memory",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference memory knowledge-graph),
    tools:
      ~w(create_entities create_relations add_observations delete_entities delete_observations delete_relations read_graph search_nodes open_nodes)
  },
  %{
    name: "io.github.modelcontextprotocol/server-sequential-thinking",
    title: "Sequential Thinking",
    description:
      "Reference server that gives a model a structured scratchpad for step-by-step problem solving, with revision and branching of earlier thoughts.",
    version: "2025.7.1",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@modelcontextprotocol/server-sequential-thinking",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference reasoning),
    tools: ~w(sequentialthinking)
  },
  %{
    name: "io.github.modelcontextprotocol/server-everything",
    title: "Everything",
    description:
      "Reference test server that exercises every MCP feature: tools, resources, prompts, sampling, logging and progress. Useful for testing clients, not for production.",
    version: "2025.9.12",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@modelcontextprotocol/server-everything",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference testing),
    tools:
      ~w(echo add longRunningOperation printEnv sampleLLM getTinyImage annotatedMessage getResourceReference)
  },
  %{
    name: "io.github.modelcontextprotocol/fetch",
    title: "Fetch",
    description:
      "Reference server that fetches a URL and converts the page to markdown for a model to read, with optional raw mode and pagination through long pages.",
    version: "2025.4.7",
    transport: "stdio",
    package_registry: "pypi",
    package_identifier: "mcp-server-fetch",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference web http),
    tools: ~w(fetch)
  },
  %{
    name: "io.github.modelcontextprotocol/git",
    title: "Git",
    description:
      "Reference server for reading, searching and manipulating local Git repositories: status, diffs, log, commits, branches and checkouts.",
    version: "2025.7.1",
    transport: "stdio",
    package_registry: "pypi",
    package_identifier: "mcp-server-git",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference git developer-tools),
    tools:
      ~w(git_status git_diff_unstaged git_diff_staged git_diff git_commit git_add git_reset git_log git_create_branch git_checkout git_show git_init)
  },
  %{
    name: "io.github.modelcontextprotocol/time",
    title: "Time",
    description:
      "Reference server for current time and time-zone conversion, so a model can answer 'what time is it in Tokyo' without guessing.",
    version: "2025.8.4",
    transport: "stdio",
    package_registry: "pypi",
    package_identifier: "mcp-server-time",
    repository_url: "https://github.com/modelcontextprotocol/servers",
    license: "MIT",
    tags: ~w(reference time utilities),
    tools: ~w(get_current_time convert_time)
  },
  %{
    name: "io.github.github/github-mcp-server",
    title: "GitHub",
    description:
      "GitHub's official MCP server. The hosted endpoint authenticates with OAuth or a personal access token; the same server also ships as a Docker image for local use.",
    version: "0.18.0",
    transport: "streamable-http",
    remote_url: "https://api.githubcopilot.com/mcp/",
    package_registry: "oci",
    package_identifier: "ghcr.io/github/github-mcp-server",
    env_vars: ~w(GITHUB_PERSONAL_ACCESS_TOKEN),
    repository_url: "https://github.com/github/github-mcp-server",
    website_url: "https://github.com/github/github-mcp-server",
    license: "MIT",
    tags: ~w(github git developer-tools issues pull-requests),
    tools:
      ~w(get_me search_repositories get_file_contents list_issues create_issue list_pull_requests create_pull_request get_pull_request_diff search_code list_commits)
  },
  %{
    name: "io.github.microsoft/playwright-mcp",
    title: "Playwright",
    description:
      "Browser automation from Microsoft's Playwright team. Drives a real browser through accessibility snapshots rather than screenshots, so a model can navigate, click, type and read pages.",
    version: "0.0.40",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@playwright/mcp",
    repository_url: "https://github.com/microsoft/playwright-mcp",
    license: "Apache-2.0",
    tags: ~w(browser automation testing web),
    tools:
      ~w(browser_navigate browser_snapshot browser_click browser_type browser_take_screenshot browser_tab_list browser_console_messages browser_network_requests)
  },
  %{
    name: "io.github.upstash/context7",
    title: "Context7",
    description:
      "Up-to-date, version-specific library documentation and code examples pulled straight into the prompt, so generated code matches the API that actually exists.",
    version: "1.0.20",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@upstash/context7-mcp",
    repository_url: "https://github.com/upstash/context7",
    website_url: "https://context7.com",
    license: "MIT",
    tags: ~w(documentation developer-tools coding),
    tools: ~w(resolve-library-id get-library-docs)
  },
  %{
    name: "com.brave/brave-search",
    title: "Brave Search",
    description:
      "Web, local, news, image and video search through the Brave Search API. Needs an API key from the Brave developer portal.",
    version: "2.0.0",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@brave/brave-search-mcp-server",
    env_vars: ~w(BRAVE_API_KEY),
    repository_url: "https://github.com/brave/brave-search-mcp-server",
    website_url: "https://brave.com/search/api/",
    license: "MIT",
    tags: ~w(search web news),
    tools:
      ~w(brave_web_search brave_local_search brave_news_search brave_image_search brave_video_search)
  },
  %{
    name: "com.supabase/mcp-server-supabase",
    title: "Supabase",
    description:
      "Manage Supabase projects from an agent: run SQL, inspect schemas, apply migrations, read logs and deploy edge functions. Scope it to one project and read-only mode where you can.",
    version: "0.5.0",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "@supabase/mcp-server-supabase",
    env_vars: ~w(SUPABASE_ACCESS_TOKEN),
    repository_url: "https://github.com/supabase-community/supabase-mcp",
    website_url: "https://supabase.com/docs/guides/getting-started/mcp",
    license: "Apache-2.0",
    tags: ~w(database postgres backend),
    tools:
      ~w(list_projects get_project list_tables execute_sql apply_migration get_logs deploy_edge_function generate_typescript_types)
  },
  %{
    name: "com.notion/mcp",
    title: "Notion",
    description:
      "Notion's hosted MCP server. Search, read and write pages and databases in a workspace after an OAuth sign-in; no local install.",
    version: "1.0.0",
    transport: "streamable-http",
    remote_url: "https://mcp.notion.com/mcp",
    website_url: "https://developers.notion.com/docs/mcp",
    tags: ~w(notes documents productivity hosted),
    tools:
      ~w(notion-search notion-fetch notion-create-pages notion-update-page notion-create-comment)
  },
  %{
    name: "com.linear/mcp",
    title: "Linear",
    description:
      "Linear's hosted MCP server for issues, projects, cycles and comments. Authenticates with OAuth on first connection.",
    version: "1.0.0",
    transport: "streamable-http",
    remote_url: "https://mcp.linear.app/mcp",
    website_url: "https://linear.app/docs/mcp",
    tags: ~w(issues project-management hosted),
    tools:
      ~w(list_issues get_issue create_issue update_issue list_projects list_teams list_comments create_comment)
  },
  %{
    name: "com.sentry/mcp",
    title: "Sentry",
    description:
      "Sentry's hosted MCP server. Look up issues, errors, traces and performance data for your projects and hand the context to an agent fixing the bug.",
    version: "0.17.0",
    transport: "streamable-http",
    remote_url: "https://mcp.sentry.dev/mcp",
    repository_url: "https://github.com/getsentry/sentry-mcp",
    website_url: "https://docs.sentry.io/product/sentry-mcp/",
    license: "Apache-2.0",
    tags: ~w(errors monitoring observability hosted),
    tools:
      ~w(find_organizations find_projects find_issues get_issue_details search_events get_trace_details)
  },
  %{
    name: "com.stripe/mcp",
    title: "Stripe",
    description:
      "Stripe's hosted MCP server plus documentation search. Create customers, products, prices, payment links and invoices, and query the Stripe docs.",
    version: "0.2.0",
    transport: "streamable-http",
    remote_url: "https://mcp.stripe.com",
    repository_url: "https://github.com/stripe/agent-toolkit",
    website_url: "https://docs.stripe.com/mcp",
    license: "MIT",
    tags: ~w(payments billing hosted),
    tools:
      ~w(search_stripe_documentation create_customer list_customers create_product create_price create_payment_link create_invoice retrieve_balance)
  },
  %{
    name: "com.cloudflare/docs",
    title: "Cloudflare Docs",
    description:
      "Cloudflare's hosted documentation server. Searches developers.cloudflare.com so answers about Workers, R2, D1 and the rest cite current docs.",
    version: "1.0.0",
    transport: "streamable-http",
    remote_url: "https://docs.mcp.cloudflare.com/mcp",
    repository_url: "https://github.com/cloudflare/mcp-server-cloudflare",
    website_url:
      "https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/",
    license: "Apache-2.0",
    tags: ~w(documentation cloudflare hosted),
    tools: ~w(search_cloudflare_documentation migrate_pages_to_workers_guide)
  },
  %{
    name: "com.deepwiki/mcp",
    title: "DeepWiki",
    description:
      "Hosted server from Cognition that answers questions about any public GitHub repository using DeepWiki's generated documentation. No authentication required.",
    version: "1.0.0",
    transport: "streamable-http",
    remote_url: "https://mcp.deepwiki.com/mcp",
    website_url: "https://docs.devin.ai/work-with-devin/deepwiki-mcp",
    tags: ~w(documentation github code-understanding hosted),
    tools: ~w(read_wiki_structure read_wiki_contents ask_question)
  },
  %{
    name: "com.huggingface/mcp",
    title: "Hugging Face",
    description:
      "Hugging Face's hosted MCP server. Search models, datasets, papers and Spaces on the Hub, and run selected Spaces as tools.",
    version: "1.0.0",
    transport: "streamable-http",
    remote_url: "https://huggingface.co/mcp",
    website_url: "https://huggingface.co/settings/mcp",
    tags: ~w(machine-learning models datasets hosted),
    tools:
      ~w(hf_whoami space_search model_search model_details paper_search dataset_search dataset_details hub_repo_details)
  },
  %{
    name: "io.github.exa-labs/exa-mcp-server",
    title: "Exa Search",
    description:
      "Neural web search built for agents: web search with live crawling, code-context search, company research and page crawling. Needs an Exa API key.",
    version: "3.0.0",
    transport: "stdio",
    package_registry: "npm",
    package_identifier: "exa-mcp-server",
    env_vars: ~w(EXA_API_KEY),
    repository_url: "https://github.com/exa-labs/exa-mcp-server",
    website_url: "https://exa.ai",
    license: "MIT",
    tags: ~w(search web research),
    tools: ~w(web_search_exa get_code_context_exa company_research_exa crawling_exa)
  }
]

for attrs <- servers do
  case Repo.get_by(Server, name: attrs.name) do
    nil ->
      {:ok, _} = Registry.create_server(attrs, status: "active", source: "seed", origin: "seed")

    server ->
      {:ok, _} = Registry.update_server(server, Map.put(attrs, :status, "active"))
  end
end

IO.puts("Seeded #{length(servers)} servers.")
