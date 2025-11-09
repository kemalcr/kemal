# Kemal Benchmark

## Installation

You will need to install [wrk](https://github.com/wg/wrk/blob/master/INSTALL) in order to run the benchmarks.

## Running

To run the benchmarks, run `run`.

The output will look something like this:

```
Building app...
Starting app...
2025-08-13T13:50:39.080477Z   INFO - kemal: [development] Kemal is ready to lead at http://0.0.0.0:3000
Running benchmark...
Running 5s test @ http://0.0.0.0:3000
  8 threads and 50 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.09ms  181.77us   4.30ms   82.42%
    Req/Sec     5.52k   532.67     7.04k    70.02%
  223578 requests in 5.10s, 33.48MB read
Requests/sec:  43842.96
Transfer/sec:      6.56MB
2025-08-13T13:50:46.183382Z   INFO - kemal: Kemal is going to take a rest
```

### Tip: Save the results to a file

You can use `run > results.log` to save the results to a file `results.log`.