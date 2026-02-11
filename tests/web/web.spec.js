// @ts-check
const { test, expect } = require('@playwright/test');
const path = require('path');

test('JSCL web tests pass', async ({ page }) => {
  const testHtml = 'file://' + path.resolve(__dirname, '../../dist/test.html');
  await page.goto(testHtml);

  const results = page.locator('#test-results');
  await expect(results).not.toBeEmpty({ timeout: 30000 });

  const text = await results.textContent();
  expect(text).toMatch(/^PASS/);
});
