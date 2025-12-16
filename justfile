# Start all services in background with build
start:
    docker compose -f compose.yaml up --build -d

# Stop all services
stop:
    docker compose -f compose.yaml down

# View logs
logs:
    docker compose -f compose.yaml logs -f

# Rebuild and restart
restart:
    docker compose -f compose.yaml down
    docker compose -f compose.yaml up --build -d
