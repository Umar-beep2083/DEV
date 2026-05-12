import json


def test_health_check(client):
    response = client.get('/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert data['app'] == 'Flask DevOps App'


def test_health_detailed(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'database' in data


def test_get_tasks_returns_list(client):
    response = client.get('/tasks')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert isinstance(data, list)


def test_create_task(client):
    payload = {'title': 'Test task', 'description': 'A test description'}
    response = client.post(
        '/tasks',
        data=json.dumps(payload),
        content_type='application/json',
    )
    assert response.status_code == 201
    data = json.loads(response.data)
    assert data['id'] is not None
    assert data['title'] == 'Test task'
    assert data['status'] == 'pending'


def test_update_and_delete_task(client):
    # Create
    response = client.post(
        '/tasks',
        data=json.dumps({'title': 'To update'}),
        content_type='application/json',
    )
    task_id = json.loads(response.data)['id']

    # Update
    response = client.put(
        f'/tasks/{task_id}',
        data=json.dumps({'status': 'completed'}),
        content_type='application/json',
    )
    assert response.status_code == 200
    assert json.loads(response.data)['status'] == 'completed'

    # Delete
    response = client.delete(f'/tasks/{task_id}')
    assert response.status_code == 200

    # Verify gone
    response = client.delete(f'/tasks/{task_id}')
    assert response.status_code == 404
