import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

// https://github.com/phoenixframework/phoenix_live_view/issues/2835
test("auto upload never uploads entries beyond max_entries", async ({
  page,
}) => {
  await page.goto("/issues/2835");
  await syncLV(page);

  await page.locator("#upload-form input[type='file']").setInputFiles([
    { name: "a.txt", mimeType: "text/plain", buffer: Buffer.from("a") },
    { name: "b.txt", mimeType: "text/plain", buffer: Buffer.from("b") },
    { name: "c.txt", mimeType: "text/plain", buffer: Buffer.from("c") },
  ]);

  await expect(page.locator("#consumed")).toHaveText("consumed: a.txt,b.txt");
  await syncLV(page);

  const excessEntry = page.locator('.upload-entry[data-name="c.txt"]');
  await expect(excessEntry).toContainText("c.txt: 0%");
  await expect(page.locator(".upload-error")).toHaveText(":too_many_files");

  // the excess entry must neither be uploaded nor allow the form to be submitted
  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.locator("#submitted")).toHaveText("submitted: false");
  await expect(page.locator("#consumed")).toHaveText("consumed: a.txt,b.txt");

  await excessEntry.getByRole("button", { name: "Cancel" }).click();
  await expect(excessEntry).toHaveCount(0);
  await expect(page.locator(".upload-error")).toHaveCount(0);
  await syncLV(page);

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.locator("#submitted")).toHaveText("submitted: true");
  await expect(page.locator("#consumed")).toHaveText("consumed: a.txt,b.txt");
});
