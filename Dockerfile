FROM node:18-slim

WORKDIR /app

RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/*

RUN wget https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACCAP1-1-91571/1-lab-capstone-project-1/code.zip \
    && unzip code.zip -x "resources/codebase_partner/node_modules/*" \
    && rm code.zip

WORKDIR /app/resources/codebase_partner

RUN npm install aws aws-sdk

EXPOSE 80

ENV APP_PORT=80

CMD ["npm", "start"]
