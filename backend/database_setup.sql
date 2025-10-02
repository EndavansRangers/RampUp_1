-- Script para crear la base de datos de Tunefy
-- Este script debe ejecutarse en PostgreSQL

-- Crear la base de datos (opcional, si no existe)
-- CREATE DATABASE tunefy;

-- Conectarse a la base de datos tunefy
-- \c tunefy;

-- Tabla principal para almacenar todas las canciones mezcladas
CREATE TABLE IF NOT EXISTS merged_songs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    song_name VARCHAR(500) NOT NULL,
    artist_name VARCHAR(500) NOT NULL,
    popularity INTEGER DEFAULT 0,
    votes INTEGER DEFAULT 0,
    session_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla para almacenar las canciones más populares (top 20)
CREATE TABLE IF NOT EXISTS top_songs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    song_name VARCHAR(500) NOT NULL,
    artist_name VARCHAR(500) NOT NULL,
    popularity INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_merged_songs_user_id ON merged_songs(user_id);
CREATE INDEX IF NOT EXISTS idx_merged_songs_popularity ON merged_songs(popularity);
CREATE INDEX IF NOT EXISTS idx_merged_songs_votes ON merged_songs(votes);
CREATE INDEX IF NOT EXISTS idx_merged_songs_song_name ON merged_songs(song_name);
CREATE INDEX IF NOT EXISTS idx_merged_songs_session_id ON merged_songs(session_id);
CREATE INDEX IF NOT EXISTS idx_top_songs_user_id ON top_songs(user_id);
CREATE INDEX IF NOT EXISTS idx_top_songs_popularity ON top_songs(popularity);

-- Función para actualizar el timestamp de updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para actualizar automáticamente el campo updated_at en merged_songs
CREATE TRIGGER update_merged_songs_updated_at 
    BEFORE UPDATE ON merged_songs 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insertar algunos datos de ejemplo (opcional)
INSERT INTO merged_songs (user_id, song_name, artist_name, popularity, votes, session_id) VALUES
('user1', 'Bohemian Rhapsody', 'Queen', 95, 10, 'demo-session'),
('user1', 'Hotel California', 'Eagles', 90, 8, 'demo-session'),
('user2', 'Imagine', 'John Lennon', 92, 12, 'demo-session'),
('user2', 'Sweet Child O'' Mine', 'Guns N'' Roses', 88, 7, 'demo-session'),
('user3', 'Billie Jean', 'Michael Jackson', 94, 15, 'demo-session'),
('user3', 'Smells Like Teen Spirit', 'Nirvana', 87, 9, 'demo-session'),
('user1', 'Stairway to Heaven', 'Led Zeppelin', 96, 11, 'demo-session'),
('user2', 'Like a Rolling Stone', 'Bob Dylan', 85, 6, 'demo-session'),
('user3', 'Purple Haze', 'Jimi Hendrix', 89, 8, 'demo-session'),
('user1', 'Good Vibrations', 'The Beach Boys', 83, 5, 'demo-session')
ON CONFLICT DO NOTHING;

-- Comentarios sobre el esquema:
-- 1. merged_songs: Tabla principal que almacena todas las canciones agregadas por los usuarios
--    - id: Clave primaria autoincremental
--    - user_id: Identificador del usuario que agregó la canción
--    - song_name: Nombre de la canción
--    - artist_name: Nombre del artista
--    - popularity: Valor de popularidad de la canción (0-100)
--    - votes: Contador de votos (upvotes - downvotes)
--    - created_at/updated_at: Timestamps para auditoría

-- 2. top_songs: Tabla para almacenar las top 20 canciones más populares
--    - Similar estructura pero sin campo votes
--    - Se llena automáticamente desde merged_songs

-- 3. Los índices mejoran el rendimiento de las consultas más frecuentes
-- 4. El trigger actualiza automáticamente el timestamp cuando se modifica un registro
