const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bodyParser = require('body-parser');

// Configuração por variáveis de ambiente: nenhum endereço ou credencial fica no código.
const port = Number(process.env.PORT) || 5000;
const mongoUri = process.env.MONGO_URI;
const appVersion = process.env.APP_VERSION || 'dev';
// Lista de origens permitidas, separadas por vírgula. Vazia = CORS desligado
// (a interface e a API são servidas pelo mesmo endereço através do Nginx).
const corsOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

// Inicializando o app Express
const app = express();
app.disable('x-powered-by');

// Middleware para CORS restrito e processamento de JSON
if (corsOrigins.length > 0) {
  app.use(cors({ origin: corsOrigins }));
}
app.use(bodyParser.json());

// Definindo o modelo de Tarefa (To-do)
const TodoSchema = new mongoose.Schema({
  text: { type: String, required: true },
  completed: { type: Boolean, default: false },
});

const Todo = mongoose.models.Todo || mongoose.model('Todo', TodoSchema);

// Verificação de saúde: confirma que a API está no ar E conectada ao banco.
// Retorna 503 enquanto o MongoDB estiver indisponível.
app.get('/health', async (req, res) => {
  let database = 'down';
  if (mongoose.connection.readyState === 1) {
    try {
      await Promise.race([
        mongoose.connection.db.command({ ping: 1 }),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000)),
      ]);
      database = 'up';
    } catch (err) {
      database = 'down';
    }
  }
  const healthy = database === 'up';
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    database,
    version: appVersion,
    uptime: Math.round(process.uptime()),
  });
});

// Rota para obter todas as tarefas (GET)
app.get('/todos', async (req, res) => {
  try {
    const todos = await Todo.find(); // Retorna todas as tarefas do banco
    res.json(todos);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Rota para adicionar uma nova tarefa (POST)
app.post('/todos', async (req, res) => {
  const { text } = req.body; // Obtém o texto da tarefa do corpo da requisição

  // Verifica se o campo "text" está presente
  if (!text) {
    return res.status(400).json({ message: 'O campo "text" é obrigatório' });
  }

  const todo = new Todo({
    text,
    completed: false,
  });

  try {
    const newTodo = await todo.save(); // Salva a tarefa no banco
    res.status(201).json(newTodo); // Retorna a tarefa criada
  } catch (err) {
    res.status(400).json({ message: err.message }); // Retorna erro se houver falha no banco de dados
  }
});

// Rota para marcar uma tarefa como concluída (PATCH)
app.patch('/todos/:id', async (req, res) => {
  try {
    const todo = await Todo.findById(req.params.id); // Encontra a tarefa pelo ID

    if (!todo) {
      return res.status(404).json({ message: 'Tarefa não encontrada' });
    }

    // Alterna o status de "completed" da tarefa
    todo.completed = !todo.completed;
    await todo.save(); // Salva a tarefa modificada
    res.json(todo); // Retorna a tarefa atualizada
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Rota para excluir uma tarefa (DELETE)
app.delete('/todos/:id', async (req, res) => {
  try {
    const todo = await Todo.findByIdAndDelete(req.params.id); // Deleta a tarefa pelo ID

    if (!todo) {
      return res.status(404).json({ message: 'Tarefa não encontrada' });
    }

    res.json({ message: 'Tarefa excluída com sucesso' }); // Retorna uma mensagem de sucesso
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Conexão com o MongoDB com novas tentativas (backoff exponencial até 30 s).
// A API sobe mesmo sem o banco; /health indica 503 até a conexão ser estabelecida.
// A URI nunca é escrita nos logs, pois contém a senha.
async function connectWithRetry(uri = mongoUri) {
  if (!uri) {
    throw new Error('Variável MONGO_URI não definida');
  }
  for (let attempt = 1; ; attempt += 1) {
    try {
      await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
      console.log('Conectado ao MongoDB');
      return;
    } catch (err) {
      const delay = Math.min(30000, 1000 * 2 ** Math.min(attempt, 5));
      console.error(
        `Erro ao conectar ao MongoDB (tentativa ${attempt}): ${err.message}. ` +
          `Nova tentativa em ${delay / 1000}s`,
      );
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
}

let wasConnected = false;
mongoose.connection.on('connected', () => {
  wasConnected = true;
});
mongoose.connection.on('disconnected', () => {
  if (wasConnected) console.warn('Conexão com o MongoDB perdida');
});
mongoose.connection.on('reconnected', () => console.log('Reconectado ao MongoDB'));

function start() {
  if (!mongoUri) {
    console.error('Variável MONGO_URI não definida. Encerrando.');
    process.exit(1);
  }

  // Iniciando o servidor na porta configurada
  const server = app.listen(port, () => {
    console.log(`Servidor rodando na porta ${port} (versão ${appVersion})`);
  });

  connectWithRetry().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });

  // Encerramento gracioso: o Docker envia SIGTERM ao parar/atualizar o container.
  const shutdown = (signal) => {
    console.log(`${signal} recebido, encerrando...`);
    server.close(() => {
      mongoose.disconnect().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  return server;
}

if (require.main === module) {
  start();
}

module.exports = { app, connectWithRetry };
