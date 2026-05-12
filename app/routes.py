from flask import Blueprint, jsonify, request
from extensions import db
from models import Task, TaskStatus

tasks_bp = Blueprint('tasks', __name__)


@tasks_bp.route('/')
def health_check():
    return jsonify({'status': 'healthy', 'app': 'Flask DevOps App'}), 200


@tasks_bp.route('/health')
def health_detailed():
    db_status = 'connected'
    try:
        db.session.execute(db.text('SELECT 1'))
    except Exception as e:
        db_status = f'error: {str(e)}'
    return jsonify({
        'status': 'healthy',
        'app': 'Flask DevOps App',
        'database': db_status,
    }), 200


@tasks_bp.route('/tasks', methods=['GET'])
def get_tasks():
    tasks = Task.query.all()
    return jsonify([t.to_dict() for t in tasks]), 200


@tasks_bp.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or not data.get('title'):
        return jsonify({'error': 'title is required'}), 400
    status_val = data.get('status', 'pending')
    try:
        status = TaskStatus(status_val)
    except ValueError:
        return jsonify({'error': f'invalid status: {status_val}'}), 400
    task = Task(
        title=data['title'],
        description=data.get('description'),
        status=status,
    )
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@tasks_bp.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    task = Task.query.get(task_id)
    if not task:
        return jsonify({'error': 'task not found'}), 404
    data = request.get_json()
    if not data:
        return jsonify({'error': 'request body required'}), 400
    if 'title' in data:
        task.title = data['title']
    if 'description' in data:
        task.description = data['description']
    if 'status' in data:
        try:
            task.status = TaskStatus(data['status'])
        except ValueError:
            return jsonify({'error': f'invalid status: {data["status"]}'}), 400
    db.session.commit()
    return jsonify(task.to_dict()), 200


@tasks_bp.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    task = Task.query.get(task_id)
    if not task:
        return jsonify({'error': 'task not found'}), 404
    db.session.delete(task)
    db.session.commit()
    return jsonify({'message': f'task {task_id} deleted'}), 200
