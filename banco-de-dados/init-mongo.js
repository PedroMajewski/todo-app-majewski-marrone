// Dados de demonstração do ToDo App.
//
// Executado:
//  - automaticamente pelo container oficial do MongoDB na primeira inicialização
//    (pasta /docker-entrypoint-initdb.d), tanto no Compose local quanto na VM;
//  - pela rotina "reset-demo-list" da pipeline de operações, com RESET_DEMO=true,
//    para preparar uma lista nova antes de cada apresentação.
//
// Idempotente: só insere os dados quando a coleção está vazia.
const env = typeof process !== 'undefined' ? process.env : {};
const dbName = env.TODO_DB_NAME || 'todo-app';
const reset = env.RESET_DEMO === 'true';

const todoDb = db.getSiblingDB(dbName);

if (!todoDb.getCollectionNames().includes('todos')) {
  todoDb.createCollection('todos');
}

if (reset) {
  const result = todoDb.todos.deleteMany({});
  print(`Lista limpa: ${result.deletedCount} tarefa(s) removida(s)`);
}

if (todoDb.todos.countDocuments() === 0) {
  todoDb.todos.insertMany([
    { text: "Laércio é um excelente professor", completed: false },
    { text: "Estudar Cloud", completed: true },
    { text: "Fazer exercícios da UA", completed: false },
  ]);
  print(`Dados de demonstração inseridos em ${dbName}.todos`);
} else {
  print(`${dbName}.todos já possui tarefas; dados de demonstração não inseridos`);
}
