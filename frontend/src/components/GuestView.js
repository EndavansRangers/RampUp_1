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
    const usernameFromURL = params.get("username"); // Get sessionId from URL parameters
    const usernamefromToken = localStorage.getItem("spotifyAccessToken");
    console.log("URL username:", usernameFromURL); // Log the username from URL parameters
    if (usernameFromURL || usernamefromToken) {
      setUsername(usernameFromURL); // Update the username state variable
      localStorage.setItem("username", usernameFromURL);
      const localUsername = localStorage.getItem("username");
      console.log("localStorage username:", localUsername); // Log the sessionId from localStorage
      setIsJoined(true);
      setGuestName(localUsername);
    } else {
      setIsJoined(false);
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
  const handleUsernameSubmit = (username) => {
    setUsername(username);
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
      <p>Link ID: {sessionId}</p>
      <div>Welcome, {guestName}!</div>
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
        <button onClick={handleLeaveSession} className="btn btn-danger">
          Leave Session
        </button>
      )}
    </div>
  );
}

export default GuestView;
