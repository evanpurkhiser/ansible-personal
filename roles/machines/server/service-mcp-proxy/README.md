# MCP proxy metadata

Each service can set optional server metadata when importing this role:

```yaml
mcp_proxy_website_url: https://jellyfin.org
mcp_proxy_instructions: >-
  Search the library before retrieving an item by ID.
mcp_proxy_icons:
  - src: icon.png
    sizes: ["144x144"]
```

Icon `src` values use Ansible's controller-side file search, including the calling
service role's `files/` directory. Absolute paths also work. The play embeds
their bytes as base64 data URIs in the proxy environment. Use small PNG images for
broad client support. `sizes` and `theme` (`light` or `dark`, describing the
background) are optional; an icon without a theme applies to both. Icons default
to an empty list. MIME types are inferred from `.png`, `.jpg`, `.jpeg`, `.svg`,
and `.webp` extensions, ignoring case. Set `mimeType` explicitly for other
extensions or to override inference.

Instructions describe workflows across tools. They apply to the proxy server;
tool descriptions and annotations belong in the backend. Instructions and the
website URL are omitted when empty. A metadata change recreates the container
through the role's environment-file change detection.

Clients choose how to display metadata. OpenAI documents server icons for local
MCP app entrypoints and registered logos for hosted apps; remote connector icon
display requires verification in the target ChatGPT UI.

- [MCP icon metadata](https://modelcontextprotocol.io/specification/2026-07-28/basic#icons)
- [OpenAI entrypoint icons](https://github.com/openai/mcp-extensions/blob/main/docs/spec.md#entrypoint-icons)
