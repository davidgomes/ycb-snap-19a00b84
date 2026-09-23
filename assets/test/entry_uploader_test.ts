import EntryUploader from "phoenix_live_view/entry_uploader";

describe("EntryUploader", () => {
  test("passes channel-error reply reason as string to entry.error", () => {
    let errorCb;
    let fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      join: () => ({
        receive(kind, cb) {
          if (kind === "error") errorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = { ref: "0", metadata: () => ({}), error: jest.fn() };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();

    // Reply payload arrives as {reason: "..."}, not as a string.
    errorCb({ reason: "join crashed" });

    expect(entry.error).toHaveBeenCalledWith("join crashed");
  });

  test("leaves the entry pending on a writer init error", () => {
    let errorCb;
    let fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      join: () => ({
        receive(kind, cb) {
          if (kind === "error") errorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = { ref: "0", metadata: () => ({}), error: jest.fn() };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();

    // The server already failed and retained the entry with the writer failure.
    errorCb({ reason: "writer_error" });

    expect(fakeChannel.leave).toHaveBeenCalledTimes(1);
    expect(entry.error).not.toHaveBeenCalled();
  });

  test("leaves the entry pending on a writer chunk error", () => {
    let chunkErrorCb;
    let fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      isJoined: () => true,
      push: () => ({
        receive(kind, cb) {
          if (kind === "error") chunkErrorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = { ref: "0", metadata: () => ({}), error: jest.fn() };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).pushChunk(
      new ArrayBuffer(1),
    );

    chunkErrorCb({ reason: "writer_error" });
    // a later channel error must not fall back to the generic entry error
    chunkErrorCb({ reason: "join crashed" });

    expect(fakeChannel.leave).toHaveBeenCalledTimes(1);
    expect(entry.error).not.toHaveBeenCalled();
  });
});
