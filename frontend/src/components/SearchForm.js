import React, { useState } from "react";

function SearchForm({ onSearch }) {
  const [search, setSearch] = useState("");

  const handleSubmit = (e) => {
    e.preventDefault();
    onSearch(search);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Type in your song..."
        autoComplete="off"
        className="form-control"
      />
      <button type="submit" className="btn btn-primary w-100 mt-2">
        Search
      </button>
    </form>
  );
}

export default SearchForm;
