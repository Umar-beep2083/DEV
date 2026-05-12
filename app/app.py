import os
from flask import Flask
from extensions import db
from models import Task  # noqa: F401 — registers model with SQLAlchemy metadata
from routes import tasks_bp


def create_app(config=None):
    flask_app = Flask(__name__)

    flask_app.config.update({
        'SQLALCHEMY_DATABASE_URI': (
            'mysql+pymysql://{user}:{pw}@{host}:{port}/{name}'.format(
                user=os.environ.get('DB_USER', 'flaskuser'),
                pw=os.environ.get('DB_PASSWORD', 'flaskpassword'),
                host=os.environ.get('DB_HOST', 'localhost'),
                port=os.environ.get('DB_PORT', '3306'),
                name=os.environ.get('DB_NAME', 'taskdb'),
            )
        ),
        'SQLALCHEMY_TRACK_MODIFICATIONS': False,
        'SECRET_KEY': os.environ.get('SECRET_KEY', 'dev-key-change-in-prod'),
    })

    if config:
        flask_app.config.update(config)

    db.init_app(flask_app)
    flask_app.register_blueprint(tasks_bp)

    with flask_app.app_context():
        db.create_all()

    return flask_app
