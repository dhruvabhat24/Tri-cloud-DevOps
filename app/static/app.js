const form = document.querySelector('#task-form');
const titleInput = document.querySelector('#title');
const tasksElement = document.querySelector('#tasks');
const emptyElement = document.querySelector('#empty');
const messageElement = document.querySelector('#message');
const runtimeElement = document.querySelector('#runtime');
const refreshButton = document.querySelector('#refresh');

async function request(url, options = {}) {
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options,
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({ detail: response.statusText }));
    throw new Error(body.detail || 'Request failed');
  }
  return response.status === 204 ? null : response.json();
}

function taskNode(task) {
  const item = document.createElement('li');
  item.className = task.completed ? 'task completed' : 'task';

  const label = document.createElement('label');
  const checkbox = document.createElement('input');
  checkbox.type = 'checkbox';
  checkbox.checked = task.completed;
  checkbox.addEventListener('change', async () => {
    try {
      await request(`/api/tasks/${task.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ completed: checkbox.checked }),
      });
      await loadTasks();
    } catch (error) {
      showMessage(error.message, true);
    }
  });

  const text = document.createElement('span');
  text.textContent = task.title;
  label.append(checkbox, text);

  const remove = document.createElement('button');
  remove.type = 'button';
  remove.className = 'danger';
  remove.textContent = 'Delete';
  remove.addEventListener('click', async () => {
    try {
      await request(`/api/tasks/${task.id}`, { method: 'DELETE' });
      await loadTasks();
    } catch (error) {
      showMessage(error.message, true);
    }
  });

  item.append(label, remove);
  return item;
}

function showMessage(text, isError = false) {
  messageElement.textContent = text;
  messageElement.className = isError ? 'error' : 'success';
}

async function loadTasks() {
  const tasks = await request('/api/tasks');
  tasksElement.replaceChildren(...tasks.map(taskNode));
  emptyElement.hidden = tasks.length !== 0;
}

async function loadInfo() {
  const info = await request('/api/info');
  runtimeElement.textContent = `${info.deployment_target} · ${info.store_backend} · version ${info.version}`;
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  try {
    await request('/api/tasks', {
      method: 'POST',
      body: JSON.stringify({ title: titleInput.value }),
    });
    titleInput.value = '';
    showMessage('Task added.');
    await loadTasks();
  } catch (error) {
    showMessage(error.message, true);
  }
});

refreshButton.addEventListener('click', () => loadTasks().catch((error) => showMessage(error.message, true)));

Promise.all([loadInfo(), loadTasks()]).catch((error) => showMessage(error.message, true));
