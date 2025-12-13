require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

// Enable CORS for all routes
app.use(cors({
  origin: true,
  credentials: true
}));

// Proxy endpoint for YouTube thumbnails
app.get('/thumbnail/:videoId', async (req, res) => {
  const { videoId } = req.params;
  const thumbnailQualities = ['maxresdefault', 'sddefault', 'hqdefault', 'mqdefault', 'default'];

  for (const quality of thumbnailQualities) {
    try {
      const thumbnailUrl = `https://img.youtube.com/vi/${videoId}/${quality}.jpg`;
      const response = await axios.get(thumbnailUrl, {
        responseType: 'arraybuffer',
        timeout: 5000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; ThumbnailProxy/1.0)'
        }
      });

      if (response.status === 200) {
        res.set({
          'Content-Type': 'image/jpeg',
          'Cache-Control': 'public, max-age=86400', // Cache for 24 hours
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET',
          'Access-Control-Allow-Headers': 'Content-Type'
        });
        return res.send(Buffer.from(response.data, 'binary'));
      }
    } catch (error) {
      // Continue to next quality if this one fails
      continue;
    }
  }

  // If all qualities fail, return a default placeholder
  res.status(404).json({ error: 'Thumbnail not found' });
});

// Proxy endpoint for Supabase chat images
app.get('/chat-image/:fileName', async (req, res) => {
  const { fileName } = req.params;

  try {
    // Construct the Supabase storage URL
    const supabaseUrl = process.env.SUPABASE_URL || 'https://your-project.supabase.co';
    const imageUrl = `${supabaseUrl}/storage/v1/object/public/chat-media/${fileName}`;

    const response = await axios.get(imageUrl, {
      responseType: 'arraybuffer',
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; ChatImageProxy/1.0)',
        'Authorization': req.headers.authorization || '' // Pass through auth if present
      }
    });

    if (response.status === 200) {
      // Determine content type from response headers or file extension
      const contentType = response.headers['content-type'] ||
        (fileName.toLowerCase().endsWith('.png') ? 'image/png' :
         fileName.toLowerCase().endsWith('.gif') ? 'image/gif' : 'image/jpeg');

      res.set({
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      });
      return res.send(Buffer.from(response.data, 'binary'));
    }
  } catch (error) {
    console.error('Error proxying chat image:', error.message);
  }

  // If image fails to load, return a default placeholder
  res.status(404).json({ error: 'Image not found' });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Thumbnail proxy server running on port ${PORT}`);
});

module.exports = app;
