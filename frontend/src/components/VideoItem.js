import React from "react";
import axios from "axios";

function VideoItem({ title, videoId }) {
  const handleSendSong = async () => {
    try {
      // First, try to extract artist and song name from the title
      const extractResponse = await axios.post(`${process.env.REACT_APP_BACKEND_URL}/extract-song-artist`, { title: title });
      let { artist, songName } = extractResponse.data;
      
      console.log("Extracted - Artist:", artist, "Song:", songName);
      
      // If extraction failed, use fallback approach
      if (!artist || !songName) {
        console.log("AI extraction failed, using fallback parsing...");
        
        // Simple fallback: try to split by common separators
        if (title.includes(' - ')) {
          const parts = title.split(' - ');
          artist = parts[0].trim();
          songName = parts.slice(1).join(' - ').trim();
        } else if (title.includes(' by ')) {
          const parts = title.split(' by ');
          songName = parts[0].trim();
          artist = parts[1].trim();
        } else {
          // Last resort: use the full title as song name and "Unknown Artist"
          songName = title.trim();
          artist = "Unknown Artist";
        }
        
        console.log("Fallback - Artist:", artist, "Song:", songName);
      }
      
      // Validate that we have valid values
      if (!artist || !songName) {
        throw new Error("Could not determine artist and song name");
      }
      
      // Get session ID from localStorage
      const sessionId = localStorage.getItem("sessionId");
      if (!sessionId) {
        throw new Error("No session found. Please join or create a session first.");
      }
      
      // Send the song to the backend
      const response = await axios.post(`${process.env.REACT_APP_BACKEND_URL}/add-song`, {
        user_id: "guest",
        song_name: songName,
        artist_name: artist,
        session_id: sessionId, // Add session_id
      });

      if (response.status === 201) {
        console.log("Song sent successfully:", response.data);
        alert("Song sent successfully!");
      } else {
        console.error("Failed to send song");
        alert("Failed to send song");
      }
    } catch (error) {
      console.error("Error sending song:", error);
      alert("Error sending song: " + (error.response?.data?.error || error.message));
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