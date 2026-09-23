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

  test("writer init errors leave the entry pending without a generic entry error", () => {
    let errorCb;
    let channelErrorCb;
    let fakeChannel = {
      onError: (cb) => (channelErrorCb = cb),
      leave: jest.fn(),
      join: () => ({
        receive(kind, cb) {
          if (kind === "error") errorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = {
      ref: "0",
      metadata: () => ({}),
      cancel: jest.fn(),
      error: jest.fn(),
    };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();

    errorCb({ reason: "writer_error" });
    channelErrorCb("closed");

    expect(fakeChannel.leave).toHaveBeenCalledTimes(1);
    expect(entry.cancel).not.toHaveBeenCalled();
    expect(entry.error).not.toHaveBeenCalled();
  });

  test("writer chunk errors leave the entry pending without a generic entry error", () => {
    let pushErrorCb;
    let fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      isJoined: () => true,
      join: () => ({
        receive() {
          return this;
        },
      }),
      push: () => ({
        receive(kind, cb) {
          if (kind === "error") pushErrorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = {
      ref: "0",
      file: { size: 10 },
      metadata: () => ({}),
      progress: jest.fn(),
      cancel: jest.fn(),
      error: jest.fn(),
    };
    let config = { chunk_size: 5, chunk_timeout: 5000 };

    let uploader = new EntryUploader(entry, config, fakeLiveSocket);
    uploader.upload();
    uploader.pushChunk(new ArrayBuffer(5));

    pushErrorCb({ reason: "writer_error" });

    expect(fakeChannel.leave).toHaveBeenCalledTimes(1);
    expect(entry.progress).not.toHaveBeenCalled();
    expect(entry.cancel).not.toHaveBeenCalled();
    expect(entry.error).not.toHaveBeenCalled();
  });
});
