# BizBrain Change Log

## Time Lapse analytics update

- Added Average quantity KPI, calculated from the filtered production records.
- Added Peak quantity KPI to show the largest quantity in the selected records.
- Added Lowest quantity KPI to show the smallest quantity in the selected records.
- Added anomaly detection for grouped quantity trends using a two-standard-deviation threshold around the trend mean.
- Anomaly results show the trend date, observed quantity, average, and difference from average.
- KPI and anomaly calculations respect the currently selected sheets, date range, date field, quantity field, and grouping.
- Empty data and trends without detectable anomalies display an explanatory empty state.

## Release History

- Release History currently lists recent GitHub commits and GitHub Actions workflow status.
- This change log provides a human-readable feature summary; the Release History UI may still need a separate implementation to display these notes directly.
