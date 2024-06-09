local nio = require("nio")
local a = nio.tests

describe("file", function()
  a.it("opens file", function()
    local path = assert(nio.fn.tempname())

    local file = assert(nio.file.open(path, "w"))

    assert.True(file.fd > 0)
  end)

  a.it("returns opening error", function()
    local path = assert(nio.fn.tempname())

    local file, open_err = nio.file.open(path, "r")

    assert.equal(open_err, "ENOENT: no such file or directory: " .. path)
    assert.Nil(file)
  end)

  a.it("writes file", function()
    local path = assert(nio.fn.tempname())

    local file = assert(nio.file.open(path, "w"))

    local err = file.write("hello")

    local io_file = assert(io.open(path, "r"))
    local content = io_file:read()
    io_file:close()

    assert.Nil(err)
    assert.equal(content, "hello")
  end)

  a.it("return error writing", function()
    local path = assert(nio.fn.tempname())

    local file = assert(nio.file.open(path, "w"))

    nio.uv.fs_close(file.fd)

    local err = file.write("hello")

    assert.equal("EBADF", err)
  end)

  a.it("reads file", function()
    local path = assert(nio.fn.tempname())
    local io_file = assert(io.open(path, "w"))
    io_file:write("hello")
    io_file:close()

    local file = assert(nio.file.open(path))
    local content, err = file.read()

    assert.Nil(err)
    assert.equal("hello", content)
  end)

  a.it("reads file up to n", function()
    local path = assert(nio.fn.tempname())
    local io_file = assert(io.open(path, "w"))
    io_file:write("hello")
    io_file:close()

    local file = assert(nio.file.open(path))
    local content, err = file.read(3)

    assert.Nil(err)
    assert.equal("hel", content)
  end)

  a.it("reads file from offset", function()
    local path = assert(nio.fn.tempname())
    local io_file = assert(io.open(path, "w"))
    io_file:write("hello")
    io_file:close()

    local file = assert(nio.file.open(path))
    local content, err = file.read(nil, 1)

    assert.Nil(err)
    assert.equal("ello", content)
  end)

  a.it("returns error when reading", function()
    local path = assert(nio.fn.tempname())
    local io_file = assert(io.open(path, "w"))
    io_file:write("hello")
    io_file:close()

    local file = assert(nio.file.open(path))
    nio.uv.fs_close(file.fd)
    local content, err = file.read()

    assert.Nil(content)
    assert.equal("EBADF: bad file descriptor", err)
  end)
end)
