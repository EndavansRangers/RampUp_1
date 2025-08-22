import React, { useState, useEffect, useContext } from "react";
import { useLocation } from "react-router-dom";
import { UserContext } from '../contexts/UserContext';
import SearchForm from "./SearchForm";
import VideoItem from "./VideoItem";
import TopTracks from "./TopTracks";
import LikedSongs from "./LikedSongs";
import Playlist from "./PlaylistGuest";
import axios from "axios";

const GOOGLE_API_KEY = `${process.env.REACT_APP_GOOGLE_KEY}`;

function GuestView() {
  const [results, setResults] = useState([]);
  const [isApiReady, setIsApiReady] = useState(false);
  const [topTracks, setTopTracks] = useState([]);
  const [likedSongs, setLikedSongs] = useState([]);
  const [guestName, setGuestName] = useState("");
  const [isJoined, setIsJoined] = useState(false);
  const [sessionId, setSessionId] = useState(null); // Define sessionId as a state variable
  const [username, setUsername] = useState(null);
  const [votes, setVotes] = useState({});
  const [isPlaylistGenerated, setIsPlaylistGenerated] = useState(false);
  const [spotifyUserId, setSpotifyUserId] = useState(null); // State to store Spotify userId
  const [showUsernameForm, setShowUsernameForm] = useState(true);
  const [tempUsername, setTempUsername] = useState("");

  const location = useLocation(); // Use the useLocation hook

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const sessionIdFromURL = params.get("sessionId"); // Get sessionId from URL parameters
    console.log("URL sessionId:", sessionIdFromURL); // Log the sessionId from URL parameters
    if (sessionIdFromURL) {
      setSessionId(sessionIdFromURL); // Update the sessionId state variable
      localStorage.setItem("sessionId", sessionIdFromURL);
      console.log("localStorage sessionId:", localStorage.getItem("sessionId")); // Log the sessionId from localStorage
    }
    
    const usernameFromURL = params.get("username"); // Get username from URL parameters
    const usernamefromToken = localStorage.getItem("spotifyAccessToken");
    console.log("URL username:", usernameFromURL); // Log the username from URL parameters
    
    // Solo auto-unirse si hay username en URL o token de Spotify
    if (usernameFromURL && sessionIdFromURL) {
      // Auto-join si viene con username en la URL
      setUsername(usernameFromURL);
      setGuestName(usernameFromURL);
      localStorage.setItem("username", usernameFromURL);
      setIsJoined(true);
      setShowUsernameForm(false);
      
      // Llamar al backend para unirse automáticamente
      axios.post(`${process.env.REACT_APP_BACKEND_URL}/join-session`, {
        sessionId: sessionIdFromURL,
        username: usernameFromURL,
      }).catch(error => {
        console.error("Error auto-joining session:", error);
      });
    } else if (usernamefromToken && sessionIdFromURL) {
      // Auto-join si hay token de Spotify
      const tokenUsername = "SpotifyUser"; // Puedes extraer el nombre real del token si lo deseas
      setUsername(tokenUsername);
      setGuestName(tokenUsername);
      localStorage.setItem("username", tokenUsername);
      setIsJoined(true);
      setShowUsernameForm(false);
      
      axios.post(`${process.env.REACT_APP_BACKEND_URL}/join-session`, {
        sessionId: sessionIdFromURL,
        username: tokenUsername,
      }).catch(error => {
        console.error("Error auto-joining session:", error);
      });
    } else {
      // Mostrar formulario para ingresar nombre
      setIsJoined(false);
      setShowUsernameForm(true);
    }
  }, [location.search]);
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const sessionId = params.get("sessionId");
    console.log("URL sessionId:", sessionId); // Log the sessionId from URL parameters
    if (sessionId) {
      localStorage.setItem("sessionId", sessionId);
      console.log("localStorage sessionId:", localStorage.getItem("sessionId")); // Log the sessionId from localStorage
    }
  }, []);

  const { fetchUsers } = useContext(UserContext);
  
  const handleUsernameSubmit = async (e) => {
    e.preventDefault();
    if (tempUsername.trim() && sessionId) {
      try {
        // Llamar al backend para unirse a la sesión
        const response = await axios.post(
          `${process.env.REACT_APP_BACKEND_URL}/join-session`,
          {
            sessionId: sessionId,
            username: tempUsername.trim(),
          }
        );

        if (response.data.success) {
          setUsername(tempUsername.trim());
          setGuestName(tempUsername.trim());
          localStorage.setItem("username", tempUsername.trim());
          setIsJoined(true);
          setShowUsernameForm(false);
          console.log("Successfully joined session:", sessionId);
        } else {
          alert("Failed to join session. Please check the session ID.");
        }
      } catch (error) {
        console.error("Error joining session:", error);
        alert("Error joining session. Please try again.");
      }
    } else {
      alert("Please enter a username and make sure you have a valid session ID.");
    }
  };

  useEffect(() => {
    // Save the current document title
    const originalTitle = document.title;

    // Update the document title
    document.title = "TuneFy Guest";

    // Revert the document title back to the original title when the component unmounts
    return () => {
      document.title = originalTitle;
    };
  }, []);

  useEffect(() => {
    // Revert the favicon back to the original favicon when the component unmounts
    return () => {
      document
        .querySelector("link[rel='icon']")
        .setAttribute("href", "/favicon-guest.ico");
    };
  }, []);
  useEffect(() => {
    window.addEventListener("resize", resetVideoHeight);

    // Load the Google API client library
    const script = document.createElement("script");
    script.src = "https://apis.google.com/js/client.js";
    script.onload = () => {
      window.gapi.load("client", init);
    };
    document.body.appendChild(script);

    return () => {
      window.removeEventListener("resize", resetVideoHeight);
    };
  }, []);

  const init = () => {
    window.gapi.client.setApiKey(GOOGLE_API_KEY);
    window.gapi.client.load("youtube", "v3", () => {
      setIsApiReady(true);
    });
  };

  const handleSearch = (search) => {
    if (search !== "" && isApiReady) {
      const request = window.gapi.client.youtube.search.list({
        part: "snippet",
        type: "video",
        q: encodeURIComponent(search).replace(/%20/g, "+") + " karaoke",
        maxResults: 3,
        order: "relevance",
      });

      request.execute((response) => {
        const items = response.result.items;
        console.log(items);
        setResults(
          items.map((item) => ({
            title: item.snippet.title,
            videoId: item.id.videoId,
          }))
        );
      });
    }
  }
  const resetVideoHeight = () => {
    const videoElements = document.querySelectorAll(".video");
    videoElements.forEach((videoElement) => {
      videoElement.style.height = `${document.getElementById("results").offsetWidth * (9 / 16)
        }px`;
    });
  };


  useEffect(() => {
    if (isPlaylistGenerated) {
      const fetchVotes = async () => {
        try {
          const response = await axios.get(
            `${process.env.REACT_APP_BACKEND_URL}/votes`
          );
          setVotes(response.data.votes);
        } catch (error) {
          console.error("Error fetching votes:", error);
        }
      };

      fetchVotes();
      const intervalId = setInterval(fetchVotes, 5000); // Fetch votes every 5 seconds

      return () => {
        clearInterval(intervalId); // Clear the interval when the component unmounts
      };
    }
  }, [isPlaylistGenerated]);
  const onVote = async (songId, voteType) => {
    console.log(`Initiating vote. Song ID: ${songId}, Vote Type: ${voteType}`);

    // Optimistically update the local votes state before the backend confirmation
    setVotes((prevVotes) => {
      const safePrevVotes = prevVotes ?? {};
      const currentVotesForSong = safePrevVotes[songId] ?? 0;
      const updatedVotesForSong =
        currentVotesForSong + (voteType === "upvote" ? 1 : -1);

      console.log(
        `Current votes for song ID ${songId}: ${currentVotesForSong}`
      );
      console.log(
        `Updating votes for song ID ${songId} to: ${updatedVotesForSong}`
      );

      return {
        ...safePrevVotes,
        [songId]: updatedVotesForSong,
      };
    });

    try {
      console.log("Sending vote to backend...");
      const response = await fetch(
        `${process.env.REACT_APP_BACKEND_URL}/vote`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ songId, voteType }),
        }
      );

      const data = await response.json();
      console.log(
        `Vote response received from backend for song ID ${songId}: `,
        data
      );

      // Optionally update state based on the response if necessary
      // ...
    } catch (error) {
      console.error(
        `Error occurred when voting for song ID ${songId}: `,
        error
      );

      // Rollback optimistic update if error occurs
      setVotes((prevVotes) => {
        const currentVotesForSong = prevVotes[songId] ?? 0;
        const rollbackVotesForSong =
          currentVotesForSong - (voteType === "upvote" ? 1 : -1);

        console.log(
          `Rolling back votes for song ID ${songId} to: ${rollbackVotesForSong}`
        );

        return {
          ...prevVotes,
          [songId]: rollbackVotesForSong,
        };
      });
    }
  };

  const handleLeaveSession = async () => {
    const sessionId = localStorage.getItem("sessionId");
    const username = localStorage.getItem("username");

    if (!sessionId || !username) {
      alert("Session ID or username not found");
      return;
    }

    try {
      const response = await axios.post(
        `${process.env.REACT_APP_BACKEND_URL}/leave-session`,
        {
          sessionId,
          username,
        }
      );

      if (response.data.success) {
        console.log("Left session successfully");
        setIsJoined(false);
        localStorage.removeItem("sessionId");
        localStorage.removeItem("username");
        localStorage.removeItem("playlistSent");
      } else {
        console.error("Failed to leave session");
      }
    } catch (error) {
      console.error("Error leaving session:", error);
      alert("Failed to leave session");
    }
  };

  return (
    <div>
      <h2>Guest View</h2>
      {sessionId ? (
        <>
          <p>Session ID: {sessionId}</p>
          
          {showUsernameForm && !isJoined ? (
            <div className="username-form" style={{ maxWidth: '400px', margin: '20px auto', padding: '20px', border: '1px solid #ddd', borderRadius: '8px' }}>
              <h3>Join Session</h3>
              <p>Please enter your name to join this music session</p>
              <form onSubmit={handleUsernameSubmit}>
                <div className="form-group" style={{ marginBottom: '15px' }}>
                  <label htmlFor="username" style={{ display: 'block', marginBottom: '5px' }}>Your Name:</label>
                  <input
                    type="text"
                    id="username"
                    value={tempUsername}
                    onChange={(e) => setTempUsername(e.target.value)}
                    placeholder="Enter your name"
                    required
                    style={{ 
                      width: '100%', 
                      padding: '8px', 
                      border: '1px solid #ccc', 
                      borderRadius: '4px',
                      fontSize: '16px'
                    }}
                  />
                </div>
                <button 
                  type="submit" 
                  style={{
                    backgroundColor: '#007bff',
                    color: 'white',
                    padding: '10px 20px',
                    border: 'none',
                    borderRadius: '4px',
                    cursor: 'pointer',
                    fontSize: '16px',
                    width: '100%'
                  }}
                >
                  Join Session
                </button>
              </form>
            </div>
          ) : (
            <>
              <div style={{ marginBottom: '20px', fontSize: '18px', fontWeight: 'bold' }}>
                Welcome, {guestName}!
              </div>
              <Playlist onVote={onVote} />
              <div className="row">
                <div className="col-md-6">
                  <TopTracks tracks={topTracks} />
                </div>
                <div className="col-md-6">
                  <LikedSongs songs={likedSongs} />
                </div>
              </div>
              <div className="row">
                <div className="col-md-6 offset-md-3">
                  <SearchForm onSearch={handleSearch} />
                  <div id="results">
                    {results.map((result, index) => (
                      <VideoItem
                        key={index}
                        title={result.title}
                        videoId={result.videoId}
                      />
                    ))}
                  </div>
                </div>
              </div>
              {isJoined && (
                <button onClick={handleLeaveSession} className="btn btn-danger" style={{ marginTop: '20px' }}>
                  Leave Session
                </button>
              )}
            </>
          )}
        </>
      ) : (
        <div style={{ textAlign: 'center', padding: '40px' }}>
          <h3>No Session Found</h3>
          <p>Please make sure you have a valid session link with a session ID.</p>
        </div>
      )}
    </div>
  );
}

export default GuestView;
