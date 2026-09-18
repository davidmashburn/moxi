# Visible-window memory observation fixture

Original local path: `/tmp/moxi-window-soak.csv`.

- Bytes: 1,957,794.
- SHA-256: `cdf7a41e39e7696589eed173a02c3ac8023a7f726ac5b4d708198a8862665388`.
- Rows: 100,000 data rows, plus header.
- CSV field order: `key,x,y,value`.

The fixture is not duplicated in this archive. Recreate it with Python's CSV
writer; `newline=''` preserves the generated CSV bytes and CRLF record endings:

```python
import csv

with open('/tmp/moxi-window-soak.csv', 'w', newline='') as output:
    writer = csv.writer(output)
    writer.writerow(['key', 'x', 'y', 'value'])
    for i in range(100000):
        writer.writerow([i, i % 997, ((i * 17) % 1000) / 100,
                         ((i * 13) % 1000) / 100])
```

Source key 0 was selected before warm-up. The parent recorded periodic filter,
clear, one-page scroll, Sort Y, and window zoom interactions during observation.
The filter field was `x`: strict `x > 600` leaves 39,600 rows; `x > 500`
leaves 49,600. Both hide selected key 0 while preserving its selection; Clear
restores 100,000 visible rows and the visible selected key.
Use the paired CUA evidence for actual field, timestamps, results, and gaps;
this was not continuous high-frequency input.
