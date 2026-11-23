// Testes da API com o executor nativo do Node (node --test), sem dependências extras.
// - Sem MONGO_URI_TEST: valida apenas que /health responde 503 sem banco.
// - Com MONGO_URI_TEST (no CI há um MongoDB como serviço): valida o fluxo completo.
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const { app, connectWithRetry } = require('../index');

const mongoUriTest = process.env.MONGO_URI_TEST;
let server;
let baseUrl;

const request = async (method, path, body) => {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
};

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (mongoose.connection.readyState === 1) {
    await mongoose.connection.dropDatabase();
  }
  await mongoose.disconnect();
  await new Promise((resolve) => server.close(resolve));
});

test('GET /health retorna 503 enquanto não há conexão com o banco', async () => {
  const res = await request('GET', '/health');
  assert.equal(res.status, 503);
  assert.equal(res.body.database, 'down');
});

test('fluxo completo de tarefas (cadastrar, listar, concluir, reabrir, excluir)', {
  skip: !mongoUriTest && 'MONGO_URI_TEST não definida',
}, async () => {
  await connectWithRetry(mongoUriTest);

  const health = await request('GET', '/health');
  assert.equal(health.status, 200);
  assert.equal(health.body.database, 'up');

  const invalid = await request('POST', '/todos', {});
  assert.equal(invalid.status, 400);

  const created = await request('POST', '/todos', { text: 'Tarefa de teste' });
  assert.equal(created.status, 201);
  assert.equal(created.body.completed, false);
  const id = created.body._id;

  const list = await request('GET', '/todos');
  assert.equal(list.status, 200);
  assert.ok(list.body.some((todo) => todo._id === id));

  const done = await request('PATCH', `/todos/${id}`);
  assert.equal(done.status, 200);
  assert.equal(done.body.completed, true);

  const reopened = await request('PATCH', `/todos/${id}`);
  assert.equal(reopened.body.completed, false);

  const removed = await request('DELETE', `/todos/${id}`);
  assert.equal(removed.status, 200);

  const missing = await request('DELETE', `/todos/${id}`);
  assert.equal(missing.status, 404);
});
