import React, { useState, useEffect, useContext } from "react";
import SearchForm from "./SearchForm";
import VideoItem from "./VideoItem";
import Playlist from "./PlaylistHost";
import { UserContext } from '../contexts/UserContext';
import QRCode from "qrcode.react";
import axios from "axios";
import "../css/SessionStyles.css";
import "../css/HostViewStyles.css";

function HostView() {
  const [results, setResults] = useState([]);
  const [isApiReady, setIsApiReady] = useState(false);
  const [topTracks, setTopTracks] = useState([]);
  const [likedSongs, setLikedSongs] = useState([]);
  const [username, setUsername] = useState("");
  const [sessionId, setSessionId] = useState("");
  const [votes, setVotes] = useState({});
  const [songs, setSongs] = useState([]);

  const [isUpdating, setIsUpdating] = useState(false);
  const [fetchKey, setFetchKey] = useState(Date.now());
  const [isPlaylistGenerated, setIsPlaylistGenerated] = useState(false);

  const [error, setError] = useState(null);

  const { users, setUsers, fetchUsers } = useContext(UserContext);
  // useEffect(() => {
  //   fetchUsers().then(() => {
  //     console.log('Users state after fetch:', users);
  //   });
  // }, []);

  useEffect(() => {
    fetchUsers(); // This should call the fetchUsers function from the context
  }, []); // Empty dependency array to call it on component mount

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
  useEffect(() => {

    if (sessionId) {
      fetchUsers();

      // If you want to periodically update the list of users, you can use setInterval
      const intervalId = setInterval(fetchUsers, 5000); // Update every 5 seconds

      return () => {
        clearInterval(intervalId); // Clear the interval when the component is unmounted
      };
    }
  }, [sessionId]);

  useEffect(() => {
    // Save the current document title
    const originalTitle = document.title;

    // Update the document title
    document.title = "TuneFy Host";

    // Revert the document title back to the original title when the component unmounts
    return () => {
      document.title = originalTitle;
    };
    console.log(process.env);
  }, []);
  useEffect(() => {
    // Revert the favicon back to the original favicon when the component unmounts
    return () => {
      document
        .querySelector("link[rel='icon']")
        .setAttribute("href", "favicon-host.ico");
    };
  }, []);



  // Modify the useEffect hook to depend on fetchKey
  useEffect(() => {
    const fetchPlaylistAndUpdateState = async () => {
      await fetchPlaylist();
    };

    fetchPlaylistAndUpdateState();
  }, [fetchKey]); // Depend on fetchKey

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
  const handleCreateSession = async () => {
    console.log("Backend URL:", process.env.REACT_APP_BACKEND_URL);

    try {
      const response = await fetch(
        `${process.env.REACT_APP_BACKEND_URL}/create-session`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ username }),
        }
      );

      if (!response.ok) {
        throw new Error("Failed to create session");
      }

      const data = await response.json();
      setSessionId(data.sessionId);

      // Save the session ID to localStorage
      localStorage.setItem("sessionId", data.sessionId);
    } catch (error) {
      console.error("Error creating session:", error);
    }
  };

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
  useEffect(() => {
    const savedSessionId = localStorage.getItem("sessionId");
    if (savedSessionId) {
      setSessionId(savedSessionId);
    }
  }, []);
  useEffect(() => {
    // Fetch the initial list of users when the component mounts
    fetchUsers();
  }, []);

  const init = () => {
    window.gapi.client.setApiKey("AIzaSyAAL1GtGXpN3NEgcbRUqQvEzNaRMk740uM");
    window.gapi.client.load("youtube", "v3", () => {
      setIsApiReady(true);
    });
  };
  const handleRemoveUser = async (username) => {
    if (isUpdating) {
      // Early exit if an update is already in progress
      return;
    }

    setIsUpdating(true); // Set the lock to prevent further updates

    try {
      const response = await axios.post(
        `${process.env.REACT_APP_BACKEND_URL}/remove-user`,
        {
          sessionId,
          username,
        }
      );

      if (response.data.success) {
        console.log("Removed user successfully");
        // Update the UI accordingly
      } else {
        console.error("Failed to remove user");
      }
    } catch (error) {
      console.error("Error removing user:", error);
    } finally {
      setIsUpdating(false); // Release the lock after the update
      await fetchUsers(); // Fetch the updated user list
    }
  };

  const handleSearch = (search) => {
    if (search !== "" && isApiReady) {
      console.log(`API is ready. Performing search for: ${search}`);
      const request = window.gapi.client.youtube.search.list({
        part: "snippet",
        type: "video",
        q: encodeURIComponent(search).replace(/%20/g, "+") + " karaoke",
        maxResults: 3,
        order: "relevance",
      });

      request.execute((response) => {
        const items = response.result.items;
        console.log(`Search completed. Results:`, items);
        if (items.length === 0) {
          console.log("No results found. Attempting a simplified search.");
          // Perform a simplified search without the "karaoke" and "Unknown Artist" terms
          const simplifiedSearch = search.replace(/karaoke/gi, "").replace(/unknown artist/gi, "").trim();
          if (simplifiedSearch !== search) {
            // Only perform a simplified search if it's different from the original search
            handleSearch(simplifiedSearch);
          }
        } else {
          setResults(
            items.map((item) => ({
              title: item.snippet.title,
              videoId: item.id.videoId,
            }))
          );
        }
      });
    } else {
      if (search === "") {
        console.log("Search term is empty. No search performed.");
      }
      if (!isApiReady) {
        console.log("API is not ready. Search cannot be performed.");
      }
    }
  };
  const handlePlaySong = (fullTitle) => {
    // Remove common karaoke-related terms and emojis
    try {
      handleSearch(fullTitle);
    } catch (error) {
      console.error('Error playing song:', error);
    }// Construct the search string
  };


  const handleRemoveSong = async (songId) => {
    if (isUpdating) {
      // Early exit if an update is already in progress
      return;
    }

    setIsUpdating(true); // Set the lock to prevent further updates

    try {
      console.log('Trying to remove song by songid: ', songId);
      const response = await axios.delete(`${process.env.REACT_APP_BACKEND_URL}/songs/${songId}`);
      console.log('Song removed successfully', response.data);
    } catch (error) {
      console.error('Error removing song', error);
    } finally {
      setIsUpdating(false); // Release the lock after the update
      await fetchPlaylist(); // Fetch the updated playlist
    }
  };

  const resetVideoHeight = () => {
    const videoElements = document.querySelectorAll(".video");
    videoElements.forEach((videoElement) => {
      videoElement.style.height = `${document.getElementById("results").offsetWidth * (9 / 16)
        }px`;
    });
  };

  const fetchPlaylist = async () => {
    try {
      const response = await fetch(`${process.env.REACT_APP_BACKEND_URL}/playlist`);
      const data = await response.json();
      setSongs(data.sort((a, b) => b.votes - a.votes));
      console.log("Playlist fetched successfully");
      if (data && data.length > 0) {
        setIsPlaylistGenerated(true);
      }
    } catch (error) {
      console.error("Error fetching playlist:", error);
    }
  };
  const handleClearDatabase = async () => {
    try {
      // Send request to backend to clear database
      const response = await fetch(
        `${process.env.REACT_APP_BACKEND_URL}/clear-database`,
        {
          method: "POST",
        }
      );

      if (response.ok) {
        // Clear local storage
        localStorage.clear();

        // Reset state variables to their initial values
        setResults([]);
        setTopTracks([]);
        setLikedSongs([]);
        setUsername("");
        setSessionId("");
        setUsers([]);
        setVotes({});
        setSongs([]);
        setIsPlaylistGenerated(false);
        setError(null);

        // Handle other UI updates or notifications here
        console.log("Database and local storage cleared");
      } else {
        console.log("Failed to clear database");
      }
    } catch (error) {
      console.error("Error clearing database:", error);
    }
  };


  const joinLink = `${process.env.REACT_APP_FRONTEND_URL}/guestview?sessionId=${sessionId}`;
  return (
    <div className="container-fluid">
      <div className="row">
        {sessionId && (
          <div className="col-md-3">
            <div className="host-view">
              <h2 className="title">Host View</h2>
              <div className="guest-count">
                Number of guests: {users.length}
              </div>
              <div className="user-list">
                <h3 className="sub-title">Logged in users:</h3>
                <div className="user-list-container">
                  <table className="user-table">
                    <tbody>
                      {users.map((user) => (
                        <tr key={user}>
                          <td>{user}</td>
                          <td>
                            <button
                              onClick={() => handleRemoveUser(user)}
                              className='btn-remove'
                            >
                              Remove
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        )}
        <div className="col-md-6">
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
        {sessionId && (
          <div className="col-md-3">
            <div className="playlist-host-container">
              <div className="playlist-header-container">
                <h2 className="playlist-host-header">Playlist</h2>
                <button onClick={fetchPlaylist} className="refresh-playlist btn btn-secondary">
                  ⟳
                </button>
              </div>
              {error && <p className="playlist-host-error">Error: {error}</p>}
              <table className="playlist-host-table">
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
                      <td className="play-song-cell">
                        <button
                          className="play-song-button"
                          onClick={() =>
                            handlePlaySong(song.song_name, song.artist_name)
                          }
                        >
                          {song.song_name} - {song.artist_name}
                        </button>
                      </td>
                      <td>{song.votes || 0}</td>
                      <td>
                        <button
                          onClick={() => handleRemoveSong(song.id)}
                          className='btn-remove'
                        >
                          🗑️
                        </button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

          </div>
        )}
      </div>

      <div className="container">
        <input
          type="text"
          placeholder="Enter your username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          className="username-input"
        />
        <button onClick={handleCreateSession} className="create-session-button">
          Create Session
        </button>
        {sessionId && (
          <div className="session-info">
            <div className="session-id">Session ID: {sessionId}</div>
            <a href={joinLink} className="join-link">
              Join Link: {process.env.REACT_APP_FRONTEND_URL}/guestview?sessionId=
              {sessionId}
            </a>
            <div className="qr-code">
              <QRCode
                value={`${process.env.REACT_APP_FRONTEND_URL}/guestview?sessionId=${sessionId}`}
              />
            </div>
          </div>
        )}
      </div>

      {sessionId && (
        <button onClick={handleClearDatabase} className="btn btn-danger">
          Clear Database
        </button>
      )}
    </div >
  );
}

export default HostView;
