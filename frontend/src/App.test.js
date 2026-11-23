import { render, screen, fireEvent } from '@testing-library/react';
import axios from 'axios';
import App from './App';

// O axios é substituído por funções simuladas: o teste não depende da API.
jest.mock('axios', () => ({
  __esModule: true,
  default: { get: jest.fn(), post: jest.fn(), patch: jest.fn(), delete: jest.fn() },
}));

test('carrega as tarefas pela rota relativa /todos', async () => {
  axios.get.mockResolvedValue({ data: [{ _id: '1', text: 'Estudar Cloud', completed: true }] });

  render(<App />);

  expect(screen.getByText('Lista de Tarefas')).toBeInTheDocument();
  expect(await screen.findByText('Estudar Cloud')).toBeInTheDocument();
  expect(axios.get).toHaveBeenCalledWith('/todos');
});

test('adiciona uma tarefa enviando POST para /todos', async () => {
  axios.get.mockResolvedValue({ data: [] });
  axios.post.mockResolvedValue({ data: { _id: '2', text: 'Nova tarefa', completed: false } });

  render(<App />);
  fireEvent.change(screen.getByPlaceholderText('Adicione uma tarefa'), {
    target: { value: 'Nova tarefa' },
  });
  fireEvent.click(screen.getByText('Adicionar'));

  expect(await screen.findByText('Nova tarefa')).toBeInTheDocument();
  expect(axios.post).toHaveBeenCalledWith('/todos', { text: 'Nova tarefa' });
});

test('exibe aviso quando a API está indisponível', async () => {
  axios.get.mockRejectedValue(new Error('Network Error'));

  render(<App />);

  expect(await screen.findByRole('alert')).toHaveTextContent('Não foi possível carregar as tarefas');
});
