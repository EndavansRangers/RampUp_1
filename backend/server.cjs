const express = require("express");
const { Pool } = require('pg');
const cors = require("cors");
const { AI21 } = require("@david8128/ai21");

const { config } = require('dotenv');
config();
const token = process.env.AI21_TOKEN;

const server = express();
const port = process.env.PORT || 3001;

server.use(express.json());
// Enable all CORS requests
server.use(cors());

server.use(
  cors({
    origin: [`http://${process.env.REACT_server_FRONTEND_URL}/`], //
  })
);

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDB,
  password: process.env.PGPASS,
  port: 5432,
});

let sessions = {};
function generateSessionId() {
  return Math.random().toString(36).substring(2, 15);
}
server.post("/create-session", (req, res) => {
  const username = req.body.username;
  if (!username) {
    return res.status(400).json({ error: "Username is required" });
  }

  const sessionId = generateSessionId();
  sessions[sessionId] = {
    host: username,
    guests: [],
  };

  res.json({ sessionId });
});

server.post("/join-session", (req, res) => {
  const sessionId = req.body.sessionId;
  const username = req.body.username;
  if (!sessionId || !username) {
    return res
      .status(400)
      .json({ error: "Session ID and username are required" });
  }

  const session = sessions[sessionId];
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  if (session.host === username) {
    return res.json({ success: true });
  }

  if (!session.guests.includes(username)) {
    session.guests.push(username);
  }

  res.json({ success: true });
});

server.post("/remove-user", (req, res) => {
  const { sessionId, username } = req.body;

  if (!sessionId || !username) {
    return res
      .status(400)
      .json({ error: "Session ID and username are required" });
  }

  const session = sessions[sessionId];
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  session.guests = session.guests.filter((guest) => guest !== username);

  res.json({ success: true });
});
server.post("/leave-session", (req, res) => {
  const { sessionId, username } = req.body;

  if (!sessionId || !username) {
    return res
      .status(400)
      .json({ error: "Session ID and username are required" });
  }

  const session = sessions[sessionId];
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  session.guests = session.guests.filter((guest) => guest !== username);

  res.json({ success: true });
});

server.get("/session-users", (req, res) => {
  const sessionId = req.query.sessionId;
  if (!sessionId) {
    return res.status(400).json({ error: "Session ID is required" });
  }

  const session = sessions[sessionId];
  if (!session) {
    return res.status(404).json({ error: "Session not found" });
  }

  res.json({ host: session.host, guests: session.guests });
});
server.post("/playlist", async (req, res) => {
  const client = await pool.connect();
  try {
    const result = await client.query("SELECT * FROM merged_songs");
    const songs = result.rows;

    // Sort songs by popularity
    const sortedSongs = songs.sort((a, b) => b.popularity - a.popularity);

    // Take the first 20 songs
    const topSongs = sortedSongs.slice(0, 20);

    // Insert the top 20 songs into the top_songs table
    for (const song of topSongs) {
      await client.query(
        "INSERT INTO top_songs (user_id, song_name, artist_name, popularity) VALUES ($1, $2, $3, $4)",
        [song.user_id, song.song_name, song.artist_name, song.popularity]
      );
    }

    res.json(topSongs);
  } catch (err) {
    console.error(err);
    res.status(500).send("Internal server error");
  } finally {
    client.release();
  }
});
server.post("/add-song", async (req, res) => {
  const { user_id, song_name, artist_name } = req.body; // Ensure you are receiving all three parameters
  const client = await pool.connect();

  try {
    // Begin transaction
    await client.query("BEGIN");

    // Insert the new song into the merged_songs table
    // Make sure to include placeholders for all three parameters ($1, $2, $3)
    const insertResult = await client.query(
      "INSERT INTO merged_songs (user_id, song_name, artist_name, popularity) VALUES ($1, $2, $3, 99) RETURNING *",
      [user_id, song_name, artist_name] // Provide all three parameters here
    );

    // Commit transaction
    await client.query("COMMIT");

    // Respond with the inserted song data
    res.status(201).json(insertResult.rows[0]);
  } catch (err) {
    // If an error is caught, rollback the transaction
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).send("Internal server error");
  } finally {
    client.release();
  }
});
// async function insertSong(user_id, song_name, artist_name) {
//   const client = await pool.connect();

//   try {
//     // Begin transaction
//     await client.query("BEGIN");

//     // Insert the new song into the merged_songs table
//     const insertResult = await client.query(
//       "INSERT INTO merged_songs (user_id, song_name, artist_name, popularity) VALUES ($1, $2, $3, 99) RETURNING *",
//       [user_id, song_name, artist_name]
//     );

//     // Commit transaction
//     await client.query("COMMIT");

