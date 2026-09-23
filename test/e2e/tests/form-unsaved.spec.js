import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

const message = "You have unsaved changes. Leave anyway?";
let dialogs = [];
let acceptDialogs = false;

test.beforeEach(async ({ page }) => {
  dialogs = [];
  acceptDialogs = false;
  page.on("dialog", async (dialog) => {
    dialogs.push(dialog.message());
    await (acceptDialogs ? dialog.accept() : dialog.dismiss());
  });
});

test("does not ask for confirmation without unsaved changes", async ({
  page,
}) => {
  await page.goto("/form/unsaved");
  await syncLV(page);

  await page.getByRole("link", { name: "Navigate away" }).click();
  await expect(page.getByRole("heading", { name: "Away" })).toBeVisible();
  await expect(page).toHaveURL("/form/unsaved/away");
  expect(dialogs).toEqual([]);
});

test("asks for confirmation before live navigation with unsaved changes", async ({
  page,
}) => {
  await page.goto("/form/unsaved");
  await syncLV(page);
  await page.locator("input[name=name]").fill("Hello");
  await syncLV(page);

  // dismissing the dialog cancels the navigation
  await page.getByRole("link", { name: "Navigate away" }).click();
  await page.getByRole("link", { name: "Patch" }).click();
  await page.getByRole("button", { name: "JS navigate" }).click();
  await expect.poll(() => dialogs).toEqual([message, message, message]);
  await expect(page).toHaveURL("/form/unsaved");
  await expect(page.locator("#patched")).not.toContainText("true");
  await expect(page.locator("input[name=name]")).toHaveValue("Hello");

  acceptDialogs = true;
  await page.getByRole("link", { name: "Patch" }).click();
  await expect(page.locator("#patched")).toHaveText("Patched: true");
  await expect(page).toHaveURL("/form/unsaved?patched=true");
  await expect(page.locator("input[name=name]")).toHaveValue("Hello");

  await page.getByRole("link", { name: "Navigate away" }).click();
  await expect(page.getByRole("heading", { name: "Away" })).toBeVisible();
  await expect(page).toHaveURL("/form/unsaved/away");
  expect(dialogs).toEqual([message, message, message, message, message]);
});

test("asks for confirmation before navigating back with unsaved changes", async ({
  page,
}) => {
  await page.goto("/form/unsaved/away");
  await syncLV(page);
  await page.getByRole("link", { name: "Back to form" }).click();
  await expect(
    page.getByRole("heading", { name: "Unsaved changes" }),
  ).toBeVisible();
  await syncLV(page);
  await page.locator("input[name=name]").fill("Hello");
  await syncLV(page);

  await page.evaluate(() => history.back());
  await expect.poll(() => dialogs).toEqual([message]);
  // the form page is restored
  await expect(page).toHaveURL("/form/unsaved");
  await expect(page.locator("input[name=name]")).toHaveValue("Hello");

  acceptDialogs = true;
  await page.evaluate(() => history.back());
  await expect(page.getByRole("heading", { name: "Away" })).toBeVisible();
  await expect(page).toHaveURL("/form/unsaved/away");
  expect(dialogs).toEqual([message, message]);
});

test("does not ask for confirmation after saving", async ({ page }) => {
  await page.goto("/form/unsaved");
  await syncLV(page);
  await page.locator("input[name=name]").fill("Hello");
  await syncLV(page);
  await page.getByRole("button", { name: "Save" }).click();
  await syncLV(page);
  await expect(page.locator("#saved")).toHaveText("Saved Hello");

  await page.getByRole("link", { name: "Navigate away" }).click();
  await expect(page.getByRole("heading", { name: "Away" })).toBeVisible();
  await expect(page).toHaveURL("/form/unsaved/away");
  expect(dialogs).toEqual([]);
});
