import React from "react";

const TopTracks = ({ tracks }) => {
  return (
    <div className="top-tracks">
      <h2>Top Tracks</h2>
      <ul>
        {tracks && tracks.length > 0 ? (
          tracks.map((track, index) => (
            <li key={index}>
              <span className="song-number">{index + 1}.</span>
              <img src={track.album.images[0].url} alt={track.name} />
              <div>
                <h3>{track.name}</h3>
                <p>{track.artists.map((artist) => artist.name).join(", ")}</p>
              </div>
            </li>
          ))
        ) : (
          <p>No top tracks found.</p>
        )}
      </ul>
    </div>
  );
};

export default TopTracks;
