# Using Node 24 
FROM node:24-slim

WORKDIR /usr/src/app

# Copy package files and install
COPY package*.json ./
RUN npm install

# Copy the rest of the code
COPY . .

# We EXPOSE 3000 because CODE uses 3000
EXPOSE 3000

CMD [ "npm", "start" ]
