module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/src/setupTests.js'],
  reporters: ['default', ['jest-junit', { outputDirectory: 'reports', outputName: 'junit-frontend.xml' }]],
};
