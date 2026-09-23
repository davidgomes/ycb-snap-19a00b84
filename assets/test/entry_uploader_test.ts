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

  test("leaves the entry pending when the server reports a writer error", () => {
    let joinErrorCb;
    let chunkErrorCb;
    let fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      isJoined: () => true,
      join: () => ({
        receive(kind, cb) {
          if (kind === "error") joinErrorCb = cb;
          return this;
        },
      }),
      push: () => ({
        receive(kind, cb) {
          if (kind === "error") chunkErrorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let form = {};
    let entry = {
      ref: "0",
      metadata: () => ({}),
      error: jest.fn(),
      fileEl: { form },
      view: { cancelSubmit: jest.fn() },
    };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    // writer init/1 failure is reported as a join error
    new EntryUploader(entry, config, fakeLiveSocket).upload();
    joinErrorCb({ reason: "writer_error" });

    // write_chunk/2 or close/2 failure is reported as a chunk error
    let uploader = new EntryUploader(entry, config, fakeLiveSocket);
    uploader.upload();
    uploader.pushChunk(new ArrayBuffer(1));
    chunkErrorCb({ reason: "writer_error" });

    expect(fakeChannel.leave).toHaveBeenCalledTimes(2);
    expect(entry.view.cancelSubmit).toHaveBeenCalledWith(form);
    expect(entry.error).not.toHaveBeenCalled();
  });
});
