CREATE DATABASE IF NOT EXISTS taskdb;
USE taskdb;

CREATE TABLE IF NOT EXISTS tasks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status ENUM('pending', 'in_progress', 'completed') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO tasks (title, description, status) VALUES
('Set up Docker environment', 'Configure Docker and Docker Compose for the project', 'completed'),
('Deploy to AWS ECS', 'Push Docker image to ECR and deploy to ECS Fargate', 'in_progress'),
('Write documentation', 'Write complete README and API documentation', 'pending');
