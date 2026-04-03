# 1. Use a 'slim' base image to reduce the attack surface
FROM node:21-slim

# 2. Set the working directory
WORKDIR /usr/src/app

# 3. Patch known vulnerabilities in the OS layer
USER root
RUN apt-get update && apt-get upgrade -y && apt-get clean

# 4. Copy package files first (to leverage Docker cache)
COPY package*.json ./
RUN npm install --only=production

# 5. Copy the rest of the application code
COPY . .

# 6. Switch to a non-root user for better security
USER node

# 7. Document the port
EXPOSE 3000

# 8. Start the app
CMD [ "npm", "start" ]
