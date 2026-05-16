# Firefly III

Firefly III in this repo is configured for authentik remote-user authentication.

Relevant environment variables are rendered from Ansible into `docker/.env`:

- `AUTHENTICATION_GUARD=remote_user_guard`
- `AUTHENTICATION_GUARD_HEADER=HTTP_X_AUTHENTIK_EMAIL`
- `AUTHENTICATION_GUARD_EMAIL=HTTP_X_AUTHENTIK_EMAIL`

Authentik should be configured with a Proxy Provider for Firefly and should forward the authenticated user's email header to Firefly. Set the authentik Docker integration's `docker_network` to `homelab-network` so the outpost container joins the shared bridge.

Notes:

- Firefly uses the email address as the user identifier in this setup.
- If you enable authentik-backed login, disable Firefly's own MFA flow so authentik remains the source of authentication.
- The Firefly app container is still published on port `82`, but the preferred internal host is the Firefly container name on `homelab-network` once the outpost is attached to that shared bridge, for example `http://firefly-app-1:8080`.
