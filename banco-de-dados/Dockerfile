# Imagem usada apenas na execução local (Docker Compose).
# Na nuvem, o Ansible usa a imagem oficial mongo:<versão> e monta estes mesmos scripts.
FROM mongo:8.0.38

# Scripts executados na primeira inicialização (volume de dados vazio), em ordem alfabética:
# 00-create-users.js (usuários da aplicação e de backup) e init-mongo.js (dados de demonstração)
COPY ./00-create-users.js ./init-mongo.js /docker-entrypoint-initdb.d/

EXPOSE 27017
