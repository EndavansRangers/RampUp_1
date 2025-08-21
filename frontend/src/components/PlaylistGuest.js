import React, { useState, useEffect } from "react";

const Playlist = ({ onVote }) => {
  const [error, setError] = useState(null);
  const [songs, setSongs] = useState([]);

  // Function to fetch the latest votes
  const fetchVotes = async () => {
    try {
      const response = await fetch(
        `${process.env.REACT_APP_BACKEND_URL}/votes`
      );
      if (!response.ok) {
        throw new Error("Failed to fetch votes");
      }
      const votes = await response.json();
      setSongs((currentSongs) =>
        currentSongs.map((song) => ({
          ...song,
          votes:
            votes.find((vote) => vote.song_id === song.id)?.votes || song.votes,
        }))
      );
    } catch (error) {
      setError(error.message);
    }
  };

  useEffect(() => {
    // Poll for votes on component mount
    fetchVotes();
    const intervalId = setInterval(fetchVotes, 20000); // Poll every 20 seconds

    // Clear interval on component unmount
    return () => clearInterval(intervalId);
  }, []);

  useEffect(() => {
    fetch(`${process.env.REACT_APP_BACKEND_URL}/playlist`)
      .then((response) => response.json())
      .then((data) => {
        setSongs(data);
      })
      .catch((error) => {
        setError(error.message);
      });
  }, []);

  // Handle local upvote/downvote actions
  const handleLocalVote = (songId, voteType) => {
    setSongs((currentSongs) =>
      currentSongs.map((song) => {
        if (song.id === songId) {
          return {
            ...song,
            votes: voteType === "upvote" ? song.votes + 1 : song.votes - 1,
          };
        }
        return song;
      })
    );
  };

  const sortedSongs = songs.sort((a, b) => b.votes - a.votes);
  return (
    <div className="playlist-container">
      <h2 className="playlist-header">Playlist</h2>
      {error && <p className="playlist-error">Error: {error}</p>}
      <table className="playlist-table">
        <thead>
          <tr>
            <th>Song Name - Artist</th>
            <th>Votes</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {sortedSongs.map((song) => (
            <tr key={song.id}>
              <td>
                {song.song_name} - {song.artist_name}
              </td>
              <td>{song.votes}</td>
              <td>
                <button
                  className="vote-button upvote"
                  onClick={() => {
                    handleLocalVote(song.id, "upvote");
                    onVote(song.id, "upvote");
                  }}
                >
                  👍
                </button>
                <button
                  className="vote-button downvote"
                  onClick={() => {
                    handleLocalVote(song.id, "downvote");
                    onVote(song.id, "downvote");
                  }}
                >
                  👎
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default Playlist;
