import React, { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import axios from "axios"; // Make sure to import axios

function SpotifyCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    const fetchSpotifyProfileAndNavigate = async () => {
      // Log the full URL for debugging purposes
      console.log("Full URL:", window.location.href);

      // Extract the Spotify Auth token from the fragment
      const fragment = window.location.hash.substring(1);
      const params = new URLSearchParams(fragment);
      const token = params.get("access_token");

      // Log the extracted token for debugging purposes
      console.log("Extracted Spotify Auth token:", token);

      if (token) {
        // Store the Spotify Auth token in localStorage
        localStorage.setItem("spotifyAccessToken", token);

        try {
          const response = await axios.get("https://api.spotify.com/v1/me", {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          });
          const data = response.data; // No need to call .json() when using axios
          console.log("Got Spotify user profile:", data);

          localStorage.setItem("username", data.display_name);

          // Retrieve the linkId from localStorage
          const linkId = localStorage.getItem("sessionId");
          const username = localStorage.getItem("username");

          // Log the linkId for debugging purposes
          console.log("Retrieved linkId from localStorage:", linkId);

          if (linkId) {
            // Redirect to the Guest View with the appropriate linkId
            navigate(`/guestview?sessionId=${linkId}&username=${username}`);
          } else {
            // Handle the error case
            console.log("Error: linkId not found in localStorage");
            // You might want to navigate to an error page or show an error message here
          }
        } catch (error) {
          console.error("Error fetching Spotify user profile:", error);
          // Handle the error case, possibly with a redirect or error message
        }
      } else {
        // Handle the error case
        console.log("Error: Spotify Auth token not found");
        // You might want to navigate to an error page or show an error message here
      }
    };

    fetchSpotifyProfileAndNavigate();
  }, [navigate]);

  return (
    <div>
      <h2>Spotify Callback</h2>
      <p>Handling Spotify Auth callback...</p>
    </div>
  );
}

export default SpotifyCallback;
