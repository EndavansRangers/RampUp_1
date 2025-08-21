import React from "react";
import axios from "axios";

function VideoItem({ title, videoId }) {
  const handleSendSong = async () => {
    const response = await axios.post(`${process.env.REACT_APP_BACKEND_URL}/extract-song-artist`, { title: title });
    const { artist, songName } = response.data;
    console.log(artist, songName);
    try {
      const response = await axios.post(`${process.env.REACT_APP_BACKEND_URL}/add-song`, {
        user_id: "null", // Since the user is not logged in, send null
        song_name: songName,
        artist_name: artist, // Send the extracted artist name
      });

      if (response.status === 201) {
        console.log("Song sent successfully:", response.data);
        // Optionally, perform any additional actions upon success
        alert("Song sent successfully:", response.data);
        // childToParent();
      } else {
        console.error("Failed to send song");
      }
    } catch (error) {
      console.error("Error sending song:", error);
    }
  };


  return (
    <div className="item">
      <div class="title-send">
        <h2>{title}</h2>
        <button onClick={handleSendSong} className="send-song btn btn-primary">
          ➤
        </button>
      </div>
      <iframe
        className="video w-100"
        width="640"
        height="360"
        src={`//www.youtube.com/embed/${videoId}`}
        frameBorder="0"
        allowFullScreen
      ></iframe>
    </div>
  );
}

export default VideoItem;