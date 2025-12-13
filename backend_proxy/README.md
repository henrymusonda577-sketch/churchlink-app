# YouTube Thumbnail Proxy Server

This proxy server resolves CORS issues when loading YouTube thumbnails in web applications.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the server:
   ```bash
   npm start
   ```

   For development with auto-restart:
   ```bash
   npm run dev
   ```

The server will run on `http://localhost:3001` by default.

## API

### GET /thumbnail/:videoId

Fetches the best available YouTube thumbnail for the given video ID.

- **Parameters:**
  - `videoId`: YouTube video ID (e.g., `Sc6SSHuZvQE`)

- **Response:**
  - JPEG image with proper CORS headers
  - Falls back through thumbnail qualities: maxresdefault → sddefault → hqdefault → mqdefault → default

- **Example:**
  ```
  GET http://localhost:3001/thumbnail/Sc6SSHuZvQE
  ```

### GET /health

Health check endpoint.

- **Response:**
  ```json
  {
    "status": "OK",
    "timestamp": "2024-01-01T00:00:00.000Z"
  }
  ```

## Deployment

For production, deploy this server to a service like Heroku, Vercel, or AWS Lambda, and update the thumbnail URLs in the Flutter app to use the production URL instead of `http://localhost:3001`.

## Troubleshooting

- Ensure the server is running before starting the Flutter app.
- Check console logs for any errors.
- If thumbnails still fail, verify the video ID is correct.
