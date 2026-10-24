# uji.jobs

A command the model runs can keep going in the background while you talk to
the model. A command becomes a background job in one of three ways:

- The model sets `run_in_background` on `run_command`, which suits dev servers
  and watch builds.
- A command still running at its timeout moves to the background instead of
  stopping. The timeout is 120 seconds unless the model gives its own. A
  command that starts with `sleep` stops at its timeout instead.
- You press Ctrl+Z while the command runs, and the model's turn carries on at
  once.

While a job runs, a row under the input shows its command and how long it has
run. When it ends, uji shows a notice and tells the model the exit code and the
last lines of output. If no turn is running, uji starts one so the model can
react; otherwise the report goes with the next turn. A job that you or the
model stop starts no turn.

The model reads a job's output with the `job_output` tool and stops it with
`stop_job`. `/jobs` lists the jobs under the input, running ones first, and
keeps them there until you type or press Esc. It picks the first job; Enter
opens its output, ↑ and ↓ pick another, and `x` stops a running job or drops a
finished one.

A background job stops after 30 minutes, or after the `timeout` the model gives
with `run_in_background`, and never runs longer than two hours. At most 8 jobs
run in the background at once. Esc stops the turn and its foreground command,
and leaves background jobs running. Quitting, `/reload`, or closing the
terminal stops them all. Stopping a job also stops every process it started,
such as the server a dev server command launches.

## uji.jobs.list()

Returns one table per background job, oldest first, with these fields:

| Field | Meaning |
|---|---|
| `id` | The job's number, which the model uses with `job_output` and `stop_job`. |
| `command` | The shell command. |
| `state` | `running`, `finished`, `stopped` or `timed out`. |
| `code` | The exit code, once the job ends. |
| `status` | A short description, such as `"running for 42s"` or `"finished, exit 0"`. |
| `tail` | The last lines of output. |

## uji.jobs.stop(id)

Stops a running job and returns `true`. Returns `false` when no job with that
id is running.

## uji.jobs.show()

Lists the jobs under the input, running ones first and then the newest, and
picks the first. `/jobs` runs this, and it notices when there are no jobs at
all.

## uji.jobs.configure(opts)

| Option | Meaning | Default |
|---|---|---|
| `wake` | Start a turn when a job ends and no turn is running. | `true` |
| `max` | The most jobs that run in the background at once. | `8` |
| `limit` | Seconds a background job may run when the model gives no `timeout`. | `1800` |

```lua
uji.jobs.configure({ wake = false, limit = 3600 })
```

Raises an error for an unknown option, a `wake` that is not `true` or `false`,
and a `max` or `limit` that is not a number above 0.
