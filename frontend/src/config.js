// API configuration
// Use relative paths in production to leverage nginx proxy
// Fallback to env variable for development

const getBackendUrl = () => {
  // If REACT_APP_BACKEND_URL is set to a full URL (starts with http), use it
  // Otherwise, use relative path for nginx proxy
  const envUrl = process.env.REACT_APP_BACKEND_URL || '';
  
  if (envUrl.startsWith('http')) {
    return envUrl;
  }
  
  // Use relative path for production (nginx will proxy /api to backend)
  return '/api';
};

export const BACKEND_URL = getBackendUrl();
export const FRONTEND_URL = process.env.REACT_APP_FRONTEND_URL || window.location.origin;
export const GOOGLE_API_KEY = process.env.REACT_APP_GOOGLE_KEY || '';
