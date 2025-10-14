# Tunefy

Tunefy is a collaborative music session application that allows a host to create a session and guests to join and contribute to a shared playlist. The application is split into a frontend React application and a backend Express server, with a PostgreSQL database to manage the data.

## Features

- Host and Guest views for managing music sessions
- Spotify API integration for music selection and playback
- Real-time session management with unique session IDs
- Playlist management with the ability to add and remove songs
- Voting system for songs in the playlist
- Caching mechanism for playlists and votes to reduce database load
- Ability for not-logged-in users to send songs to the shared playlist

## Getting Started

To get the application running, you'll need to set up both the frontend and backend parts of the project.

### Prerequisites

- Node.js
- npm (Node Package Manager)
- PostgreSQL database

### Installation

#### Backend Setup

1. Navigate to the `backend` directory.
2. Install the required npm packages:

```sh
npm install
```

3. Set up the PostgreSQL database using the provided `init.sql` script in the `database/scripts` directory.
4. Create a `.env` file in the `backend` directory with the following environment variables:

```
PGHOST=<your_database_host>
PGUSER=<your_database_user>
PGDATABASE=<your_database_name>
PGPASSWORD=<your_database_password>
PGPORT=<your_database_port>
```

5. Start the backend server:

```sh
npm start
```

The server will start running on `http://192.168.1.6:3001`.

#### Frontend Setup

1. Navigate to the `frontend` directory.
2. Install the required npm packages:

```sh
npm install
```

3. Start the React development server:

```sh
npm start
```

The application will open in your default web browser at `http://192.168.1.6:3000`.

### Usage

- Access the host view by navigating to the root URL `/`.
- Guests can join a session by navigating to `/guestview` and entering a valid session ID.
- The Spotify callback route `/callback` is used for handling OAuth authentication with Spotify.

### Add environment variables
GOOGLE_KEY="AIzaSyAAL1GtGXpN3NEgcbRUqQvEzNaRMk740uM"
AI21_TOKEN="mJ4SfZVGu3Yn1MtQqpbNt1NpzhvbbE6i"

## API Endpoints

The backend server exposes several API endpoints for session and playlist management:

- POST `/create-session`: Create a new music session.
- POST `/join-session`: Join an existing music session.
- POST `/leave-session`: Leave a music session.
- GET `/session-users`: Get the list of users in a session.
- POST `/playlist`: Manage the playlist for a session.
- GET `/playlist`: Retrieve the current playlist.
- POST `/vote`: Vote for a song in the playlist.
- POST `/clear-database`: Clear the database (use with caution).
- POST `/add-song`: Add a song to the playlist. If the user is not logged in, the `user_id` will be `null`.

## File Structure

The project is organized into the following directories and files:

```
.
├── backend
│   ├── package-lock.json
│   ├── package.json
│   └── server.js
├── database
│   └── scripts
│       └── init.sql
└── frontend
    ├── package-lock.json
    ├── package.json
    ├── public
    │   ├── favicon.ico
    │   ├── index.html
    │   └── ...
    └── src
        ├── App.css
        ├── App.js
        ├── components
        │   ├── GuestView.js
        │   ├── HostView.js
        │   ├── SpotifyCallback.js
        │   └── ...
        └── index.js
```

## Infrastructure and DevOps

This project includes comprehensive infrastructure as code and CI/CD pipelines:

### Deployment
- **Kubernetes:** Self-managed cluster on AWS EC2 (Control Plane + Worker nodes)
- **CNI:** Calico v3.27.0 with VXLAN overlay networking
- **Container Registry:** AWS ECR
- **Monitoring:** Prometheus + Grafana stack

### CI/CD Pipeline
- **Build:** TeamCity (6-step pipeline: checkout, build images, push to ECR, package charts)
- **Deploy:** Octopus Deploy (automated deployment to Kubernetes with smoke tests)
- **Observability:** Grafana accessible via AWS ALB

### Documentation
For operations, deployment, and disaster recovery procedures, see:

- **[Disaster Recovery Complete Guide](docs/importants/DISASTER_RECOVERY_COMPLETE_GUIDE.md)** - Full documentation of infrastructure recovery, networking troubleshooting, and CI/CD setup
- **[Recovery Quick Reference](docs/importants/RECOVERY_QUICK_REFERENCE.md)** - Quick troubleshooting guide for common issues
- **[C7 Observability Checklist](docs/importants/C7-Observability-Checklist.md)** - Monitoring implementation checklist
- **[CI/CD Implementation](docs/importants/CICD_IMPLEMENTATION.md)** - TeamCity and Octopus configuration details

### Infrastructure Management
```bash
# Deploy infrastructure with Terraform
cd infra/terraform/compute-dev
terraform plan
terraform apply

# Access cluster
ssh -J ubuntu@<bastion-ip> ubuntu@<cp-private-ip>
kubectl get nodes
```

For detailed troubleshooting, Security Group configurations, and operational procedures, refer to the disaster recovery documentation.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or create issues for bugs and feature requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.