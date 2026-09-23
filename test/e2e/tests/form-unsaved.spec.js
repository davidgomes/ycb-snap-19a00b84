import { test, expect } from "../test-fixtures";
import { syncLV } from "../utils";

test("can guard unsaved form changes against live navigation", async ({
  page,
}) => {
  let networkEvents = [];
  page.on("request", (request) =>
    networkEvents.push({ method: request.method(), url: request.url() }),
  );

  await page.goto("/form-unsaved");
  await syncLV(page);

  await page.locator("#unsaved-note").fill("draft");
  await syncLV(page);
  await expect(page.locator("#unsaved-value")).toHaveText(
    "Unsaved value: draft",
  );

  networkEvents = [];
  const leaveLink = page.getByRole("link", { name: "Leave form" });
  const navigationDetail = {
    href: "http://localhost:4004/form-unsaved/target",
    patch: false,
    pop: false,
    direction: "forward",
  };

  // dismissing the confirm dialog cancels the live navigation
  let dialogPromise = page.waitForEvent("dialog");
  let clickPromise = leaveLink.click();
  let dialog = await dialogPromise;
  expect(dialog.type()).toBe("confirm");
  expect(dialog.message()).toBe(
    "You have unsaved changes. Leave without saving?",
  );
  await dialog.dismiss();
  await clickPromise;

  await expect(page).toHaveURL("/form-unsaved");
  expect(await page.evaluate(() => window.unsavedEvents)).toEqual([
    navigationDetail,
  ]);

  // the LiveView is still connected and handles events
  await page.locator("#unsaved-note").fill("draft after cancel");
  await syncLV(page);
  await expect(page.locator("#unsaved-value")).toHaveText(
    "Unsaved value: draft after cancel",
  );

  // accepting the confirm dialog performs the live navigation
  dialogPromise = page.waitForEvent("dialog");
  clickPromise = leaveLink.click();
  dialog = await dialogPromise;
  await dialog.accept();
  await clickPromise;
  await syncLV(page);

  await expect(page).toHaveURL("/form-unsaved/target");
  await expect(
    page.getByRole("heading", { name: "Unsaved form target" }),
  ).toBeVisible();
  expect(await page.evaluate(() => window.unsavedEvents)).toEqual([
    navigationDetail,
    navigationDetail,
  ]);
  // everything happened over the websocket, no page reloads
  expect(networkEvents).toEqual([]);
});
