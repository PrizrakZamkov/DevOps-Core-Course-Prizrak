import { test, expect } from '@playwright/test';
import * as path from 'path';

const repoRoot = process.cwd();
const evidencePage = `file://${path.join(repoRoot, 'app_python/docs/lab15screens/lab15-evidence.html')}`;
const screenshotDir = path.join(repoRoot, 'app_python/docs/lab15screens');

test.describe('Lab 15 evidence screenshots', () => {
  test('capture statefulset evidence sections', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(evidencePage);
    await expect(page.getByRole('heading', { name: 'Lab 15 - StatefulSets' })).toBeVisible();

    await page.screenshot({
      path: path.join(screenshotDir, '01-lab15-overview.png'),
      fullPage: true,
    });

    await page.locator('#statefulset').screenshot({
      path: path.join(screenshotDir, '02-lab15-statefulset.png'),
    });

    await page.locator('#storage').screenshot({
      path: path.join(screenshotDir, '03-lab15-storage-dns.png'),
    });

    await page.locator('#updates').screenshot({
      path: path.join(screenshotDir, '04-lab15-update-strategies.png'),
    });
  });
});
