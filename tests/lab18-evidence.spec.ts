import { test, expect } from '@playwright/test';
import * as path from 'path';

const repoRoot = process.cwd();
const evidencePage = `file://${path.join(repoRoot, 'app_python/docs/lab18screens/lab18-evidence.html')}`;
const staticSite = process.env.LAB18_IPFS_URL ?? `file://${path.join(repoRoot, 'labs/lab18/index.html')}`;
const screenshotDir = path.join(repoRoot, 'app_python/docs/lab18screens');

test.describe('Lab 18 evidence screenshots', () => {
  test('capture 4EVERLAND and IPFS evidence sections', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });

    await page.goto(staticSite);
    await expect(page.getByRole('heading', { name: /Production-Grade/ })).toBeVisible();
    await page.screenshot({
      path: path.join(screenshotDir, '01-lab18-static-site.png'),
      fullPage: true,
    });

    await page.goto(evidencePage);
    await expect(page.getByRole('heading', { name: 'Lab 18 - 4EVERLAND & IPFS' })).toBeVisible();

    await page.locator('#ipfs').screenshot({
      path: path.join(screenshotDir, '02-lab18-ipfs-node.png'),
    });

    await page.locator('#deployment').screenshot({
      path: path.join(screenshotDir, '03-lab18-4everland-deploy.png'),
    });

    await page.locator('#gateways').screenshot({
      path: path.join(screenshotDir, '04-lab18-gateway-pinning.png'),
    });
  });
});
