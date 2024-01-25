local nio = require("nio")
local a = nio.tests

describe("process", function()
  a.it("captures stdout", function()
    local process = nio.process.run({
      cmd = "printf",
      args = { "hello" },
    })
    process.result()
    local output = process.stdout.read()

    assert.equal("hello", output)
    local exit_code = process.result()
    assert.equal(0, exit_code)
  end)

  a.it("captures stderr", function()
    local process = nio.process.run({
      cmd = vim.loop.exepath(),
      args = { "--bad" },
    })
    process.result()
    local output = process.stderr.read()

    assert.Not.equal("", output)
  end)

  a.it("sends input", function()
    local process = nio.process.run({ cmd = "cat" })
    process.stdin.write("hello")
    process.stdin.close()

    local output = process.stdout.read()
    assert.equal("hello", output)
  end)

  a.it("pipes from another process", function()
    local process = nio.process.run({
      cmd = "printf",
      args = { "hello" },
    })

    local second_process = nio.process.run({
      cmd = "cat",
      stdin = process.stdout,
    })
    second_process.result()
    local output = second_process.stdout.read()
    assert.equal(output, "hello")
  end)

  a.it("reads input from uv_pipe_t", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = nio.process.run({
      cmd = "cat",
      stdin = pipe,
    })

    pipe:write("hello")
    nio.uv.shutdown(pipe)

    process.result()
    local output = process.stdout.read()
    assert.equal(output, "hello")
  end)

  a.it("writes stdout to uv_pipe_t", function()
    local pipe = assert(vim.loop.new_pipe())
    A(pipe:fileno())

    local process = nio.process.run({
      cmd = "printf",
      args = { "hello" },
      stdout = pipe,
    })

    local output = nio.control.future()
    pipe:read_start(function(_, data)
      if data then
        output.set(data)
      end
    end)

    process.result()
    A(pipe:fileno())

    pipe:close()
    assert.equal(output.wait(), "hello")
  end)

  a.it("writes stderr to uv_pipe_t", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = nio.process.run({
      cmd = vim.loop.exepath(),
      args = { "--bad" },
      stderr = pipe,
    })

    local output = nio.control.future()
    pipe:read_start(function(_, data)
      output.set(data)
    end)

    process.result()

    pipe:close()
    assert.Not.equal(output.wait(), "")
  end)

  a.it("sends signals to pid", function()
    local pipe = assert(vim.loop.new_pipe())

    local process = nio.process.run({
      cmd = "cat",
      stdin = pipe,
    })

    process.signal(15)

    local exit_code = process.result()
    assert.equal(15, exit_code)
  end)
end)
