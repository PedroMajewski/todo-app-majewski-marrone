# Etapa 1: Construção da aplicação
FROM node:22-alpine AS build

# Definindo o diretório de trabalho dentro do container
WORKDIR /app

# Instalando as dependências exatamente como no package-lock.json
COPY package*.json ./
RUN npm ci --no-audit --no-fund

# Copiando todo o conteúdo da pasta do projeto para o container
COPY . .

# Endereço da API usado pelo navegador. Vazio = mesmo endereço da interface (/todos).
ARG REACT_APP_API_URL=""
ENV REACT_APP_API_URL=$REACT_APP_API_URL

# Construindo a aplicação para produção
RUN npm run build

# Etapa 2: Servindo a aplicação com Nginx (versão estável fixa)
FROM nginx:1.30-alpine

ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="todo-frontend" \
      org.opencontainers.image.version=$APP_VERSION

# Destino da API dentro da rede Docker (nome do container/alias e porta)
ENV API_UPSTREAM=api:5000 \
    APP_VERSION=$APP_VERSION

# Configuração do Nginx (template processado na inicialização do container)
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Copiando o build da etapa anterior para o diretório padrão do Nginx
COPY --from=build /app/build /usr/share/nginx/html
RUN printf '{"version":"%s"}\n' "$APP_VERSION" > /usr/share/nginx/html/version.json

# Expondo a porta 80 para acesso à aplicação
EXPOSE 80

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/nginx-health || exit 1

# Comando para iniciar o Nginx e servir a aplicação
CMD ["nginx", "-g", "daemon off;"]
