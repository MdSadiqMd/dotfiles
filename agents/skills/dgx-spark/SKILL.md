---
name: dgx-spark
description: Run GPU work (training, CUDA jobs, experiments) on the shared DGX Spark pair `spark1`/`spark2` over SSH, without disturbing the DeepSeek (dsv41) server people use. Use when asked to run something "on the spark", "on the DGX", on the GB10 GPUs, or to check/stop/start the DeepSeek engine there.
---

# DGX Spark pair

Two NVIDIA GB10 boxes (128 GB unified memory each), reachable as `ssh spark1` (head) and `ssh spark2` (worker) with key login, already set up in `~/.ssh/config`. `spark2` goes through Twingate, so Twingate must be connected on this Mac.

- sudo: `security find-generic-password -s dgx-spark-sudo -w | ssh spark1 'sudo -S -p "" <cmd>'`. Never print the password or put it in a file or command line.
- Host Python has no torch. Use the serving image: `docker run --rm --gpus all ... --entrypoint python3 dsv41-serve:v5 <script>`.
- Engine docs: `ssh spark1 cat ~/cx7-bond/README.md`.

## DeepSeek is live, people use it

`dsv41-serve` (vLLM, tensor-parallel across both boxes) holds ~108 GB on each GPU, leaving ~6 GB. Running out of memory can get the vLLM worker OOM-killed for everyone.

- Never stop, restart, `docker exec` into, or change `dsv41-serve`, `litellm`, `open-webui` or the Twingate connector unless the user explicitly asks in the current thread. Stopping takes the model offline for everyone. Confirm the timing with the user first.
- Before any GPU job, check load and memory, and skip if anyone is using it:
  ```sh
  ssh spark1 "curl -s localhost:8000/metrics | grep -E '^vllm:num_requests_(running|waiting)\{'"
  ssh spark1 'free -m; nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader'
  ```
- While DeepSeek runs, only toy jobs fit. Cap GPU memory (`torch.cuda.set_per_process_memory_fraction`), use `nice -n 19`, `timeout`, `docker run --rm --memory 3g`, and abort if `MemAvailable` < 4 GB.
- Verified 2026-11-10: a tiny job works on spark1 (~66 MiB, see `gpu_probe.py`); spark2 returned CUDA OOM even for that, so do not run GPU jobs on spark2 while DeepSeek is up.
- After a job, confirm `ssh spark1 "curl -s -o /dev/null -w '%{http_code}' localhost:8000/health"` prints 200 and no probe containers remain.

## Safe probe

```sh
ssh spark1 'cat > /tmp/gpu_probe.py' < ~/.agents/skills/dgx-spark/gpu_probe.py
ssh spark1 'timeout 120 nice -n 19 docker run --rm --gpus all --memory 3g -v /tmp/gpu_probe.py:/t.py:ro --entrypoint python3 dsv41-serve:v5 /t.py; rm -f /tmp/gpu_probe.py'
```

## Real training (needs the full GPU)

Only after the user agrees on a window: `ssh spark1` → `sudo systemctl stop dsv41-serve` (the head unit also stops the spark2 rank), run the job, then `sudo systemctl start dsv41-serve` and wait for `/health` 200 and a test completion before handing back.
