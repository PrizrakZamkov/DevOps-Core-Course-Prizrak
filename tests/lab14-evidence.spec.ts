import { test, expect } from '@playwright/test';
import * as path from 'path';

const repoRoot = process.cwd();
const evidencePage = `file://${path.join(repoRoot, 'app_python/docs/lab14screens/lab14-evidence.html')}`;
const screenshotDir = path.join(repoRoot, 'app_python/docs/lab14screens');

test.describe('Lab 14 evidence screenshots', () => {
  test('capture progressive delivery evidence sections', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(evidencePage);
    await expect(page.getByRole('heading', { name: 'Lab 14 - Progressive Delivery' })).toBeVisible();

    await page.screenshot({
      path: path.join(screenshotDir, '01-lab14-overview.png'),
      fullPage: true,
    });

    await page.locator('#canary').screenshot({
      path: path.join(screenshotDir, '02-lab14-canary.png'),
    });

    await page.locator('#bluegreen').screenshot({
      path: path.join(screenshotDir, '03-lab14-bluegreen.png'),
    });

    await page.locator('#analysis').screenshot({
      path: path.join(screenshotDir, '04-lab14-analysis.png'),
    });
  });
});
