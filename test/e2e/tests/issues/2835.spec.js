import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

const textFile = (name) => ({
  name,
  mimeType: "text/plain",
  buffer: Buffer.from(name),
});

// https://github.com/phoenixframework/phoenix_live_view/issues/2835
test("auto upload never uploads entries over max_entries", async ({ page }) => {
  await page.goto("/issues/2835");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");
  const excessEntry = page.locator('.upload-entry[data-name="c.txt"]');
  const errors = page.locator(".upload-error");

  await input.setInputFiles([
    textFile("a.txt"),
    textFile("b.txt"),
    textFile("c.txt"),
  ]);

  await expect(page.locator("#consumed")).toHaveText("consumed: a.txt,b.txt");
  // the excess entry is kept with the error even after the others are consumed
  await expect(excessEntry).toContainText("c.txt: 0%");
  await expect(errors).toHaveText(":too_many_files");
  await expect(input).toHaveAttribute("data-phx-preflighted-refs", "");

  // new files can still be uploaded, but the excess entry is not
  await input.setInputFiles([textFile("d.txt")]);
  await expect(page.locator("#consumed")).toHaveText(
    "consumed: a.txt,b.txt,d.txt",
  );
  await expect(excessEntry).toContainText("c.txt: 0%");
  await expect(errors).toHaveText(":too_many_files");

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.locator("#submitted")).toHaveText("submitted: false");

  await excessEntry.getByRole("button", { name: "Cancel" }).click();
  await expect(excessEntry).toHaveCount(0);
  await expect(errors).toHaveCount(0);
  await syncLV(page);

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.locator("#submitted")).toHaveText("submitted: true");
  await expect(page.locator("[data-phx-main]")).toHaveClass(/phx-connected/);
});
