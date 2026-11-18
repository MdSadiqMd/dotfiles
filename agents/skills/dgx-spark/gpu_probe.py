import time, torch, torch.nn as nn
torch.cuda.set_per_process_memory_fraction(1024 / (torch.cuda.get_device_properties(0).total_memory / 2**20))  # hard cap ~1 GB
d = "cuda"
torch.manual_seed(0)
X = torch.randn(4096, 64, device=d); w = torch.randn(64, 1, device=d); y = X @ w + 0.1 * torch.randn(4096, 1, device=d)
m = nn.Sequential(nn.Linear(64, 128), nn.ReLU(), nn.Linear(128, 1)).to(d)
opt = torch.optim.Adam(m.parameters(), 1e-2)
t = time.time()
for s in range(300):
    i = torch.randint(0, 4096, (256,), device=d)
    loss = nn.functional.mse_loss(m(X[i]), y[i]); opt.zero_grad(); loss.backward(); opt.step()
    if s in (0, 299): print(f"step {s} loss {loss.item():.4f}")
torch.cuda.synchronize()
print(f"device={torch.cuda.get_device_name(0)} time={time.time()-t:.2f}s peak_mem={torch.cuda.max_memory_allocated()/2**20:.1f}MiB")
