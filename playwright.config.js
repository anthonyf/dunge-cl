// @ts-check
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests/web',
  testMatch: '*.spec.js',
  timeout: 60000,
  use: {
    browserName: 'chromium',
    headless: true,
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
  ],
});
