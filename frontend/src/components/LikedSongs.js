import React from "react";

const LikedSongs = ({ songs }) => {
  return (
    <div className="liked-songs">
      <h2>Liked Songs</h2>
      <ul>
        {songs && songs.length > 0 ? (
          songs.map((song, index) => (
            <li key={index}>
              <span className="song-number">{index + 1}.</span>
              <img src={song.track.album.images[0].url} alt={song.track.name} />
              <div>
                <h3>{song.track.name}</h3>
                <p>
                  {song.track.artists.map((artist) => artist.name).join(", ")}
                </p>
              </div>
            </li>
          ))
        ) : (
          <p>No liked songs found.</p>
        )}
      </ul>
    </div>
  );
};

export default LikedSongs;
