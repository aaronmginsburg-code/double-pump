--!nocheck
-- Runs every tests/*.spec.luau file. Usage (from the repo root): lune run tests/run.luau [filter]
local fs = require("@lune/fs")
local process = require("@lune/process")
local T = require("./tests/runner/T")

local filter = process.args[1]
local files = {}
for _, name in fs.readDir("tests") do
	if name:match("%.spec%.luau$") and (not filter or name:find(filter, 1, true)) then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	local before = T.results.passed + T.results.failed
	local ok, err = pcall(require, "./tests/" .. name:gsub("%.luau$", ""))
	if not ok then
		T.results.failed += 1
		table.insert(T.results.failures, { name = name .. " (load)", err = tostring(err) })
	end
	print(string.format("%-34s %d tests", name, T.results.passed + T.results.failed - before))
end

for _, failure in T.results.failures do
	print("\nFAIL " .. failure.name .. "\n" .. failure.err)
end
print(string.format("\n%d passed, %d failed", T.results.passed, T.results.failed))
process.exit(if T.results.failed == 0 then 0 else 1)
