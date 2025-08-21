import React from "react";

function CompleteList({ topTracks, likedSongs }) {
  return (
    <div>
      <h3>Complete List</h3>
      <div>
        <h4>Top Tracks</h4>
        <ul>
          {topTracks.map((track, index) => (
            <li key={index}>{track.name}</li>
          ))}
        </ul>
      </div>
      <div>
        <h4>Liked Songs</h4>
        <ul>
          {likedSongs.map((song, index) => (
            <li key={index}>{song.name}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default CompleteList;