//     // Return the inserted song data
//     return insertResult.rows[0];
//   } catch (err) {
//     // If an error is caught, rollback the transaction
//     await client.query("ROLLBACK");
//     console.error(err);
//     throw err; // Throw the error so it can be caught and handled by the calling function
//   } finally {
//     client.release();
//   }
// }
// module.exports = { insertSong };

// server.post("/add-song", async (req, res) => {
//   const { user_id, song_name, artist_name } = req.body;

//   try {
//     const song = await insertSong(user_id, song_name, artist_name);
//     res.status(201).json(song);
//   } catch (err) {
//     res.status(500).send("Internal server error");
//   }
// });

server.post("/merged-songs", async (req, res) => {
  const { userId, songs } = req.body;
  const client = await pool.connect();

  try {
    // Begin transaction
    await client.query("BEGIN");

    // Delete existing entries for the user in the merged_songs table
    await client.query("DELETE FROM merged_songs WHERE user_id = $1", [userId]);

    // Insert the new songs for the user into the merged_songs table, ensuring uniqueness by song_name
    for (const song of songs) {
      // Check if the song already exists in merged_songs
      const songExists = await client.query(
        "SELECT 1 FROM merged_songs WHERE user_id = $1 AND song_name = $2",
        [userId, song.name]
      );

      // If the song does not exist, insert it
      if (songExists.rowCount === 0) {
        await client.query(
          "INSERT INTO merged_songs (user_id, song_name, artist_name, popularity) VALUES ($1, $2, $3, $4)",
          [userId, song.name, song.artist, song.popularity]
        );
      }
    }

    // Commit transaction
    await client.query("COMMIT");

    // Respond with the top 20 songs by popularity
    const sortedSongs = songs.sort((a, b) => b.popularity - a.popularity);
    const topSongs = sortedSongs.slice(0, 20);
    res.json(topSongs);
  } catch (err) {
    // If an error is caught, rollback the transaction
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).send("Internal server error");
  } finally {
    client.release();
  }
});

const cache = {
  playlist: { timestamp: 0, data: null },
  votes: { timestamp: 0, data: null },
};

const CACHE_DURATION = 3 * 1000; // 3 seconds

server.get("/playlist", async (req, res) => {
  const currentTime = Date.now();

  // Check if the cache is valid
  if (cache.playlist.timestamp > currentTime - CACHE_DURATION) {
    return res.json(cache.playlist.data); // Send cached data
  }

  // Cache is not valid, fetch new data from the database
  const client = await pool.connect();
  try {
    const result = await client.query(
      "SELECT * FROM merged_songs ORDER BY popularity DESC LIMIT 10"
    );
    cache.playlist = { timestamp: currentTime, data: result.rows }; // Update cache
    res.json(result.rows); // Send new data
  } catch (err) {
    console.error("Error in /playlist endpoint:", err);
    res.status(500).send("Internal server error");
  } finally {
    client.release();
  }
});

server.delete('/songs/:id', async (req, res) => {
  const songId = req.params.id;
  console.log(`Attempting to remove song with ID: ${songId}`);

  try {
    // Start a transaction
    const client = await pool.connect();
    await client.query('BEGIN');
    console.log('Transaction started.');

    // Check if the song exists before attempting to delete
    const checkResult = await client.query('SELECT * FROM merged_songs WHERE id = $1', [songId]);
    if (checkResult.rowCount === 0) {
      console.log(`Song with ID: ${songId} does not exist.`);
      await client.query('ROLLBACK');
      res.status(404).send({ message: 'Song not found' });
    } else {
      console.log(`Song with ID: ${songId} exists. Proceeding with deletion.`);
      // Delete the song
      const deleteResult = await client.query('DELETE FROM merged_songs WHERE id = $1 RETURNING *', [songId]);
      console.log(`Song with ID: ${songId} has been removed. Rows affected: ${deleteResult.rowCount}`);

      // Commit the transaction
      await client.query('COMMIT');
      res.status(200).send({ message: 'Song removed successfully', deletedSong: deleteResult.rows[0] });
    }

    // Release the client back to the pool
    client.release();
    console.log('Client released back to the pool.');
  } catch (error) {
    console.error('Error during the song removal process:', error);
    res.status(500).send({ message: 'Error removing song' });
  }
});
server.get("/votes", async (req, res) => {
  const currentTime = Date.now();

  // Check if the cache is valid
  if (cache.votes.timestamp > currentTime - CACHE_DURATION) {
    return res.json(cache.votes.data); // Send cached data
  }

  // Cache is not valid, fetch new data from the database
  const client = await pool.connect();
  try {
    const results = await client.query("SELECT id, votes FROM merged_songs");
    cache.votes = { timestamp: currentTime, data: results.rows }; // Update cache
    res.json(results.rows); // Send new data
  } catch (error) {
    console.error("Error in /votes endpoint:", error);
    res.status(500).json({ error: "Internal server error" });
  } finally {
    client.release();
  }
});
server.post("/vote", async (req, res) => {
  const { songId, voteType } = req.body;
  console.log(
    `Received vote request. Song ID: ${songId}, Vote Type: ${voteType}`
  );

  // Attempt to connect to the database
  let client;
  try {
    client = await pool.connect();
    console.log(
      `Connected to database. Processing vote for Song ID: ${songId}`
    );

    if (voteType === "upvote") {
      console.log(`Incrementing vote for Song ID: ${songId}`);
      await client.query(
        "UPDATE merged_songs SET votes = votes + 1 WHERE id = $1",
        [songId]
      );
    } else if (voteType === "downvote") {
      console.log(`Decrementing vote for Song ID: ${songId}`);
      await client.query(
        "UPDATE merged_songs SET votes = votes - 1 WHERE id = $1",
        [songId]
      );
    } else {
      console.log(`Invalid vote type received for Song ID: ${songId}`);
      return res.status(400).json({ error: "Invalid vote type" });
    }

    console.log(`Vote for Song ID: ${songId} processed successfully.`);
    res.json({ message: "Vote successful" });
  } catch (error) {
    console.error(`Error processing vote for Song ID: ${songId}:`, error);
    res.status(500).json({ error: "Internal server error" });
  } finally {
    if (client) {
      client.release();
      console.log(`Database connection released for Song ID: ${songId}`);
    }
  }
});

