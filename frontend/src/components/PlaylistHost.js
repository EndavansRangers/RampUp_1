import React, { useState, useEffect } from "react";

const Playlist = ({ songs }) => {
  const [error, setError] = useState(null);

  // Function to fetch the latest votes and update the songs prop
  const fetchVotesAndUpdateSongs = async () => {
    try {
      const response = await fetch(
        `${process.env.REACT_APP_BACKEND_URL}/votes`
      );
      if (!response.ok) {
        throw new Error("Failed to fetch votes");
      }
      const votes = await response.json();

      // Assuming you want to merge these votes with the songs prop
      const updatedSongs = songs.map((song) => ({
        ...song,
        votes:
          votes.find((vote) => vote.song_id === song.id)?.votes || song.votes,
      }));

      // If you need to update the parent component with these new votes,
      // you should lift this state up to the parent and pass down a function to update it,
      // or use a global state management solution like Context or Redux.
    } catch (error) {
      setError(error.message);
    }
  };

  useEffect(() => {
    // Poll for votes on component mount
    fetchVotesAndUpdateSongs();
    const intervalId = setInterval(fetchVotesAndUpdateSongs, 20000); // Poll every 20 seconds

    // Clear interval on component unmount
    return () => clearInterval(intervalId);
  }, [songs]); // Added songs as a dependency

  // Sort the songs by votes in descending order
  const sortedSongs = [...songs].sort(
    (a, b) => (b.votes || 0) - (a.votes || 0)
  );
  return (
    <div className="playlist-host-container">
      <h2 className="playlist-host-header">Playlist</h2>
      {error && <p className="playlist-host-error">Error: {error}</p>}
      <table className="playlist-host-table">
        <thead>
          <tr>
            <th>Song Name - Artist</th>
            <th>Votes</th>
          </tr>
        </thead>
        <tbody>
          {sortedSongs.map((song) => (
            <tr key={song.id}>
              <td>
                {song.song_name} - {song.artist_name}
              </td>
              <td>{song.votes || 0}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default Playlist;
