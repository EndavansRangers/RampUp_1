import { render, screen } from '@testing-library/react';
import App from './App';
test('renderiza la app', () => {
  render(<App />);
  expect(screen.getByText(/tunefy/i)).toBeInTheDocument();
});
