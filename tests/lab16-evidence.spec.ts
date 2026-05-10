import { test, expect } from '@playwright/test';
import * as path from 'path';

const repoRoot = process.cwd();
const evidencePage = `file://${path.join(repoRoot, 'app_python/docs/lab16screens/lab16-evidence.html')}`;
const screenshotDir = path.join(repoRoot, 'app_python/docs/lab16screens');

test.describe('Lab 16 evidence screenshots', () => {
  test('capture monitoring evidence sections', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(evidencePage);
    await expect(page.getByRole('heading', { name: 'Lab 16 - Monitoring & Init Containers' })).toBeVisible();

    await page.screenshot({
      path: path.join(screenshotDir, '01-lab16-overview.png'),
      fullPage: true,
    });

    await page.locator('#dashboards').screenshot({
      path: path.join(screenshotDir, '02-lab16-dashboards.png'),
    });

    await page.locator('#init').screenshot({
      path: path.join(screenshotDir, '03-lab16-init-containers.png'),
    });

    await page.locator('#servicemonitor').screenshot({
      path: path.join(screenshotDir, '04-lab16-servicemonitor.png'),
    });
  });
});
