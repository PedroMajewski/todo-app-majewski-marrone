FROM node:22-alpine

ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="todo-api" \
      org.opencontainers.image.version=$APP_VERSION

ENV NODE_ENV=production \
    PORT=5000 \
    APP_VERSION=$APP_VERSION

# Definindo o diretório de trabalho dentro do container
WORKDIR /app

# Instalando apenas as dependências de produção, exatamente como no package-lock.json
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

# Copiando o restante do conteúdo do projeto para o container
COPY . .

# Executa como usuário sem privilégios
USER node

# Expondo a porta que o backend vai usar (5000)
EXPOSE 5000

# Saudável apenas quando a API responde E está conectada ao MongoDB (/health)
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||5000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Comando para rodar a aplicação
CMD ["node", "index.js"]
