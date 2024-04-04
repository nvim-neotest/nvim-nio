local nio = require("nio")
local a = nio.tests

describe("process", function()
  a.it("returns process ID", function()
    local process = assert(nio.process.run({
      cmd = "printf",
      args = { "hello" },
    }))
    assert.True(0 < process.pid)
  end)

  a.it("captures stdout", function()
    local process = assert(nio.process.run({
      cmd = "printf",
      args = { "hello" },
    }))
    process.result()
    local output = process.stdout.read()

    assert.equal("hello", output)
    local exit_code = process.result()
    assert.equal(0, exit_code)
  end)

  a.it("captures stderr", function()
    local process = assert(nio.process.run({
      cmd = vim.loop.exepath(),
      args = { "--bad" },
    }))
    process.result()
    local output = process.stderr.read()

    assert.Not.equal("", output)
  end)

  a.it("returns spawn error", function()
    local process, err = nio.process.run({
      cmd = "not_a_real_command",
    })
    assert.Nil(process)
    assert.equal("ENOENT: no such file or directory", err)
  end)

  a.it("returns spawn error with bad stdin pipe", function()
    local process, err = nio.process.run({
      cmd = "cat",
      stdin = 1000,
    })
    assert.equal("EBADF: bad file descriptor", err)
    assert.Nil(process)
  end)

  a.it("returns spawn error with bad stdout pipe", function()
    local process, err = nio.process.run({
      cmd = "cat",
      stdout = 1000,
    })
    assert.equal("EBADF: bad file descriptor", err)
    assert.Nil(process)
  end)

  a.it("sends input", function()
    local process = assert(nio.process.run({ cmd = "cat" }))
    process.stdin.write("hello")
    process.stdin.close()

    local output = process.stdout.read()
    assert.equal("hello", output)
  end)

  a.it("pipes from another process", function()
    local process = assert(nio.process.run({
      cmd = "printf",
      args = { "hello" },
    }))

    local second_process = assert(nio.process.run({
      cmd = "cat",
      stdin = process.stdout,
    }))
    second_process.result()
    local output = second_process.stdout.read()
    assert.equal(output, "hello")
  end)

  a.it("pipes from file", function()
    local path = assert(nio.fn.tempname())

    local write_file = assert(nio.file.open(path, "w+"))

    write_file.write("hello")
    write_file.close()

    local read_file = assert(nio.file.open(path, "r"))

    local process = assert(nio.process.run({
      cmd = "cat",
      stdin = read_file,
    }))
    process.result()
    local output = process.stdout.read()
    assert.equal(output, "hello")
  end)

  a.it("pipes to file", function()
    local path = assert(nio.fn.tempname())

    local file = assert(nio.file.open(path, "w+"))

    local process = assert(nio.process.run({
      cmd = "cat",
      stdout = file,
    }))
    process.stdin.write("hello")
    process.stdin.close()
    process.result()

    local output = file.read(nil, 0)
    assert.equal(output, "hello")
  end)

  a.it("reads input from uv_pipe_t", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = assert(nio.process.run({
      cmd = "cat",
      stdin = pipe,
    }))

    pipe:write("hello")
    nio.uv.shutdown(pipe)

    process.result()
    local output = process.stdout.read()
    assert.equal(output, "hello")
  end)

  a.it("writes stdout to uv_pipe_t", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = assert(nio.process.run({
      cmd = "printf",
      args = { "hello" },
      stdout = pipe,
    }))

    local output = nio.control.future()
    pipe:read_start(function(_, data)
      if data then
        output.set(data)
      end
    end)

    process.result()

    pipe:close()
    assert.equal(output.wait(), "hello")
  end)

  a.it("writes stderr to uv_pipe_t", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = assert(nio.process.run({
      cmd = vim.loop.exepath(),
      args = { "--bad" },
      stderr = pipe,
    }))

    local output = nio.control.future()
    pipe:read_start(function(_, data)
      if output.is_set() then
        return
      end
      output.set(data)
    end)

    process.result()

    pipe:close()
    assert.Not.equal(output.wait(), "")
  end)

  a.it("sends signals to pid", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = assert(nio.process.run({
      cmd = "cat",
      stdin = pipe,
    }))

    process.signal(15)

    local exit_code = process.result()
    assert.equal(0, exit_code)
  end)

  a.it("returns exit code", function()
    local process = assert(nio.process.run({
      cmd = "bash",
      args = { "-c", "exit 1" },
    }))

    local exit_code = process.result()
    assert.equal(1, exit_code)
  end)
end)
