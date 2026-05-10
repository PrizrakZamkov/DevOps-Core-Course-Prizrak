import { test, expect } from '@playwright/test';
import * as path from 'path';

const repoRoot = process.cwd();
const evidencePage = `file://${path.join(repoRoot, 'app_python/docs/lab17screens/lab17-evidence.html')}`;
const screenshotDir = path.join(repoRoot, 'app_python/docs/lab17screens');

test.describe('Lab 17 evidence screenshots', () => {
  test('capture Fly.io evidence sections', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(evidencePage);
    await expect(page.getByRole('heading', { name: 'Lab 17 - Fly.io Edge Deployment' })).toBeVisible();

    await page.screenshot({
      path: path.join(screenshotDir, '01-lab17-overview.png'),
      fullPage: true,
    });

    await page.locator('#config').screenshot({
      path: path.join(screenshotDir, '02-lab17-fly-config.png'),
    });

    await page.locator('#regions').screenshot({
      path: path.join(screenshotDir, '03-lab17-regions.png'),
    });

    await page.locator('#ops').screenshot({
      path: path.join(screenshotDir, '04-lab17-ops-comparison.png'),
    });
  });
});
