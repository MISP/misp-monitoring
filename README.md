# misp-monitoring
Tools and documentation related to MISP instance monitoring in production/corporate environments 

## livestats.sh

command-line utility to have a view on HTTP requests arriving on the MISP server.

based on `bash`, `sort`, `uniq`, `awk`, `grep`, `cut`, `tail`, `bc`, `expand`

```
Usage: ./livestats.sh [ -f | --logfile <filename> ] 
                      [ -s | --scope <scope> ] 
                      [ -l | --limit <searchterm> ] 
                      [ -n | --lines <number> ] 
                      [ -i | --interval <seconds> ]
```

`logfile`  is an `Apache` access logfile containing MISP logs
`scope`    is a scope filter, for instance if you have a reverse proxy for `misp1.your.domain` and `misp2.your.domain`
`limit`    is an additional search term like `GET /events/` or `POST /events/restSearch`.
`lines`    is the number of log lines to show
`interval` is the number of seconds until refresh

Interactive controls accessible via Ctrl-C:
```
 	        q - quit
	        i - edit interval
 	        r - reset values
	        s - sort
	        l - edit loglimit
	        o - toggle order
   	      any other key resumes
```

Output:
```
IP Address                            lines (t-2s)    lines (t=now)     delta  req/s   total increase
------------------------------------------------------------------------------------------------------------
193.41.a.b                               65315           65328          13      6.50       1033
141.117.c.d                             116822          116833          11      5.50       1302
93.94.e.f                                76269           76276           7      3.50        904
95.216.g.h                               63607           63609           2      1.00        333
62.23.i.j                                 6840            6840           0      0             0
54.200.k.l                                8552            8552           0      0             0
51.124.m.n                                6823            6823           0      0            66
164.128.o.p                              36004           36004           0      0             0
161.69.q.r                                2040            2040           0      0             0
149.134.s.t                              12108           12108           0      0             0
```

Where `IP address` is an IP address, `lines (t-2s)` is the number of log entries from 2s ago, `lines (t=now)` number of log lines now, `delta` is the difference between the two former, `req/s` are the number of requests per second, and the `total increase` is the total number of requests since starting the tool.
