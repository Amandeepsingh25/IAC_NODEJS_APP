# Stage 1: Copy the application files
FROM node:14 AS app

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the working directory
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code to the working directory
COPY . .

# Stage 2: Create the final image using Alpine Linux
FROM node:14-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy only the built artifacts from the previous stage
COPY --from=app /usr/src/app .

# Install multilevel package globally (if needed)
RUN npm install -g multilevel

# Expose port 3000
EXPOSE 3000

# Command to run the application
CMD ["node", "app.js"]
