import React, { useState, useEffect } from "react";
import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import HostView from "./components/HostView";
import axios from "axios";
import GuestView from "./components/GuestView";
import { UserProvider } from "./contexts/UserContext";
import SpotifyCallback from "./components/SpotifyCallback";
import "bootstrap/dist/css/bootstrap.min.css";
import "./App.css";

function App() {
  return (
    <UserProvider>
      <Router>
        <div className="container">
          <header className="text-center my-4">
            <h1>
              <a href="/">Tunefy</a>
            </h1>
          </header>
          <Routes>
            <Route path="/" element={<HostView />} />
            <Route path="/guestview" element={<GuestView />} />
            <Route path="/callback" element={<SpotifyCallback />} />
          </Routes>
        </div>
      </Router>
    </UserProvider>
  );
}

export default App;
