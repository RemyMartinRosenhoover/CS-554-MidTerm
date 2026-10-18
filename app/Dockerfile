# One image, two environments. Configuration (PORT, SERVICE_NAME, MESSAGE) is
# injected at run time by Compose or Kubernetes, never baked in here.
FROM node:22-alpine

WORKDIR /app

# The service has no dependencies, so there is no npm install step: only the
# package manifest (for `npm start`) and the source are copied.
COPY package.json ./
COPY src ./src

# Run as the unprivileged user the base image provides.
USER node

# Documents the default listening port; PORT at run time can override it.
EXPOSE 8080

# Exec form so the Node process is PID 1 and receives SIGTERM directly;
# src/server.js handles SIGTERM/SIGINT with a graceful shutdown.
CMD ["node", "src/server.js"]
