DROP DATABASE IF EXISTS GPS_db;
CREATE DATABASE GPS_db CHARACTER SET utf8mb4;

USE GPS_db;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    pswd_hash VARCHAR(255) NOT NULL
);

CREATE TABLE saved_locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    label VARCHAR(50) NOT NULL,
    address VARCHAR(255),
--    latitude DECIMAL(10, 8) NOT NULL,
--    longitude DECIMAL(11, 8) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE incident_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(50) NOT NULL
);

CREATE TABLE incidents (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    type_id INT NOT NULL,
--    latitude DECIMAL(10, 8) NOT NULL,
--    longitude DECIMAL(11, 8) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (type_id) REFERENCES incident_types(id)
);


INSERT INTO incident_types (label) VALUES ('Accident'), ('Bouchon'), ('Travaux'), ('Danger'), ('Obstacle sur la route'), ('Véhicule arrêté'), ('Radar'), ('Police'), ('Brouillard'), ('Voie de droite bloquée'), ('Voie de gauche bloquée');
