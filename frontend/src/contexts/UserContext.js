import React, { createContext, useState } from "react";
import axios from "axios";

export const UserContext = createContext({
    users: [],
    setUsers: () => { },
    fetchUsers: () => { },
    // ... other shared state or functions
});

export const UserProvider = ({ children }) => {
    const [users, setUsers] = useState([]);

    const fetchUsers = async () => {
        try {
            const sessionId = localStorage.getItem("sessionId");
            if (!sessionId) {
                console.error("Session ID not found");
                return;
            }

            const response = await axios.get(
                `${process.env.REACT_APP_BACKEND_URL}/session-users`,
                {
                    params: {
                        sessionId,
                    },
                }
            );

            const { host, guests } = response.data;
            console.log('Fetched users:', { host, guests }); // Log the fetched users
            setUsers([host, ...guests]);
        } catch (error) {
            console.error("Error fetching users:", error);
        }
    };

    return (
        <UserContext.Provider value={{ users, setUsers, fetchUsers }}>
            {children}
        </UserContext.Provider>
    );
};