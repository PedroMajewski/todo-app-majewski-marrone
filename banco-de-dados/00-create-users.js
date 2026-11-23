// Usuários do MongoDB com privilégio mínimo (REQ-03):
//  - aplicação: readWrite apenas no banco do ToDo App;
//  - backup: papéis backup/restore, usado pelo mongodump/mongorestore.
//
// Executado na primeira inicialização do container (/docker-entrypoint-initdb.d)
// e pelo Ansible a cada execução da pipeline. Idempotente: só altera o usuário
// quando a senha ou os papéis mudaram (imprime criado/atualizado/inalterado).
// As credenciais vêm de variáveis de ambiente; nada é gravado no código.
const env = typeof process !== 'undefined' ? process.env : {};
const dbName = env.TODO_DB_NAME || 'todo-app';
const admin = db.getSiblingDB('admin');

function rolesKey(roles) {
  return roles.map((r) => `${r.role}@${r.db}`).sort().join(',');
}

function passwordWorks(user, pwd) {
  try {
    const conn = new Mongo('mongodb://127.0.0.1:27017');
    const result = conn.getDB('admin').auth(user, pwd);
    conn.close();
    return Boolean(result && result.ok);
  } catch (err) {
    return false;
  }
}

function upsertUser(user, pwd, roles) {
  if (!user || !pwd) {
    return false;
  }
  const existing = admin.getUser(user);
  if (!existing) {
    admin.createUser({ user, pwd, roles });
    print(`Usuário ${user} criado`);
  } else if (rolesKey(existing.roles) !== rolesKey(roles) || !passwordWorks(user, pwd)) {
    admin.updateUser(user, { pwd, roles });
    print(`Usuário ${user} atualizado`);
  } else {
    print(`Usuário ${user} inalterado`);
  }
  return true;
}

const appUser = upsertUser(env.MONGO_APP_USERNAME, env.MONGO_APP_PASSWORD, [
  { role: 'readWrite', db: dbName },
]);
if (!appUser) {
  print('MONGO_APP_USERNAME/MONGO_APP_PASSWORD não definidos: usuário da aplicação não criado');
}

upsertUser(env.MONGO_BACKUP_USERNAME, env.MONGO_BACKUP_PASSWORD, [
  { role: 'backup', db: 'admin' },
  { role: 'restore', db: 'admin' },
]);
