        ARG UNIC_ID
        ARG SESSION_TIMEOUT
        FROM node:18-alpine
        WORKDIR /app
        COPY . .
        ENV UNIC_ID=${UNIC_ID}
        ENV SESSION_TIMEOUT=${SESSION_TIMEOUT}
        RUN npm install
        EXPOSE 3000
        CMD ["npm", "start"]
