import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

// Configuration
const ARGOCD_URL = process.env.ARGOCD_URL || 'http://localhost:8080';
const ARGOCD_USERNAME = process.env.ARGOCD_USERNAME || 'admin';
const ARGOCD_PASSWORD = process.env.ARGOCD_PASSWORD || 'admin';
const SCREENSHOT_DIR = './app_python/docs/lab13screens';

// Create screenshots directory if it doesn't exist
if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

test.describe('Lab 13 - GitOps with ArgoCD', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to ArgoCD
    await page.goto(ARGOCD_URL, { waitUntil: 'networkidle' }).catch(() => {
      console.log('Waiting for ArgoCD to be available...');
    });

    // Wait for page to load or handle insecure context
    try {
      await page.waitForLoadState('networkidle', { timeout: 5000 });
    } catch (e) {
      console.log('Page loading timeout, continuing...');
    }
  });

  test('Login to ArgoCD and capture dashboard', async ({ page }) => {
    // Accept any certificate warnings if present
    try {
      if (await page.locator('button:has-text("Advanced")').isVisible({ timeout: 2000 })) {
        await page.click('button:has-text("Advanced")');
        await page.click('a:has-text("Proceed")');
      }
    } catch (e) {
      // Certificate warning not present
    }

    // Wait for login form
    await page.waitForSelector('input[name="username"]', { timeout: 10000 }).catch(() => {
      console.log('Login form not found, may already be logged in');
    });

    // Check if already logged in
    const loginButton = await page.locator('button:has-text("Login")').count();
    
    if (loginButton > 0) {
      // Fill login credentials
      await page.fill('input[name="username"]', ARGOCD_USERNAME);
      await page.fill('input[name="password"]', ARGOCD_PASSWORD);
      
      // Click login
      await page.click('button:has-text("Login")');
      
      // Wait for dashboard to load
      await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {
        console.log('Navigation not detected');
      });
    }

    // Take dashboard screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '01-argocd-dashboard.png'), fullPage: true });
    console.log('Saved: 01-argocd-dashboard.png');
  });

  test('Navigate to applications and capture status', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped, assuming already logged in');
    }

    // Click on Applications in sidebar
    const appsLink = await page.locator('a:has-text("Applications")').first().count();
    if (appsLink > 0) {
      await page.click('a:has-text("Applications")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Take applications list screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '02-applications-list.png'), fullPage: true });
    console.log('Saved: 02-applications-list.png');
  });

  test('View python-app-dev application details', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped');
    }

    // Navigate to applications
    const appsLink = await page.locator('a:has-text("Applications")').first().count();
    if (appsLink > 0) {
      await page.click('a:has-text("Applications")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Click on python-app-dev
    const devAppLink = await page.locator('text=python-app-dev').first().count();
    if (devAppLink > 0) {
      await page.click('text=python-app-dev');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
      await page.waitForTimeout(2000);
    }

    // Take dev application details screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '03-app-dev-details.png'), fullPage: true });
    console.log('Saved: 03-app-dev-details.png');
  });

  test('View python-app-prod application details', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped');
    }

    // Navigate to applications
    const appsLink = await page.locator('a:has-text("Applications")').first().count();
    if (appsLink > 0) {
      await page.click('a:has-text("Applications")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Click on python-app-prod
    const prodAppLink = await page.locator('text=python-app-prod').first().count();
    if (prodAppLink > 0) {
      await page.click('text=python-app-prod');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
      await page.waitForTimeout(2000);
    }

    // Take prod application details screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '04-app-prod-details.png'), fullPage: true });
    console.log('Saved: 04-app-prod-details.png');
  });

  test('View application synchronization status', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped');
    }

    // Navigate to applications
    const appsLink = await page.locator('a:has-text("Applications")').first().count();
    if (appsLink > 0) {
      await page.click('a:has-text("Applications")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Take sync status screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '05-sync-status.png'), fullPage: true });
    console.log('Saved: 05-sync-status.png');
  });

  test('View application resources and health', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped');
    }

    // Navigate to applications
    const appsLink = await page.locator('a:has-text("Applications")').first().count();
    if (appsLink > 0) {
      await page.click('a:has-text("Applications")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Click on python-app-dev to view resources
    const devAppLink = await page.locator('text=python-app-dev').first().count();
    if (devAppLink > 0) {
      await page.click('text=python-app-dev');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
      
      // Scroll down to see resources
      await page.evaluate(() => window.scrollBy(0, window.innerHeight));
      await page.waitForTimeout(1000);
    }

    // Take resources screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '06-resources-health.png'), fullPage: true });
    console.log('Saved: 06-resources-health.png');
  });

  test('Capture application tree view', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped');
    }

    // Navigate to applications
    const appsLink = await page.locator('a:has-text("Applications")').first().count();
    if (appsLink > 0) {
      await page.click('a:has-text("Applications")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Click on python-app-dev
    const devAppLink = await page.locator('text=python-app-dev').first().count();
    if (devAppLink > 0) {
      await page.click('text=python-app-dev');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
      
      // Click on tree view tab if available
      const treeTab = await page.locator('[aria-label*="tree"], [title*="tree"]').count();
      if (treeTab > 0) {
        await page.click('[aria-label*="tree"], [title*="tree"]');
        await page.waitForTimeout(1500);
      }
    }

    // Take tree view screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '07-tree-view.png'), fullPage: true });
    console.log('Saved: 07-tree-view.png');
  });

  test('Capture ArgoCD settings and configuration', async ({ page }) => {
    // Login first
    try {
      const loginButton = await page.locator('button:has-text("Login")').count();
      if (loginButton > 0) {
        await page.fill('input[name="username"]', ARGOCD_USERNAME);
        await page.fill('input[name="password"]', ARGOCD_PASSWORD);
        await page.click('button:has-text("Login")');
        await page.waitForNavigation({ waitUntil: 'networkidle' }).catch(() => {});
      }
    } catch (e) {
      console.log('Login skipped');
    }

    // Click on Settings/Configuration
    const settingsLink = await page.locator('a:has-text("Settings"), a:has-text("Administration")').first().count();
    if (settingsLink > 0) {
      await page.click('a:has-text("Settings"), a:has-text("Administration")');
      await page.waitForLoadState('networkidle', { timeout: 5000 }).catch(() => {});
    }

    // Take settings screenshot
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, '08-settings.png'), fullPage: true });
    console.log('Saved: 08-settings.png');
  });
});
