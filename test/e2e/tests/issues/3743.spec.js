import { test, expect } from "../../test-fixtures";
import { syncLV } from "../../utils";

const pdf = (name, content) => ({
  name,
  mimeType: "application/pdf",
  buffer: Buffer.from(content),
});

// https://github.com/phoenixframework/phoenix_live_view/issues/3743
test("a writer failure remains visible until it is cancelled", async ({
  page,
}) => {
  await page.goto("/issues/3743");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");

  await input.setInputFiles([
    pdf("good.pdf", "0000000000"),
    pdf("bad.pdf", "00000error"),
  ]);

  const failedEntry = page.locator('.upload-entry[data-name="bad.pdf"]');
  await expect(failedEntry.locator(".upload-error")).toHaveText(
    "{:writer_failure, :invalid_pdf}",
  );
  await expect(page.locator("#consumed")).toHaveText("consumed: good.pdf");
  await expect(page.locator("[data-phx-main]")).toHaveClass(/phx-connected/);

  // the failed entry stays pending on the client until it is cancelled
  await expect(input).not.toHaveAttribute("data-phx-active-refs", "");
  const failedRef = await input.getAttribute("data-phx-active-refs");
  await expect(input).toHaveAttribute("data-phx-preflighted-refs", failedRef);
  await expect(input).toHaveAttribute("data-phx-done-refs", "");

  await failedEntry.getByRole("button", { name: "Cancel" }).click();
  await expect(failedEntry).toHaveCount(0);
  await syncLV(page);

  await page.getByRole("button", { name: "Submit" }).click();
  await syncLV(page);
  await expect(page.locator("#submitted")).toHaveText("submitted: true");

  await input.setInputFiles([pdf("retry.pdf", "0000000000")]);
  await expect(page.locator("#consumed")).toHaveText(
    "consumed: retry.pdf,good.pdf",
  );
  await expect(page.locator(".upload-entry")).toHaveCount(0);
});

test("a writer init failure remains visible until it is cancelled", async ({
  page,
}) => {
  await page.goto("/issues/3743");
  await syncLV(page);

  const input = page.locator("#upload-form input[type='file']");

  await input.setInputFiles([pdf("init_error.pdf", "0000000000")]);

  const failedEntry = page.locator('.upload-entry[data-name="init_error.pdf"]');
  await expect(failedEntry.locator(".upload-error")).toHaveText(
    "{:writer_failure, :init_failed}",
  );
  await expect(page.locator("[data-phx-main]")).toHaveClass(/phx-connected/);

  await failedEntry.getByRole("button", { name: "Cancel" }).click();
  await expect(failedEntry).toHaveCount(0);
  await syncLV(page);

  await input.setInputFiles([pdf("retry.pdf", "0000000000")]);
  await expect(page.locator("#consumed")).toHaveText("consumed: retry.pdf");
  await expect(page.locator("[data-phx-main]")).toHaveClass(/phx-connected/);
});
