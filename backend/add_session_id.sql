-- Script para agregar session_id a las tablas existentes
-- Ejecutar este script en PostgreSQL

-- Agregar columna session_id a la tabla merged_songs
ALTER TABLE merged_songs ADD COLUMN IF NOT EXISTS session_id VARCHAR(50);

-- Agregar columna session_id a la tabla top_songs
ALTER TABLE top_songs ADD COLUMN IF NOT EXISTS session_id VARCHAR(50);

-- Crear índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_merged_songs_session_id ON merged_songs(session_id);
CREATE INDEX IF NOT EXISTS idx_top_songs_session_id ON top_songs(session_id);

-- Opcional: Limpiar datos existentes que no tienen session_id
-- Solo ejecutar si quieres empezar limpio
-- DELETE FROM merged_songs WHERE session_id IS NULL;
-- DELETE FROM top_songs WHERE session_id IS NULL;

-- Verificar que las columnas se agregaron correctamente
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'merged_songs' AND column_name = 'session_id';

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'top_songs' AND column_name = 'session_id';

-- Mostrar estructura actual de las tablas
\d merged_songs;
\d top_songs;
