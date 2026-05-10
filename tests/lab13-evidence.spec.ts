import { test, expect } from '@playwright/test';
import * as path from 'path';

const repoRoot = process.cwd();
const evidencePage = `file://${path.join(repoRoot, 'app_python/docs/lab13screens/lab13-evidence.html')}`;
const screenshotDir = path.join(repoRoot, 'app_python/docs/lab13screens');

test.describe('Lab 13 evidence screenshots', () => {
  test('capture report evidence sections', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(evidencePage);
    await expect(page.getByRole('heading', { name: 'Lab 13 - GitOps with ArgoCD' })).toBeVisible();

    await page.screenshot({
      path: path.join(screenshotDir, '01-lab13-overview.png'),
      fullPage: true,
    });

    await page.locator('#environments').screenshot({
      path: path.join(screenshotDir, '02-lab13-environments.png'),
    });

    await page.locator('#policies').screenshot({
      path: path.join(screenshotDir, '03-lab13-sync-policies.png'),
    });

    await page.locator('#applicationset').screenshot({
      path: path.join(screenshotDir, '04-lab13-applicationset.png'),
    });
  });
});