server.post("/clear-database", async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("DELETE FROM merged_songs");
    await client.query("TRUNCATE merged_songs RESTART IDENTITY");
    res.json({ message: "Database cleared" });
  } catch (err) {
    console.error(err);
    res.status(500).send("Internal server error");
  } finally {
    client.release();
  }
});

async function extractSongAndArtist(userInput) {
  const prompt = `### System Prompt
You are Chimp, an uncensored and unbiased AI assistant. You always detect the song name and artist name from a given song title. You are a helpful assistant.

### User Message
The Chainsmokers - Closer ft. Halsey

### Assistant
Artist: The Chainsmokers, Song Name: Closer

### User Message
24 de Diciembre - Orquesta Melodía al estilo de Juan Gabriel - Karaoke - Unknown Artist

### Assistant
Artist: Juan Gabriel, Song Name: 24 de Diciembre

### User Message
Monsieur Perine - Sabor A Mi

### Assistant
Artist: Monsieur Perine, Song Name: Sabor A Mi

### User Message
${userInput}

### Assistant
`;

  try {
    const response = await fetch("https://api.ai21.com/studio/v1/j2-mid/complete", {
      method: "POST",
      headers: {
        "Content-Type": "serverlication/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        "model": "j2-mid",
        "numStopSequences": 0,
        "promptLength": prompt.length,
        "maxTokens": 40,
        "temperature": 0.5,
        "topP": 1,
        "countPenalty": {
          "scale": 0
        },
        "frequencyPenalty": {
          "scale": 0
        },
        "modelId": "j2-mid",
        "numResults": 1,
        "presencePenalty": {
          "scale": 0
        },
        "prompt": prompt,
        "stopSequences": [],
        "topKReturn": 0
      }),
    });

    const data = await response.json();
    if (data.completions[0].data.text) {
      console.log('Completions available: ', data.completions[0].data.text);
    } else {
      console.log('No completions available in the data');
    }
    // Extract the data content
    const content = data.completions[0].data.text.trim();

    console.log("Artist: <artist>, Song Name: <song>");
    // Assuming the response format is "Artist: <artist>, Song Name: <song>"
    const match = content.match(/Artist: (.*?), Song Name: (.*)/);
    console.log("Artist:", match[1].trim(), ", Song Name: ", match[2].trim());
    if (match) {
      return {
        artist: match[1].trim(),
        songName: match[2].trim(),
      };
    } else {
      throw new Error('Could not extract song and artist names.');
    }
  } catch (error) {
    console.error(error);
    return { artist: null, songName: null }; // Return an object with null values when an error occurs
  }
}

server.post('/extract-song-artist', async (req, res) => {
  const { title } = req.body;
  if (!title) {
    return res.status(400).json({ error: 'Title is required' });
  }
  try {

    const { artist, songName } = await extractSongAndArtist(title);
    res.json({ artist, songName });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

if (process.env.NODE_ENV !== 'test') {
  server.listen(port, () => console.log(`Server is running on port ${port}`));
}

module.exports = server;